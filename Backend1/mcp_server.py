from flask import Flask, request, jsonify
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from datetime import datetime
import urllib.parse
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# MongoDB Configuration
MONGODB_USERNAME = 'starboy_user'  
MONGODB_PASSWORD = '55359279'  
MONGODB_CLUSTER = 'cluster0.qnn7pyq.mongodb.net'  
DATABASE_NAME = 'starboy_db'
COLLECTION_NAME = 'sessions'

# URL-encode the password to handle special characters
encoded_password = urllib.parse.quote_plus(MONGODB_PASSWORD)
connection_string = f"mongodb+srv://{MONGODB_USERNAME}:{encoded_password}@{MONGODB_CLUSTER}/?retryWrites=true&w=majority&appName=Cluster0"

client = None
db = None
sessions = None

try:
    # Create MongoClient with ServerApi instance for Atlas compatibility
    client = MongoClient(
        connection_string,
        server_api=ServerApi(version='1')
    )
    
    # Test the connection with a ping
    client.admin.command('ping')
    logger.info("Successfully connected to MongoDB Atlas!")
    
    # Get database and collection (creates if they don't exist)
    db = client[DATABASE_NAME]
    sessions = db[COLLECTION_NAME]
    
except Exception as e:
    logger.error(f"Failed to connect to MongoDB: {e}")
    print(f"Connection failed: {e}. Check your password, IP whitelist, and cluster status.")
    client = None

@app.route('/save_session', methods=['POST'])
def save_session():
    global sessions
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    memory = request.json.get('session_memory')
    if memory:
        sessions.insert_one({'memory': memory, 'timestamp': datetime.now()})
        logger.info(f"Saved session memory: {memory[:50]}...")
    return jsonify({'status': 'success'})

@app.route('/recall_session', methods=['GET'])
def recall_session():
    global sessions
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    latest = sessions.find_one(sort=[('timestamp', -1)])
    return jsonify({'session_memory': latest['memory'] if latest else ''})

@app.route('/clear_session', methods=['POST'])
def clear_session():
    global sessions
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    sessions.delete_many({})
    logger.info("Cleared all session data")
    return jsonify({'status': 'success'})

if __name__ == '__main__':
    if client is None:
        print("Cannot start server: MongoDB connection failed. Fix the connection string and retry.")
    else:
        print("MCP Server starting on http://0.0.0.0:5002")
        app.run(debug=True, host='0.0.0.0', port=5002)