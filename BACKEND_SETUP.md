# Backend Setup Instructions

## 🔧 Fixing Connection Issues

The app was trying to connect to `http://0.0.0.0:5002` which doesn't work. I've updated it to use `http://localhost:5002` by default.

### Option 1: Use localhost (Recommended)
The app now defaults to `http://localhost:5002`. Make sure your backend is running on this URL.

### Option 2: Create .env file (Advanced)
Create a `.env` file in the root directory with:

```env
# Backend Configuration
BACKEND_URL=http://localhost:5002
# Alternative: http://127.0.0.1:5002

# Gemini AI Configuration  
GEMINI_API_KEY=your_gemini_api_key_here

# Speech Service Configuration
SPEECH_API_URL=http://127.0.0.1:5000
```

## 🚀 How to Start Backend

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Install Python dependencies:**
   ```bash
   pip install flask pymongo selenium beautifulsoup4 python-dotenv
   ```

3. **Start the backend:**
   ```bash
   python app.py
   ```

4. **Verify backend is running:**
   - Open browser and go to `http://localhost:5002`
   - You should see a response or error page (not connection refused)

## 🧪 Test Connection

Run the test script to verify everything works:
```bash
dart test_backend_integration.dart
```

## 📱 Voice Commands

Now you can use these simplified voice commands:
- **"Tools alarm"** → Opens alarm page
- **"Tools scores"** → Opens student tracker page  
- **"Tools travel"** → Opens travel guide page
- **"Tools memo"** → Opens memo keeper page

## 🔍 Troubleshooting

### If you still get connection errors:

1. **Check if backend is running:**
   ```bash
   curl http://localhost:5002
   ```

2. **Check if port 5002 is in use:**
   ```bash
   netstat -an | grep 5002
   ```

3. **Try different URL in .env:**
   ```env
   BACKEND_URL=http://127.0.0.1:5002
   ```

4. **Check firewall settings** - make sure port 5002 is not blocked

### Common Issues:
- **"Connection refused"** → Backend not running
- **"Timeout"** → Backend running but slow to respond  
- **"SocketException"** → Network/firewall issue


