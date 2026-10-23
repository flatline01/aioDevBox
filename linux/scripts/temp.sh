#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- 1. Configuration & Validation ---
# Ensure the SUPER_ADMIN environment variable is set
if [ -z "\$SUPER_ADMIN" ]; then
    echo "Error: The 'SUPER_ADMIN' environment variable is not defined." >&2
    exit 1
fi

# Function to display script usage
usage() {
    echo "Usage: \$0 --name=\"Site Name\" --slug=\"site-slug\" [--url=\"example.com\"] [--multisite]"
    exit 1
}

# Parse named arguments
while [[ "\$#" -gt 0 ]]; do
    case \$1 in
        --name=*) SITE_NAME="\${1#*=}" ;;
        --slug=*) SLUG="\${1#*=}" ;;
        --url=*) SITE_URL="\${1#*=}" ;;
        --multisite) MULTISITE=true ;;
        *) echo "Unknown parameter passed: \$1"; usage ;;
    esac
    shift
done

# Validate required arguments
if [ -z "\(SITE_NAME" ] \vert{}\vert{} [ -z "\)SLUG" ]; then
    echo "Error: Both --name and --slug are required parameters." >&2
    usage
fi

# Sanitize slug for directory and DB compatibility (alphanumeric and underscores/hyphens only)
SLUG_CLEAN=\((echo "\)SLUG" | tr -cd '[:alnum:]_-')

# Fallback URL if not provided
if [ -z "\$SITE_URL" ]; then
    SITE_URL="http://localhost/\$SLUG_CLEAN"
fi

# Define database parameters
DB_NAME="wp_\${SLUG_CLEAN}"
DB_USER="usr_\${SLUG_CLEAN}"
# Generate a highly secure random password for the new database user
DB_PASS=\$(openssl rand -base64 16 | tr -dc '[:alnum:]')
DB_HOST="localhost"

# Admin configuration derived from environment variable
ADMIN_USER="\$SUPER_ADMIN"
ADMIN_EMAIL="\${ADMIN_USER}@example.com" # Adjust as needed
ADMIN_PASS=\$(openssl rand -base64 12)

echo "============================================="
echo " Starting WordPress Setup for: \$SITE_NAME"
echo " Slug/Directory:               \$SLUG_CLEAN"
echo " URL:                           \$SITE_URL"
echo " Multisite Enabled:            \${MULTISITE:-false}"
echo "============================================="

# --- 2. Create the Directory ---
echo "Creating directory '\$SLUG_CLEAN'..."
mkdir -p "\$SLUG_CLEAN"
cd "\$SLUG_CLEAN"

# --- 3. Create MySQL Database and User ---
echo "Creating MySQL database and user..."
# Note: This assumes the executing system user has root access via local mysql client configurations (~/.my.cnf).
# Alternatively, replace 'mysql' with 'mysql -u root -pPassword' if necessary.
mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql -e "CREATE USER IF NOT EXISTS '\${DB_USER}'@'\({DB_HOST}' IDENTIFIED BY '\){DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '\({DB_USER}'@'\){DB_HOST}';"
mysql -e "FLUSH PRIVILEGES;"

# --- 4. WP-CLI Downloads & Configuration ---
echo "Downloading core WordPress files..."
wp core download

echo "Generating wp-config.php..."
wp config create --dbname="\(DB_NAME" --dbuser="\)DB_USER" --dbpass="\(DB_PASS" --dbhost="\)DB_HOST"

# --- 5. WordPress Installation Loop ---
if [ "\$MULTISITE" = true ]; then
    echo "Installing WordPress as a Multisite Network..."
    # Installs core network setup directly
    wp core multisite-install \
        --url="\$SITE_URL" \
        --title="\$SITE_NAME" \
        --admin_user="\$ADMIN_USER" \
        --admin_password="\$ADMIN_PASS" \
        --admin_email="\$ADMIN_EMAIL" \
        --subdomains=false # Set to true if you are doing a subdomain network instead of subdirectories
else
    echo "Installing standard WordPress site..."
    wp core install \
        --url="\$SITE_URL" \
        --title="\$SITE_NAME" \
        --admin_user="\$ADMIN_USER" \
        --admin_password="\$ADMIN_PASS" \
        --admin_email="\$ADMIN_EMAIL"
fi

# --- 6. Summary ---
echo "============================================="
echo " WordPress Setup Successfully Completed!"
echo "============================================="
echo " Directory Path:  \$(pwd)"
echo " Database Name:   \$DB_NAME"
echo " Database User:   \$DB_USER"
echo " Database Pass:   \$DB_PASS"
echo " WP Admin User:   \$ADMIN_USER"
echo " WP Admin Pass:   \$ADMIN_PASS"
echo " URL:             \$SITE_URL"
echo "============================================="