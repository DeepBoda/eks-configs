// Replace the Elasticsearch client configuration in your backend code:

// OLD (with auth):
const client = new Client({
  node: process.env.ELASTIC_URL || "http://localhost:9200",
  auth: {
    username: "elastic",
    password: "sdXBClIwLXjBHveJmqIh",
  },
  ssl: {
    ca: fs.readFileSync(certificatePath),
  },
});

// NEW (no auth):
const client = new Client({
  node: process.env.ELASTIC_URL || "http://localhost:9200",
});