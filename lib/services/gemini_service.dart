import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'mcp_client.dart';

class GeminiService {
  late GenerativeModel _model;
  final List<String> _sessionMemory = [];
  McpClient? _mcp;
  String? _sessionId;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  Future<void> _ensureSession() async {
    if (_mcp == null) {
      _mcp = await McpClient.connect();
    }
    if (_sessionId == null) {
      final result = await _mcp!.call('init_session', {'user_id': 'anonymous'});
      _sessionId = (result as Map)['session_id'] as String;
    }
  }

  // Seeds in-memory session from a recalled persisted string
  void seedSessionMemory(String memory) {
    if (memory.isEmpty) return;
    _sessionMemory.addAll(memory.split(' '));
  }

  Future<String> generateContent({
    required String text,
    File? imageFile,
    List<Map<String, dynamic>> emotions = const [],
  }) async {
    try {
      _sessionMemory.add(text); // Store user input in memory
      final memoryContext = _sessionMemory.join(
        ' ',
      ); // Build context from memory

      final parts = <Part>[];
      String prompt =
          'Role: empathetic, friendly cultural companion.\n'
          'Style rules:\n'
          '- Do NOT say you are an AI or assistant.\n'
          '- Speak directly to the user; no disclaimers.\n'
          '- Be concise and specific; 1 short sentence unless asked.\n'
          '- If emotions are given, reflect them briefly.\n'
          'Context: Based on the user input: "$text"';
      if (emotions.isNotEmpty) {
        prompt +=
            ' and detected emotions: ${emotions.map((e) => "${e['label']}: ${e['score']}").join(", ")}';
      }
      if (memoryContext.isNotEmpty) {
        prompt += ' and previous context: "$memoryContext"';
      }
      prompt += ', provide a single concise, friendly sentence (max 30 words).';
      parts.add(TextPart(prompt));

      if (imageFile != null) {
        final imageBytes = await imageFile.readAsBytes();
        final mimeType =
            imageFile.path.endsWith('.jpg') || imageFile.path.endsWith('.jpeg')
                ? 'image/jpeg'
                : 'image/png';
        parts.add(DataPart(mimeType, imageBytes));
      }

      final content = [Content.multi(parts)];
      final response = await _model.generateContent(content);

      // Save to MCP for persistence
      await _saveToMcp(memoryContext);
      return response.text ?? 'No response from AI.';
    } catch (e) {
      throw Exception('Gemini API error: $e');
    }
  }

  // Simple heuristic router that maps user text to an intent string
  Future<String> routeIntent({
    required String text,
    File? imageFile,
    List<Map<String, dynamic>> emotions = const [],
  }) async {
    final lower = text.toLowerCase();
    if (lower.contains('email') || lower.contains('send') && lower.contains('mail')) {
      return 'email:send';
    }
    if (lower.contains('note') || lower.contains('remember')) {
      return 'notes:create';
    }
    if (lower.contains('alarm') || lower.contains('wake me')) {
      return 'alarm:set';
    }
    if (lower.contains('attendance') || lower.contains('class')) {
      return 'attendance:view';
    }
    if (lower.contains('score') || lower.contains('grade')) {
      return 'scores:check';
    }
    if (lower.contains('travel') || lower.contains('trip') || lower.contains('itinerary')) {
      return 'travel:plan';
    }
    if (lower.contains('workout') || lower.contains('exercise') || lower.contains('fitness')) {
      return 'fitness:start';
    }
    return 'general:chat';
  }

  Future<void> _saveToMcp(String memory) async {
    try {
      await _ensureSession();
      await _mcp!.call('update_context', {
        'session_id': _sessionId,
        'new_context': [
          {'text': memory},
        ],
      });
    } catch (e) {
      // Log but do not fail user flow
      // ignore: avoid_print
      print('MCP save failed: $e');
    }
  }

  Future<String> recallSession() async {
    try {
      await _ensureSession();
      final result = await _mcp!.call('get_context', {
        'session_id': _sessionId,
      });
      final contextList = (result as Map)['context'] as List<dynamic>?;
      if (contextList == null) return '';
      final texts =
          contextList
              .map((e) => (e as Map<String, dynamic>)['text'])
              .whereType<String>()
              .toList();
      return texts.join(' ');
    } catch (e) {
      // ignore: avoid_print
      print('MCP recall failed: $e');
      return '';
    }
  }

  void clearSession() async {
    _sessionMemory.clear();
    try {
      await _ensureSession();
      await _mcp!.call('clear_session', {'session_id': _sessionId});
      _sessionId = null;
    } catch (e) {
      // ignore: avoid_print
      print('MCP clear failed: $e');
    }
  }
}
