import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gemini_service.dart';

class SpeechEmotionService {
  final String _baseUrl = dotenv.env['SPEECH_API_URL'] ?? 'http://127.0.0.1:5000';
  final AudioRecorder _recorder = AudioRecorder();
  File? _audioFile;
  bool _isRecording = false;
  bool _isInitialized = false;
  final GeminiService _geminiService = GeminiService();

  bool get isInitialized => _isInitialized;
  bool get isListening => _isRecording;

  Future<String> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _audioFile = File('${directory.path}/temp_audio.wav');
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['models_loaded']['whisper'] && data['models_loaded']['emotion']) {
          _isInitialized = true;
          print('SpeechEmotionService initialized successfully');
          return 'ready';
        } else {
          print('Models not loaded on backend');
          return 'error_models';
        }
      } else {
        print('Backend health check failed: ${response.statusCode}');
        return 'error_connection';
      }
    } catch (e) {
      print('Error initializing SpeechEmotionService: $e');
      _isInitialized = false;
      return 'error_exception';
    }
  }

  // Lazily ensure service is initialized before first use
  Future<String> initializeOnDemand() async {
    if (_isInitialized) return 'ready';
    try {
      final status = await initialize();
      return status;
    } catch (e) {
      return 'error_exception';
    }
  }

  Future<void> startListening(
    void Function(String, String, List<Map<String, dynamic>>, String?) callback, {
    File? imageFile,
  }) async {
    if (!_isInitialized) {
      final status = await initializeOnDemand();
      if (status != 'ready') {
        callback(status, '', [], null);
        return;
      }
    }

    try {
      if (await _recorder.hasPermission()) {
        _isRecording = true;
        await _recorder.start(const RecordConfig(), path: _audioFile!.path);
        print('Recording started');
        callback('Recording...', '', [], null);

        // Recording will normally be stopped by the UI (press-and-hold).
        // As a safety fallback, stop automatically after 8 seconds.
        await Future.delayed(Duration(seconds: 8));
        if (_isRecording) {
          await stop(callback, imageFile: imageFile);
        }
      } else {
        callback('Microphone permission denied', '', [], null);
      }
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
      callback('Error starting recording: $e', '', [], null);
    }
  }

  Future<void> stop(
    void Function(String, String, List<Map<String, dynamic>>, String?)? callback, {
    File? imageFile,
  }) async {
    if (!_isRecording && callback == null) {
      // Handle cleanup call (no callback, no recording)
      _isRecording = false;
      return;
    }

    if (!_isRecording) {
      callback?.call('Not recording', '', [], null);
      return;
    }

    try {
      await _recorder.stop();
      _isRecording = false;
      print('Recording stopped, processing audio...');
      callback?.call('Processing...', '', [], null);

      final result = await _transcribeAndAnalyze(imageFile);
      if (result['success']) {
        final transcribedText = result['transcribed_text'] ?? '';
        final emotions = (result['emotions'] as List<dynamic>?)?.map((e) => {
              'label': e['label'] as String,
              'score': (e['score'] / 100).toDouble(),
              'percentage': e['score'].toDouble(),
            }).toList() ?? [];
        final geminiResponse = await _generateCulturalResponse(transcribedText, emotions, imageFile);
        callback?.call('Success', transcribedText, emotions, geminiResponse);
      } else {
        callback?.call('Error: ${result['error']}', '', [], null);
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      callback?.call('Error stopping recording: $e', '', [], null);
    }
  }

  Future<Map<String, dynamic>> _transcribeAndAnalyze(File? imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/transcribe_and_analyze'));
      request.files.add(await http.MultipartFile.fromPath('audio', _audioFile!.path));
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 200 && data['success']) {
        print('Transcription and analysis successful: ${data['transcribed_text']}');
        return data;
      } else {
        print('Backend error: ${data['error']}');
        return {'success': false, 'error': data['error'] ?? 'Unknown error'};
      }
    } catch (e) {
      print('Error in transcribe_and_analyze: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<String?> _generateCulturalResponse(
    String transcribedText,
    List<Map<String, dynamic>> emotions,
    File? imageFile,
  ) async {
    if (transcribedText.isEmpty && imageFile == null) {
      return null;
    }

    try {
      final response = await _geminiService.generateContent(
        text: transcribedText,
        imageFile: imageFile,
        emotions: emotions,
      );
      return response.split('.').first + '.'; // Ensure one sentence
    } catch (e) {
      print('Error calling GeminiService: $e');
      return _createMockCulturalResponse(transcribedText);
    }
  }

  String _createMockCulturalResponse(String input) {
    List<String> responses = [
      'Your words spark joy in the digital realm!',
      'Your voice carries a vibrant energy today.',
      'The AI spirits resonate with your input.',
    ];

    final rand = Random();
    return responses[rand.nextInt(responses.length)];
  }

  Future<Map<String, dynamic>> transcribeAudioFile(File audioFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/transcribe'));
      request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> analyzeTextDirectly(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analyze_emotions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}