import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/image_state.dart';
import '../services/speech_emotion_service.dart';
import '../services/gemini_service.dart';
import 'student_tracker.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final SpeechEmotionService _speechService = SpeechEmotionService();
  final GeminiService _geminiService = GeminiService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;
  bool _isSpeaking = false;

  // Emotion to GLB asset mapping
  static const Map<String, String> emotionToGlb = {
    'angry': 'assets/glb/c_angry.glb',
    'anger': 'assets/glb/c_angry.glb',
    'disgust': 'assets/glb/c_disgust.glb',
    'fear': 'assets/glb/c_fear.glb',
    'happy': 'assets/glb/c_smile.glb',
    'positive': 'assets/glb/c_smile.glb',
    'neutral': 'assets/glb/c_neutral.glb',
    'sad': 'assets/glb/c_cry.glb',
    'sadness': 'assets/glb/c_cry.glb',
    'negative': 'assets/glb/c_cry.glb',
    'surprise': 'assets/glb/c_surprise.glb',
    'surprised': 'assets/glb/c_surprise.glb',
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: Duration(milliseconds: 1600), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeController = AnimationController(duration: Duration(milliseconds: 300), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _speechService.stop(null);
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _showAlert('Microphone permission is required.');
    }
    await Permission.camera.request();
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notice'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))],
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
      SnackBar(content: Text('Image selected. Processing...')),
    );
    final intent = await _geminiService.routeIntent(text: 'analyze image', imageFile: file);
    _routeByIntent(intent);
  }

  void _onSpeechProcessed(
    String status,
    String text,
    List<Map<String, dynamic>> emotions,
    String? culturalResponse,
  ) async {
    if (!mounted) return;
    if (status.startsWith('Error')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status)));
      return;
    }
    // Update avatar by emotion
    if (emotions.isNotEmpty) {
      _updateGlbByEmotion(emotions.first['label'] as String);
    }
    // Decide destination
    final intent = await _geminiService.routeIntent(text: text, emotions: emotions);
    _routeByIntent(intent);
  }

  void _routeByIntent(String intent) {
    // Route to appropriate page based on intent
    switch (intent) {
      case 'scores:check':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => StudentTrackerPage()),
        );
        break;
      case 'email:send':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email feature coming soon!')),
        );
        break;
      case 'notes:create':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notes feature coming soon!')),
        );
        break;
      case 'alarm:set':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alarm feature coming soon!')),
        );
        break;
      case 'attendance:view':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance feature coming soon!')),
        );
        break;
      case 'travel:plan':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Travel planning feature coming soon!')),
        );
        break;
      case 'fitness:start':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fitness feature coming soon!')),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Intent: $intent')),
        );
    }
  }

  void _updateGlbByEmotion(String emotion) {
    final emotionLower = emotion.toLowerCase().trim();
    final path = emotionToGlb[emotionLower] ?? 'assets/glb/c_neutral.glb';
    
    if (path != _currentGlb) {
      setState(() {
        _currentGlb = path;
        _reloadModel = true;
      });
      Future.delayed(Duration(milliseconds: 50), () {
        if (!mounted) return;
        setState(() => _reloadModel = false);
      });
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
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('STARBOY', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                            Text('AI Personal Assistant', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
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
                          icon: Icon(Icons.health_and_safety_outlined),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_pulseAnimation, _shakeAnimation]),
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Transform.translate(
                              offset: Offset(_isSpeaking ? sin(_shakeAnimation.value * 2 * pi) * 5 : 0, 0),
                              child: SizedBox(
                                width: 260,
                                height: 260,
                                child: Visibility(
                                  visible: !_reloadModel,
                                  replacement: Center(child: CircularProgressIndicator()),
                                  child: ModelViewer(
                                    key: ValueKey('$_currentGlb$_reloadModel'),
                                    backgroundColor: Colors.transparent,
                                    src: _currentGlb,
                                    alt: 'STARBOY Avatar',
                                    ar: false,
                                    autoRotate: !_isSpeaking,
                                    autoRotateDelay: 3000,
                                    rotationPerSecond: '30deg',
                                    cameraControls: true,
                                    disableZoom: true,
                                    touchAction: TouchAction.none,
                                    interactionPrompt: InteractionPrompt.none,
                                    cameraOrbit: '0deg 75deg 4.5m',
                                    minCameraOrbit: 'auto 50deg auto',
                                    maxCameraOrbit: 'auto 100deg auto',
                                    fieldOfView: '30deg',
                                    loading: Loading.eager,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onLongPressStart: (_) => _onHoldMicStart(),
                            onLongPressEnd: (_) => _onHoldMicEnd(),
                            child: Semantics(
                              label: 'Hold to talk',
                              button: true,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.mic, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(_isSpeaking ? 'Listening…' : 'Hold to Talk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _onPickMedia,
                            borderRadius: BorderRadius.circular(16),
                            child: Semantics(
                              label: 'Add media',
                              button: true,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, color: Theme.of(context).colorScheme.onSecondaryContainer),
                                    SizedBox(width: 8),
                                    Text('Add Media', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
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