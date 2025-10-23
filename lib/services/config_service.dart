import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static String get backendUrl {
    // Try to get from environment variables first (using API_BASE_URL from .env)
    String? envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    // Fallback to localhost for development
    return 'http://localhost:5002';
  }

  static String get geminiApiKey {
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static String get speechApiUrl {
    return dotenv.env['SPEECH_API_URL'] ?? 'http://127.0.0.1:5000';
  }
}