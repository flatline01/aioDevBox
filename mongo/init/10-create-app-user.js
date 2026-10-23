// Runs once, on first initialization of an empty mongo_data volume.
// Creates the application user (readWrite on the app database only), so
// apps don't connect as root. Credentials come from the container env.
const dbName = process.env.MONGO_DATABASE;
const appDb = db.getSiblingDB(dbName);

appDb.createUser({
  user: process.env.MONGO_USER,
  pwd: process.env.MONGO_PASSWORD,
  roles: [{ role: "readWrite", db: dbName }],
});

// Mongo creates databases lazily; seed a collection so it shows up in tools.
appDb.createCollection("_init");
