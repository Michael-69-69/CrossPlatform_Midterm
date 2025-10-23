import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import '../models/image_state.dart';
import '../services/speech_emotion_service.dart';
import '../services/gemini_service.dart';
import '../services/config_service.dart';
import 'student_tracker.dart';
import 'alarm.dart';
import 'memo.dart';
import 'travel.dart';
import 'email.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final SpeechEmotionService _speechService = SpeechEmotionService();
  final GeminiService _geminiService = GeminiService();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  bool _isSpeaking = false;
  String _responseText = '';
  bool _isLoading = false;
  File? _recordedFile;
  bool _showTestButtons = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.linear),
    );
    _ensurePermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _audioRecorder.stop();
    _speechService.dispose();
    super.dispose();
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _shakeController.reset();
      });
    });
  }

  Future<void> _ensurePermissions() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _showAlert('Microphone permission is required.');
    }
    await Permission.camera.request();
    await Permission.storage.request();
    await Permission.notification.request();
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notice'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _onHoldMicStart() async {
    HapticFeedback.mediumImpact();
    await _ensurePermissions();
    if (await _audioRecorder.hasPermission()) {
      final directory = await getTemporaryDirectory();
      _recordedFile = File('${directory.path}/recording.m4a');
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordedFile!.path,
      );
      setState(() {
        _isSpeaking = true;
        _responseText = 'Recording...';
        _isLoading = false;
      });
      _shakeController.repeat(reverse: true);
    } else {
      _showAlert('Microphone permission denied.');
    }
  }

  Future<void> _onHoldMicEnd() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
      setState(() {
        _isSpeaking = false;
        _responseText = 'Recording stopped. Review or send?';
      });
      _shakeController.reset();
      _showRecordingOptions();
    }
  }

  Future<void> _showRecordingOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Listen'),
              onTap: () async {
                Navigator.pop(context);
                if (_recordedFile != null && await _recordedFile!.exists()) {
                  try {
                    await _audioPlayer.stop();
                    await _audioPlayer.play(DeviceFileSource(_recordedFile!.path));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Playback failed: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No recording available')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                if (_recordedFile != null && await _recordedFile!.exists()) {
                  await _recordedFile!.delete();
                }
                setState(() {
                  _recordedFile = null;
                  _responseText = 'Recording deleted.';
                });
                await _flutterTts.speak('Recording deleted.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Send'),
              onTap: () {
                Navigator.pop(context);
                _sendRecordingOrImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendRecordingOrImage() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Processing...';
    });

    File? imageFile = Provider.of<ImageState>(context, listen: false).imageFile;
    File? audioFile = _recordedFile;

    if (audioFile != null) {
      final result = await _speechService.transcribeAudioFile(audioFile);
      if (result['success']) {
        final transcribedText = result['transcribed_text'] ?? '';
        final emotions = (result['emotions'] as List<dynamic>?)
            ?.map((e) => {
                  'label': e['label'] as String,
                  'score': (e['score'] / 100).toDouble(),
                })
            .toList() ??
            [];
        final intent = await _geminiService.routeIntent(
          text: transcribedText,
          emotions: emotions,
        );
        String response = await _geminiService.generateContent(
          text: transcribedText,
          imageFile: imageFile,
          emotions: emotions,
        );
        setState(() {
          _isSpeaking = true;
          _shakeController.repeat(reverse: true);
          _responseText = response;
          _isLoading = false;
          _recordedFile = null;
        });
        await _flutterTts.speak(response);
      } else {
        setState(() {
          _responseText = 'Error: ${result['error'] ?? 'Failed to process audio'}';
          _isLoading = false;
        });
        await _flutterTts.speak(_responseText);
      }
    } else if (imageFile != null) {
      final intent = await _geminiService.routeIntent(
        text: 'Analyze this',
        imageFile: imageFile,
      );
      String response = await _geminiService.generateContent(
        text: 'Analyze this',
        imageFile: imageFile,
        emotions: [],
      );
      setState(() {
        _isSpeaking = true;
        _shakeController.repeat(reverse: true);
        _responseText = response;
        _isLoading = false;
        Provider.of<ImageState>(context, listen: false).setImage(null);
      });
      await _flutterTts.speak(response);
    } else {
      setState(() {
        _responseText = 'No recording or image to send.';
        _isLoading = false;
      });
      await _flutterTts.speak(_responseText);
    }
  }

  Future<void> _takePicture() async {
    await _ensurePermissions();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      Provider.of<ImageState>(context, listen: false).setImage(file);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo taken. Send when ready.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo taken.')),
      );
    }
  }

  Future<void> _onPickMedia() async {
    await _ensurePermissions();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    Provider.of<ImageState>(context, listen: false).setImage(file);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image selected. Send when ready.')),
    );
  }

  Future<void> _showInputDialog(String intent, String text) async {
    String input1 = '';
    String input2 = '';
    String title = 'Input Required';
    String label1 = '';
    String label2 = '';
    if (intent == 'scores:check') {
      title = 'Enter MSSV and Password';
      label1 = 'MSSV';
      label2 = 'Password';
    } else if (intent == 'travel:plan') {
      title = 'Plan a Trip';
      label1 = 'Destination';
      label2 = 'End Date (YYYY-MM-DD)';
    } else if (intent == 'notes:create') {
      title = 'Create a Note';
      label1 = 'Note Content';
      label2 = '';
    }
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(labelText: label1),
              onChanged: (value) => input1 = value,
            ),
            if (label2.isNotEmpty)
              TextField(
                decoration: InputDecoration(labelText: label2),
                obscureText: intent == 'scores:check',
                onChanged: (value) => input2 = value,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _processInput(intent, input1, input2, text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _processInput(String intent, String input1, String input2, String text) async {
    String response = '';
    setState(() {
      _isLoading = true;
    });
    try {
      if (intent == 'scores:check' && input1.isNotEmpty && input2.isNotEmpty) {
        final backendResponse = await http.post(
          Uri.parse('${ConfigService.backendUrl}/check_scores'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mssv': input1, 'password': input2}),
        );
        var jsonResponse = jsonDecode(backendResponse.body);
        if (jsonResponse.containsKey('error')) {
          response = 'Error: ${jsonResponse['error']}';
        } else {
          List<dynamic> scores = jsonResponse['scores'] ?? [];
          if (scores.isNotEmpty) {
            response = 'Found ${scores.length} scores for MSSV $input1: ';
            response += scores
                .take(3)
                .map((s) => "${s['course']}: ${s['score']}")
                .join(", ");
            if (scores.length > 3) response += " and ${scores.length - 3} more";
          } else {
            response = 'No scores found for MSSV $input1';
          }
          _routeByIntent('navigate:student');
        }
      } else if (intent == 'travel:plan' && input1.isNotEmpty) {
        String tripId = DateTime.now().millisecondsSinceEpoch.toString();
        final backendResponse = await http.post(
          Uri.parse('${ConfigService.backendUrl}/plan_trip'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'trip_id': tripId,
            'plan': input1,
            'end_date': input2.isNotEmpty ? input2 : DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          }),
        );
        var jsonResponse = jsonDecode(backendResponse.body);
        if (jsonResponse.containsKey('error')) {
          response = 'Error: ${jsonResponse['error']}';
        } else {
          response = 'Trip to $input1 planned successfully!';
          _routeByIntent('navigate:travel');
        }
      } else if (intent == 'notes:create' && input1.isNotEmpty) {
        final backendResponse = await http.post(
          Uri.parse('${ConfigService.backendUrl}/note'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'content': input1, 'expiry': null}),
        );
        var jsonResponse = jsonDecode(backendResponse.body);
        if (jsonResponse.containsKey('error')) {
          response = 'Error: ${jsonResponse['error']}';
        } else {
          response = 'Note saved: $input1';
          _routeByIntent('navigate:memo');
        }
      } else if (intent == 'clear:all') {
        final backendResponse = await http.post(
          Uri.parse('${ConfigService.backendUrl}/clear_all'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({}),
        );
        var jsonResponse = jsonDecode(backendResponse.body);
        if (jsonResponse.containsKey('error')) {
          response = 'Error: ${jsonResponse['error']}';
        } else {
          response = 'All data cleared successfully';
        }
      } else {
        response = 'Please fill in the required fields.';
      }
    } catch (e) {
      response = 'Error connecting to backend: $e';
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
    String lowerText = text.toLowerCase().trim();
    if (lowerText.contains("go to") ||
        lowerText.contains("open") ||
        lowerText.contains("navigate")) {
      if (lowerText.contains("alarm") || lowerText.contains("wake")) {
        _routeByIntent('navigate:alarm');
        setState(() {
          _isLoading = false;
        });
        return;
      } else if (lowerText.contains("memo") || lowerText.contains("note")) {
        _routeByIntent('navigate:memo');
        setState(() {
          _isLoading = false;
        });
        return;
      } else if (lowerText.contains("student") ||
          lowerText.contains("tracker") ||
          lowerText.contains("score")) {
        _showInputDialog('scores:check', text);
        setState(() {
          _isLoading = false;
        });
        return;
      } else if (lowerText.contains("travel") || lowerText.contains("trip")) {
        _showInputDialog('travel:plan', text);
        setState(() {
          _isLoading = false;
        });
        return;
      } else if (lowerText.contains("email") || lowerText.contains("mail")) {
        _routeByIntent('navigate:email');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }
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
    File? imageFile = Provider.of<ImageState>(context, listen: false).imageFile;
    final intent = await _geminiService.routeIntent(
      text: text,
      emotions: emotions,
    );
    if (intent == 'general:chat') {
      String response = await _geminiService.generateContent(
        text: text,
        imageFile: imageFile,
        emotions: emotions,
      );
      if (response.isNotEmpty) {
        setState(() {
          _isSpeaking = true;
          _shakeController.repeat(reverse: true);
          _responseText = response;
          _isLoading = false;
        });
        await _flutterTts.speak(response);
      }
    } else if (intent == 'scores:check' || intent == 'travel:plan' || intent == 'notes:create' || intent == 'clear:all') {
      _showInputDialog(intent, text);
      setState(() {
        _isLoading = false;
      });
    } else {
      _routeByIntent(intent);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _routeByIntent(String intent) {
    switch (intent) {
      case 'navigate:student':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StudentTrackerPage()),
        );
        break;
      case 'navigate:travel':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TravelGuidePage()),
        );
        break;
      case 'navigate:memo':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MemoKeeperPage()),
        );
        break;
      case 'navigate:alarm':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AlarmSchedulerPage()),
        );
        break;
      case 'navigate:email':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EmailPage()),
        );
        break;
      case 'scores:check':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StudentTrackerPage()),
        );
        break;
      case 'travel:plan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TravelGuidePage()),
        );
        break;
      case 'notes:create':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MemoKeeperPage()),
        );
        break;
      case 'alarm:set':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AlarmSchedulerPage()),
        );
        break;
      case 'clear:all':
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Data cleared via voice')));
        break;
      default:
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Intent: $intent')));
    }
  }

  void _showMysteryDialog() {
    String input = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Code'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Code'),
          onChanged: (value) => input = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (input.toLowerCase() == 'tester') {
                setState(() {
                  _showTestButtons = true;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
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
                    Color(0xFF4A90E2), // Soft blue
                    Color(0xFF50E3C2), // Teal
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
                            Text(
                              'STARBOY',
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white),
                            ),
                            Text(
                              'AI Personal Assistant',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.question_mark,
                              color: Colors.white),
                          onPressed: _showMysteryDialog,
                        ),
                      ],
                    ),
                  ),
                  if (_showTestButtons)
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        children: [
                          _buildTestButton('Alarm', 'navigate:alarm',
                              Colors.redAccent),
                          const SizedBox(width: 8),
                          _buildTestButton('Memo', 'navigate:memo',
                              Colors.orangeAccent),
                          const SizedBox(width: 8),
                          _buildTestButton('Student', 'navigate:student',
                              Colors.greenAccent),
                          const SizedBox(width: 8),
                          _buildTestButton('Travel', 'navigate:travel',
                              Colors.blueAccent),
                          const SizedBox(width: 8),
                          _buildTestButton('Email', 'navigate:email',
                              Colors.purpleAccent),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _pulseAnimation,
                              _shakeAnimation,
                            ]),
                            builder: (context, _) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/Starboy/Neutral_bot.png',
                                    width: 160,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      print('Error loading image: $error');
                                      return Center(
                                          child: Text('Image not found: $error',
                                              style: TextStyle(
                                                  color: Colors.white)));
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_isLoading)
                            const CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        Colors.white))
                          else
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _responseText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      children: [
                        GestureDetector(
                          onLongPressStart: (_) => _onHoldMicStart(),
                          onLongPressEnd: (_) => _onHoldMicEnd(),
                          onTap: () => _testVoiceCommand(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blueAccent, Colors.cyan],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.3),
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
                                Text(
                                  _isSpeaking ? 'Recording…' : 'Hold to Record',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _sendRecordingOrImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                          ),
                          child: Container(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send),
                                const SizedBox(width: 8),
                                const Text(
                                  'Send',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _takePicture,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.purpleAccent, Colors.deepPurple],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Take Picture',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ],
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

  Widget _buildTestButton(String label, String intent, Color color) {
    return ElevatedButton(
      onPressed: () => _routeByIntent(intent),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  void _testVoiceCommand() {
    setState(() {
      _responseText = 'Test voice command triggered';
    });
    HapticFeedback.selectionClick();
  }
}