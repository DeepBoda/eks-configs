// Fix for Elasticsearch client response structure
// Replace in elasticSearch.js

// OLD CODE:
// const { body } = await client.search({...});
// return body.hits.hits.map((hit) => hit._source);

// NEW CODE:
const response = await client.search({...});
const hits = response.body?.hits?.hits || response.hits?.hits || [];
return hits.map((hit) => hit._source);

// OR simpler fix - just remove the destructuring:
// const response = await client.search({...});
// return response.hits.hits.map((hit) => hit._source);