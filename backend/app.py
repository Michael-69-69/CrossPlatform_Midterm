from flask import Flask, request, jsonify
from pymongo import MongoClient
from pymongo.server_api import ServerApi
from datetime import datetime
import urllib.parse
import logging
import time
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from bs4 import BeautifulSoup
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# MongoDB Configuration
MONGODB_USERNAME = 'starboy_user'
MONGODB_PASSWORD = '55359279'
MONGODB_CLUSTER = 'cluster0.qnn7pyq.mongodb.net'
DATABASE_NAME = 'starboy_db'

# URL-encode the password to handle special characters
encoded_password = urllib.parse.quote_plus(MONGODB_PASSWORD)
connection_string = f"mongodb+srv://{MONGODB_USERNAME}:{encoded_password}@{MONGODB_CLUSTER}/?retryWrites=true&w=majority&appName=Cluster0"

client = None
db = None
scores_coll = None
itineraries_coll = None
notes_coll = None
alarms_coll = None

try:
    # Create MongoClient with ServerApi instance for Atlas compatibility
    client = MongoClient(
        connection_string,
        server_api=ServerApi(version='1')
    )
    # Test the connection with a ping
    client.admin.command('ping')
    logger.info("Successfully connected to MongoDB Atlas!")
    
    # Get database and collections (creates if they don't exist)
    db = client[DATABASE_NAME]
    scores_coll = db['scores']  # For student scores
    itineraries_coll = db['itineraries']  # For travel plans
    notes_coll = db['notes']  # For memo/diary
    alarms_coll = db['alarms']  # For alarm data
    
    # Add indexes for performance
    scores_coll.create_index([("mssv", 1), ("timestamp", -1)])
    itineraries_coll.create_index([("trip_id", 1), ("end_date", 1)])
    notes_coll.create_index([("date", 1), ("timestamp", -1)])
    alarms_coll.create_index([("user_id", 1), ("alarm_time", 1)])
    
except Exception as e:
    logger.error(f"Failed to connect to MongoDB: {e}")
    print(f"Connection failed: {e}. Check your password, IP whitelist, and cluster status.")
    client = None

# Function to fetch student scores using Selenium web crawler
def fetch_student_scores(mssv, password):
    # Specify the path to your ChromeDriver executable
    path_to_chromedriver = "D:/Playground/FunnyCOde/chromedriver-win64/chromedriver.exe"
    
    # Set up Selenium with Service and Options
    options = Options()
    options.add_argument("--headless")  # Run headless
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")  # Set a larger window size
    
    service = Service(executable_path=path_to_chromedriver)
    driver = None
    
    try:
        driver = webdriver.Chrome(service=service, options=options)
        
        # Navigate to the login page
        login_url = "https://old-stdportal.tdtu.edu.vn/Login/Index?ReturnUrl=https%3A%2F%2Fold-stdportal.tdtu.edu.vn%2F"
        driver.get(login_url)
        logger.info(f"Navigated to login: {driver.current_url}")
        
        # Wait for the login form to load and fill it
        WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.ID, "txtUser")))
        username_field = driver.find_element(By.ID, "txtUser")
        password_field = driver.find_element(By.ID, "txtPass")
        
        username_field.send_keys(mssv)
        password_field.send_keys(password)
        password_field.send_keys(Keys.RETURN)  # Submit the form
        
        # Wait for login to complete (redirect)
        time.sleep(5)  # Give time for redirection
        logger.info(f"After login, navigated to: {driver.current_url}")
        
        # Navigate to the scores page with the correct path
        scores_url = "https://ketquahoctap.tdtu.edu.vn/home/diemtonghop/"
        driver.get(scores_url)
        logger.info(f"Navigated to scores page: {driver.current_url}")
        
        # Check if redirected and retry with token if needed
        if "Token" in driver.current_url and "RequestId" in driver.current_url:
            logger.info("Detected token-based redirect. Attempting to navigate to scores page again.")
            driver.get(scores_url)  # Retry the scores URL
            time.sleep(5)  # Wait for potential redirect
        
        # Trigger content loading with scrolling
        driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(5)  # Wait for initial load
        
        # Wait for the page to load and table to be populated
        max_wait_time = 40  # Increased wait time
        start_time = time.time()
        table_found = False
        
        while time.time() - start_time < max_wait_time and not table_found:
            try:
                WebDriverWait(driver, 5).until(EC.presence_of_element_located((By.ID, "dl_kqht")))
                table = driver.find_element(By.ID, "dl_kqht")
                rows = table.find_elements(By.TAG_NAME, "tr")
                if len(rows) > 1:  # Check if table has more than the header row
                    table_found = True
                    logger.info("Table found with rows!")
                else:
                    time.sleep(2)  # Wait before retrying
                    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")  # Scroll again
            except Exception:
                time.sleep(2)  # Wait before next attempt
                driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")  # Scroll again
        
        if not table_found:
            raise Exception("Table 'dl_kqht' not found after waiting.")
        
        # Scroll through the page to load all content
        total_height = driver.execute_script("return document.body.scrollHeight")
        for i in range(0, total_height, 500):  # Scroll in steps of 500px
            driver.execute_script(f"window.scrollTo(0, {i});")
            time.sleep(1)  # Allow time for content to load
        
        driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        time.sleep(2)  # Final wait for content to settle
        
        # Parse with BeautifulSoup
        soup = BeautifulSoup(driver.page_source, 'html.parser')
        table = soup.find('table', id='dl_kqht')
        
        if table:
            scores_list = []
            rows = table.find_all('tr')[1:]  # Skip header
            for row in rows:
                cols = row.find_all('td')
                if len(cols) == 5:
                    stt = cols[0].text.strip()
                    course = cols[1].text.strip().replace('\n', ' ')
                    code = cols[2].text.strip()
                    credits = cols[3].text.strip()
                    score = cols[4].text.strip()
                    
                    scores_list.append({
                        'stt': stt,
                        'course': course,
                        'code': code,
                        'credits': credits,
                        'score': score
                    })
            
            driver.quit()
            return scores_list
        else:
            raise Exception("Table parsing failed.")
            
    except Exception as e:
        logger.error(f"Error fetching scores: {e}")
        if driver:
            driver.quit()
        return str(e)  # Return error as string

# Endpoint for checking student scores (fetches via web crawler and saves last result)
@app.route('/check_scores', methods=['POST'])
def check_scores():
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    data = request.json
    mssv = data.get('mssv')
    password = data.get('password')
    
    if not mssv or not password:
        return jsonify({'error': 'Missing mssv or password'}), 400
    
    scores = fetch_student_scores(mssv, password)
    
    if isinstance(scores, str):  # Error occurred
        return jsonify({'error': scores}), 500
    
    # Save last result only (delete old for this mssv)
    scores_coll.delete_many({'mssv': mssv})
    scores_coll.insert_one({
        'mssv': mssv,
        'scores': scores,
        'timestamp': datetime.now()
    })
    logger.info(f"Saved scores for MSSV: {mssv}")
    
    return jsonify({'scores': scores})

# Endpoint to recall latest scores for a student
@app.route('/scores/<mssv>', methods=['GET'])
def get_scores(mssv):
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    record = scores_coll.find_one({'mssv': mssv}, sort=[('timestamp', -1)])
    return jsonify({'scores': record['scores'] if record else []})

# Endpoint for planning a trip (simple logging to DB)
@app.route('/plan_trip', methods=['POST'])
def plan_trip():
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    data = request.json
    trip_id = data.get('trip_id')
    plan = data.get('plan')  # Expect frontend to send plan details (e.g., JSON with itinerary)
    end_date = datetime.fromisoformat(data.get('end_date')) if data.get('end_date') else None
    
    if not trip_id or not plan:
        return jsonify({'error': 'Missing trip_id or plan'}), 400
    
    # Save to DB
    itineraries_coll.insert_one({
        'trip_id': trip_id,
        'plan': plan,
        'end_date': end_date,
        'timestamp': datetime.now()
    })
    logger.info(f"Saved itinerary for trip {trip_id}")
    
    return jsonify({'status': 'success', 'plan': plan})

# Endpoint to recall a trip plan
@app.route('/itinerary/<trip_id>', methods=['GET'])
def get_itinerary(trip_id):
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    itinerary = itineraries_coll.find_one(
        {'trip_id': trip_id, 'end_date': {'$gte': datetime.now()}}, 
        sort=[('timestamp', -1)]
    )
    return jsonify({'plan': itinerary['plan'] if itinerary else None})

# Endpoint for saving a memo/note (daily diary style)
@app.route('/note', methods=['POST'])
def save_note():
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    data = request.json
    content = data.get('content')
    expiry = datetime.fromisoformat(data.get('expiry')) if data.get('expiry') else None
    
    if not content:
        return jsonify({'error': 'Missing content'}), 400
    
    current_date = datetime.now().date().isoformat()  # Group by date for daily diary
    
    notes_coll.insert_one({
        'date': current_date,
        'content': content,
        'expiry': expiry,
        'timestamp': datetime.now()
    })
    logger.info(f"Saved note on {current_date}: {content[:50]}...")
    
    return jsonify({'status': 'success'})

# Endpoint to recall notes (optionally by date)
@app.route('/notes', methods=['GET'])
def get_notes():
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    date_param = request.args.get('date')  # e.g., ?date=2025-10-19
    query = {'$or': [{'expiry': None}, {'expiry': {'$gte': datetime.now()}}]}
    if date_param:
        query['date'] = date_param
    
    notes = list(notes_coll.find(query, sort=[('timestamp', -1)]).limit(10))  # Limit to recent
    return jsonify({'notes': [note['content'] for note in notes]})

# ALARM ENDPOINTS
@app.route('/alarms', methods=['POST'])
def create_alarm():
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    data = request.json
    user_id = data.get('user_id', 'default_user')
    title = data.get('title')
    alarm_time = datetime.fromisoformat(data.get('alarm_time'))
    is_active = data.get('is_active', True)
    
    if not title or not alarm_time:
        return jsonify({'error': 'Missing title or alarm_time'}), 400
    
    alarm_data = {
        'user_id': user_id,
        'title': title,
        'alarm_time': alarm_time,
        'is_active': is_active,
        'created_at': datetime.now(),
        'updated_at': datetime.now()
    }
    
    result = alarms_coll.insert_one(alarm_data)
    alarm_data['_id'] = str(result.inserted_id)
    
    logger.info(f"Created alarm for user {user_id}: {title}")
    return jsonify({'status': 'success', 'alarm': alarm_data})

@app.route('/alarms/<user_id>', methods=['GET'])
def get_alarms(user_id):
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    alarms = list(alarms_coll.find({'user_id': user_id}, sort=[('alarm_time', 1)]))
    
    # Convert ObjectId to string for JSON serialization
    for alarm in alarms:
        alarm['_id'] = str(alarm['_id'])
        alarm['alarm_time'] = alarm['alarm_time'].isoformat()
        alarm['created_at'] = alarm['created_at'].isoformat()
        alarm['updated_at'] = alarm['updated_at'].isoformat()
    
    return jsonify({'alarms': alarms})

@app.route('/alarms/<alarm_id>', methods=['PUT'])
def update_alarm(alarm_id):
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    data = request.json
    update_data = {'updated_at': datetime.now()}
    
    if 'title' in data:
        update_data['title'] = data['title']
    if 'alarm_time' in data:
        update_data['alarm_time'] = datetime.fromisoformat(data['alarm_time'])
    if 'is_active' in data:
        update_data['is_active'] = data['is_active']
    
    result = alarms_coll.update_one(
        {'_id': alarm_id},
        {'$set': update_data}
    )
    
    if result.matched_count == 0:
        return jsonify({'error': 'Alarm not found'}), 404
    
    logger.info(f"Updated alarm {alarm_id}")
    return jsonify({'status': 'success'})

@app.route('/alarms/<alarm_id>', methods=['DELETE'])
def delete_alarm(alarm_id):
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    result = alarms_coll.delete_one({'_id': alarm_id})
    
    if result.deleted_count == 0:
        return jsonify({'error': 'Alarm not found'}), 404
    
    logger.info(f"Deleted alarm {alarm_id}")
    return jsonify({'status': 'success'})

# General clear endpoint (for all collections, use with caution)
@app.route('/clear_all', methods=['POST'])
def clear_all():
    if client is None:
        return jsonify({'error': 'MongoDB not connected'}), 500
    
    scores_coll.delete_many({})
    itineraries_coll.delete_many({})
    notes_coll.delete_many({})
    alarms_coll.delete_many({})
    
    logger.info("Cleared all data")
    return jsonify({'status': 'success'})

if __name__ == '__main__':
    if client is None:
        print("Cannot start server: MongoDB connection failed. Fix the connection string and retry.")
    else:
        print("Backend Server starting on http://0.0.0.0:5002")
        app.run(debug=True, host='0.0.0.0', port=5002)

