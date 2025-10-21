from pymongo import MongoClient
from pymongo.server_api import ServerApi
import urllib.parse

MONGODB_USERNAME = 'starboy_user'  
MONGODB_PASSWORD = '55359279'  
MONGODB_CLUSTER = 'cluster0.qnn7pyq.mongodb.net'

encoded_password = urllib.parse.quote_plus(MONGODB_PASSWORD)
connection_string = f"mongodb+srv://{MONGODB_USERNAME}:{encoded_password}@{MONGODB_CLUSTER}/?retryWrites=true&w=majority&appName=Cluster0"

try:
    client = MongoClient(
        connection_string,
        server_api=ServerApi(version='1')
    )
    client.admin.command('ping')
    print("Connection successful! You can now run the MCP server.")
except Exception as e:
    print(f"Test failed: {e}")