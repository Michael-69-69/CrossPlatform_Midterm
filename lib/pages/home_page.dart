import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:alarm/alarm.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/image_state.dart';
import '../services/speech_emotion_service.dart';
import '../services/gemini_service.dart';
import 'student_tracker.dart';
import 'alarm.dart';
import 'memo.dart';
import 'travel.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final SpeechEmotionService _speechService = SpeechEmotionService();
  final GeminiService _geminiService = GeminiService();
  final FlutterTts _flutterTts = FlutterTts();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool _isSpeaking = false;
  String _responseText = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1600), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.linear),
    );
    _ensurePermissions();
    Alarm.init();
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _shakeController.reset();
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _flutterTts.stop();
    _speechService.stop(null);
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _showAlert('Microphone permission is required.');
    }
    await Permission.camera.request();
    await Permission.notification.request();
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notice'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _onHoldMicStart() async {
    HapticFeedback.mediumImpact();
    await _ensurePermissions();
    final status = await _speechService.initializeOnDemand();
    if (status != 'ready') {
      _showAlert(status.replaceAll('_', ' '));
      return;
    }
    setState(() {
      _isSpeaking = true;
      _responseText = '';
      _isLoading = false;
    });
    _shakeController.repeat(reverse: true);
    _speechService.startListening(_onSpeechProcessed);
  }

  Future<void> _onHoldMicEnd() async {
    if (_speechService.isListening) {
      await _speechService.stop(_onSpeechProcessed);
    }
    _shakeController.reset();
    setState(() {
      _isSpeaking = false;
    });
  }

  Future<void> _onPickMedia() async {
    await _ensurePermissions();
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    Provider.of<ImageState>(context, listen: false).setImage(file);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image selected. Processing...')),
    );
    setState(() {
      _isLoading = true;
    });
    final intent = await _geminiService.routeIntent(text: 'analyze image', imageFile: file);
    if (intent == 'general:chat') {
      String geminiResponse = await _geminiService.generateContent(
        text: 'Analyze this image',
        imageFile: file,
        emotions: [],
      );
      if (geminiResponse.isNotEmpty) {
        setState(() {
          _isSpeaking = true;
          _shakeController.repeat(reverse: true);
          _responseText = geminiResponse;
          _isLoading = false;
        });
        await _flutterTts.speak(geminiResponse);
      }
    } else {
      _routeByIntent(intent);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onSpeechProcessed(
    String status,
    String text,
    List<Map<String, dynamic>> emotions,
    String? culturalResponse,
  ) async {
    if (!mounted) return;
    if (status.startsWith('Error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status)));
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Local navigation commands
    String lowerText = text.toLowerCase().trim();
    if (lowerText.contains("alarm") && lowerText.contains("page")) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => AlarmSchedulerPage()));
      setState(() {
        _isLoading = false;
      });
      return;
    } else if (lowerText.contains("memo") && lowerText.contains("page")) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => MemoKeeperPage()));
      setState(() {
        _isLoading = false;
      });
      return;
    } else if (lowerText.contains("student") || lowerText.contains("tracker")) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => StudentTrackerPage()));
      setState(() {
        _isLoading = false;
      });
      return;
    } else if (lowerText.contains("travel") && lowerText.contains("page")) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => TravelGuidePage()));
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Alarm setting via voice
    if (lowerText.contains("set alarm")) {
      RegExp timeRegex = RegExp(r'(\d{1,2})\s*(am|pm)', caseSensitive: false);
      var match = timeRegex.firstMatch(lowerText);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        String period = match.group(2)!.toUpperCase();
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        DateTime now = DateTime.now();
        DateTime alarmTime = DateTime(now.year, now.month, now.day, hour);
        if (alarmTime.isBefore(now)) alarmTime = alarmTime.add(Duration(days: 1));
        await Alarm.set(
          alarmSettings: AlarmSettings(
            id: DateTime.now().millisecondsSinceEpoch % 10000,
            dateTime: alarmTime,
            assetAudioPath: 'assets/alarm.mp3',
            notificationTitle: 'STARBOY Alarm',
            notificationBody: 'Time to wake up!',
          ),
        );
        String response = 'Alarm set for ${match.group(0)}';
        setState(() {
          _isSpeaking = true;
          _shakeController.repeat(reverse: true);
          _responseText = response;
          _isLoading = false;
        });
        await _flutterTts.speak(response);
        return;
      }
    }

    // Cultural response
    if (culturalResponse != null && culturalResponse.isNotEmpty) {
      setState(() {
        _isSpeaking = true;
        _shakeController.repeat(reverse: true);
        _responseText = culturalResponse;
        _isLoading = false;
      });
      await _flutterTts.speak(culturalResponse);
      return;
    }

    // Backend intents via /voice_command
    File? imageFile = Provider.of<ImageState>(context, listen: false).imageFile;
    final intent = await _geminiService.routeIntent(text: text, emotions: emotions);
    String response = '';
    setState(() {
      _isLoading = true;
    });
    if (intent == 'general:chat') {
      response = await _geminiService.generateContent(
        text: text,
        imageFile: imageFile,
        emotions: emotions,
      );
    } else {
      try {
        final backendResponse = await http.post(
          Uri.parse('http://0.0.0.0:5002/voice_command'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'command': text}),
        );
        var jsonResponse = jsonDecode(backendResponse.body);
        if (jsonResponse.containsKey('error')) {
          response = 'Error: ${jsonResponse['error']}';
        } else if (intent == 'scores:check') {
          response = jsonResponse['scores']
              .map((s) => "${s['course']}: ${s['score']}")
              .join(", ");
        } else if (intent == 'travel:plan') {
          response = "Trip planned: ${jsonResponse['plan']}";
        } else if (intent == 'notes:create') {
          response = "Note saved: ${jsonResponse['content'] ?? text}";
        } else if (intent == 'clear:all') {
          response = "All data cleared";
        } else {
          response = jsonResponse['response'] ?? 'Action completed';
        }
      } catch (e) {
        response = 'Error connecting to backend: $e';
      }
    }

    if (response.isNotEmpty) {
      setState(() {
        _isSpeaking = true;
        _shakeController.repeat(reverse: true);
        _responseText = response;
        _isLoading = false;
      });
      await _flutterTts.speak(response);
    }
  }

  void _routeByIntent(String intent) {
    switch (intent) {
      case 'scores:check':
        Navigator.push(context, MaterialPageRoute(builder: (context) => StudentTrackerPage()));
        break;
      case 'travel:plan':
        Navigator.push(context, MaterialPageRoute(builder: (context) => TravelGuidePage()));
        break;
      case 'notes:create':
        Navigator.push(context, MaterialPageRoute(builder: (context) => MemoKeeperPage()));
        break;
      case 'alarm:set':
        Navigator.push(context, MaterialPageRoute(builder: (context) => AlarmSchedulerPage()));
        break;
      case 'clear:all':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared via voice')));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Intent: $intent')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageState>(
      builder: (context, imageState, child) {
        return Scaffold(
          body: SafeArea(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('STARBOY',
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              'AI Personal Assistant',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                            ),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Check backend health',
                          onPressed: () async {
                            try {
                              final status = await _speechService.initializeOnDemand();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(status == 'ready' ? 'Backend OK' : status)),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Health check failed: $e')),
                              );
                            }
                          },
                          icon: const Icon(Icons.health_and_safety_outlined),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: Listenable.merge([_pulseAnimation, _shakeAnimation]),
                            builder: (context, _) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Icon(
                                  _isSpeaking ? Icons.mic : Icons.smart_toy,
                                  size: 160,
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_isLoading)
                            const CircularProgressIndicator()
                          else
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _responseText,
                                style: const TextStyle(fontSize: 16, color: Colors.black),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onLongPressStart: (_) => _onHoldMicStart(),
                            onLongPressEnd: (_) => _onHoldMicEnd(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.mic, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(_isSpeaking ? 'Listening…' : 'Hold to Talk',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _onPickMedia,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer),
                                  const SizedBox(width: 8),
                                  const Text('Add Media', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}