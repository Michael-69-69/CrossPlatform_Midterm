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
          'Role: STARBOY AI Personal Assistant - empathetic, friendly cultural companion.\n'
          'Style rules:\n'
          '- Do NOT say you are an AI or assistant.\n'
          '- Speak directly to the user; no disclaimers.\n'
          '- Be concise and specific; 1 short sentence unless asked.\n'
          '- If emotions are given, reflect them briefly.\n'
          'Available features:\n'
          '- Check student scores: "check scores for MSSV [number]"\n'
          '- Plan trips: "plan trip to [destination]"\n'
          '- Save notes: "save note [content]"\n'
          '- Set alarms: "set alarm for [time]"\n'
          '- Navigate pages: "go to [alarm/memo/student/travel] page"\n'
          '- Clear data: "clear all data"\n'
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

  // Enhanced heuristic router that maps user text to an intent string
  Future<String> routeIntent({
    required String text,
    File? imageFile,
    List<Map<String, dynamic>> emotions = const [],
  }) async {
    final lower = text.toLowerCase();

    // Navigation commands
    if (lower.contains('go to') ||
        lower.contains('open') ||
        lower.contains('navigate')) {
      if (lower.contains('alarm') || lower.contains('wake')) {
        return 'navigate:alarm';
      }
      if (lower.contains('memo') ||
          lower.contains('note') ||
          lower.contains('notes')) {
        return 'navigate:memo';
      }
      if (lower.contains('student') ||
          lower.contains('score') ||
          lower.contains('grade') ||
          lower.contains('tracker')) {
        return 'navigate:student';
      }
      if (lower.contains('travel') ||
          lower.contains('trip') ||
          lower.contains('itinerary')) {
        return 'navigate:travel';
      }
    }

    // Backend function commands
    if (lower.contains('check score') ||
        lower.contains('get score') ||
        lower.contains('my grade')) {
      return 'scores:check';
    }
    if (lower.contains('plan trip') ||
        lower.contains('travel to') ||
        lower.contains('trip to')) {
      return 'travel:plan';
    }
    if (lower.contains('save note') ||
        lower.contains('remember') ||
        lower.contains('note down')) {
      return 'notes:create';
    }
    if (lower.contains('set alarm') ||
        lower.contains('wake me') ||
        lower.contains('alarm for')) {
      return 'alarm:set';
    }
    if (lower.contains('clear all') ||
        lower.contains('delete all') ||
        lower.contains('reset data')) {
      return 'clear:all';
    }

    // General chat
    return 'general:chat';
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
