#%%
# Endpoint for your ChromaDB API, modify the path as per your API documentation
chromadb_url = 'http://192.168.68.99:5001'

# Headers with authorization token
headers = {
    'Authorization': 'Bearer your_token_here'
}
import chromadb

client = chromadb.HttpClient(
    host=chromadb_url,
    # port=5001,
    ssl=False,
    # headers=headers,
    settings=None,
    # tenant=DEFAULT_TENANT,
    # database=DEFAULT_DATABASE
)
print(client)
client.heartbeat()

#%%
# Get default tenant
# tenant = client.set_tenant('default_tenant')



client.list_collections()

# %%


import chromadb
from chromadb.config import DEFAULT_TENANT, DEFAULT_DATABASE
admin_client = chromadb.AdminClient()
admin_client.create_tenant(DEFAULT_TENANT)
# %%
