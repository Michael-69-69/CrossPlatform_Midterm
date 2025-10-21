import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  late GenerativeModel _model;
  final List<String> _sessionMemory = [];

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  // Skip MCP session management
  Future<void> _ensureSession() async {
    // MCP disabled - do nothing
    return;
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
      final memoryContext = _sessionMemory.join(' '); // Build context from memory

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

      // Skip MCP save
      return response.text ?? 'No response from AI.';
    } catch (e) {
      print('Gemini API error: $e');
      return 'Sorry, I couldn’t process that. Try again!';
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
    // MCP disabled - do nothing
    return;
  }

  Future<String> recallSession() async {
    // Return empty string since MCP is disabled
    return '';
  }

  void clearSession() async {
    _sessionMemory.clear();
    // MCP disabled - no server call needed
  }
}