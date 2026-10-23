#!/bin/sh
# nginx/docker-entrypoint.d/50-provision-sites.sh
#
# Runs automatically (via the base nginx image's /docker-entrypoint.d/
# mechanism) before nginx starts. Reads /sites.json, and for each site:
#   - generates an nginx vhost (HTTP -> HTTPS redirect, HTTPS proxying
#     .php requests to linux:9000)
#   - generates a self-signed SSL cert for its domain, if one doesn't
#     already exist under the persisted /etc/nginx/ssl volume
set -e

SITES_JSON="/sites.json"
CONF_DIR="/etc/nginx/conf.d"
SSL_DIR="/etc/nginx/ssl"

if [ ! -f "$SITES_JSON" ]; then
    echo "[sites] No sites.json found at $SITES_JSON — skipping site provisioning."
    exit 0
fi

mkdir -p "$SSL_DIR"

# Clear previously generated site vhosts (not default.conf) so a site
# removed from sites.json doesn't leave a stale, orphaned vhost behind.
rm -f "$CONF_DIR"/site-*.conf

site_count=$(jq '.sites | length' "$SITES_JSON")
echo "[sites] Found $site_count site(s) in sites.json"

for key in $(jq -r '.sites | keys[]' "$SITES_JSON"); do
    name=$(jq -r --arg k "$key" '.sites[$k].name' "$SITES_JSON")
    directory=$(jq -r --arg k "$key" '.sites[$k].directory' "$SITES_JSON")

    webroot=$(jq -r --arg k "$key" '.sites[$k].webroot // ""' "$SITES_JSON")
    if [[ -n "$webroot" ]]; then
        directory="${directory}${webroot}"
        echo "[sites]  * custom webroot: ${directory}"
    fi
    
    tld=$(jq -r --arg k "$key" '.sites[$k].tld' "$SITES_JSON")

    if [ -z "$directory" ] || [ "$directory" = "null" ] || [ -z "$tld" ] || [ "$tld" = "null" ]; then
        echo "[sites]   Skipping '$key' — missing directory or tld"
        continue
    fi

    echo "[sites]   $name ($tld) -> $directory"

    cert_dir="$SSL_DIR/$tld"
    mkdir -p "$cert_dir"

    if [ ! -f "$cert_dir/fullchain.pem" ] || [ ! -f "$cert_dir/privkey.pem" ]; then
        echo "[sites]     Generating self-signed cert for $tld"
        openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
            -keyout "$cert_dir/privkey.pem" \
            -out "$cert_dir/fullchain.pem" \
            -subj "/CN=$tld" \
            -addext "subjectAltName=DNS:$tld" \
            >/dev/null 2>&1
    else
        echo "[sites]     Reusing existing cert for $tld"
    fi

    cat > "$CONF_DIR/site-$key.conf" <<EOF
server {
    listen 80;
    server_name $tld;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $tld;

    ssl_certificate     $cert_dir/fullchain.pem;
    ssl_certificate_key $cert_dir/privkey.pem;

    root $directory;
    index index.php index.html;

    access_log /var/log/nginx/$key.access.log;
    error_log  /var/log/nginx/$key.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass linux:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\. {
        deny all;
    }
}
EOF


echo "[sites]     Remember to add $tld at 127.0.0.1 to your hosts file."
done

echo "[sites] Site(s) runs a self signed cert - you need to accept it in your browser."
echo "[sites] All *.local sites are available in the linux container."
echo "[sites] Done."
