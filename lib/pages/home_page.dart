import 'dart:async'; // Added for Future.delayed
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
import 'package:animated_text_kit/animated_text_kit.dart'; // Added for typewriter
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // fixed import
import '../models/image_state.dart';
import '../services/speech_emotion_service.dart';
import '../services/gemini_service.dart';
import 'student_tracker.dart';
import 'alarm.dart' hide Alarm;
import 'memo.dart';
import 'travel.dart';
import 'classroom.dart';

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

  bool _showTutorial = false;
  List<Map<String, dynamic>> _recentActivity = [];

  // NEW: State for sliding panel
  final DraggableScrollableController _scrollController = DraggableScrollableController();
  bool _isPanelExpanded = false;

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
    _welcomeUser(); // Added welcome message call

    // NEW: Listener for panel state
    _scrollController.addListener(_onScroll);
  }

  // NEW: Listener to update panel state
  void _onScroll() {
    double position = _scrollController.size;
    // Check if it's near the max size
    if (position > 0.75 && !_isPanelExpanded) {
      setState(() {
        _isPanelExpanded = true;
      });
    }
    // Check if it's near the min size
    else if (position < 0.2 && _isPanelExpanded) {
      setState(() {
        _isPanelExpanded = false;
      });
    }
  }

  // Added welcome message method
  void _welcomeUser() async {
    // Wait a moment for the app to settle
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _responseText = "Hi! How can I help you today?";
        _isSpeaking = true;
        _shakeController.repeat(reverse: true);
      });
      await _flutterTts.speak(_responseText);
    }
  }

  void _showHelpTutorial() {
  setState(() {
    _showTutorial = true;
  });
  }

  void _closeTutorial() {
  setState(() {
    _showTutorial = false;
  });
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
    _scrollController.dispose(); // NEW
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
    // NEW: Track image activity
    setState(() {
      _recentActivity.insert(0, {
        'type': 'image',
        'content': 'Image analyzed',
        'time': DateTime.now(),
        'icon': Icons.image,
      });
      if (_recentActivity.length > 7) _recentActivity.removeLast();
    });
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
    setState(() {
      _recentActivity.insert(0, {
      'type': 'speech',
      'content': text.length > 50 ? text.substring(0, 50) + '...' : text,
      'time': DateTime.now(),
      'icon': Icons.mic,
  });
  if (_recentActivity.length > 7) _recentActivity.removeLast();
  });

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
    // NEW: Track navigation
    String pageName = '';
    IconData pageIcon = Icons.apps;
    
    switch (intent) {
      case 'scores:check':
        pageName = 'Student Tracker';
        pageIcon = Icons.school;
        Navigator.push(context, MaterialPageRoute(builder: (context) => StudentTrackerPage()));
        break;
      case 'travel:plan':
        pageName = 'Travel Guide';
        pageIcon = Icons.flight;
        Navigator.push(context, MaterialPageRoute(builder: (context) => TravelGuidePage()));
        break;
      case 'notes:create':
        pageName = 'Memo Keeper';
        pageIcon = Icons.note;
        Navigator.push(context, MaterialPageRoute(builder: (context) => MemoKeeperPage()));
        break;
      case 'alarm:set':
        pageName = 'Alarm Scheduler';
        pageIcon = Icons.alarm;
        Navigator.push(context, MaterialPageRoute(builder: (context) => AlarmSchedulerPage()));
        break;
      case 'clear:all':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared via voice')));
        return; // Don't track this
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Intent: $intent')));
        return; // Don't track unknown intents
    }
    
    // NEW: Add to activity log
    if (pageName.isNotEmpty) {
      setState(() {
        _recentActivity.insert(0, {
          'type': 'navigation',
          'content': 'Opened $pageName',
          'time': DateTime.now(),
          'icon': pageIcon,
        });
        if (_recentActivity.length > 7) _recentActivity.removeLast();
      });
    }
  }

  // Added helper method for card taps
  void _handleCardTap(String title, IconData icon, VoidCallback onTap) {
    HapticFeedback.lightImpact();
    setState(() {
      _recentActivity.insert(0, {
        'type': 'navigation',
        'content': 'Opened $title',
        'time': DateTime.now(),
        'icon': icon,
      });
      if (_recentActivity.length > 7) _recentActivity.removeLast();
    });
    onTap(); // Execute the navigation
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ImageState>(
      builder: (context, imageState, child) {
        return Stack(
          children: [
            Scaffold(
              // --- APPBAR UPDATED ---
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                // NEW: Animated bot icon in AppBar
                leading: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isPanelExpanded ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.smart_toy,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STARBOY',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      'AI Personal Assistant',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Show voice commands',
                    onPressed: _showHelpTutorial,
                    icon: const Icon(Icons.help_outline),
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
              // --- BODY UPDATED ---
              body: Container(
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
                // NEW: Stack for bot and sliding panel
                child: Stack(
                  children: [
                    // --- LAYER 1: The Maximized Bot ---
                    _buildMaximizedBot(),

                    // --- LAYER 2: The Sliding Panel ---
                    _buildSlidingPanel(),
                  ],
                ),
              ),
              // --- BOTTOMNAVBAR UPDATED ---
              bottomNavigationBar: _buildBottomMicBar(),
            ), 
            
            // Tutorial Overlay (remains the same)
            if (_showTutorial)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Voice Commands',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: _closeTutorial,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCommandExample('Navigation', [
                            'Open student tracker',
                            'Show my alarms',
                            'Take me to travel page',
                          ]),
                          const SizedBox(height: 12),
                          _buildCommandExample('Actions', [
                            'Set alarm for 7 AM',
                            'Check my scores',
                            'Create a new memo',
                          ]),
                          const SizedBox(height: 12),
                          _buildCommandExample('General', [
                            'What\'s in this image?',
                            'Tell me a joke',
                            'How are you today?',
                          ]),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Hold the microphone button and speak clearly',
                                    style: TextStyle(fontSize: 12, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
      );
    },
  );
}

  // --- NEW WIDGETS ---

  Widget _buildMaximizedBot() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isPanelExpanded ? 0.0 : 1.0, // Fade out when panel expands
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
                    size: 120,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const CircularProgressIndicator()
            // --- Replaced Text with Typewriter Effect ---
            else if (_responseText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AnimatedTextKit(
                  key: ValueKey(_responseText), // Ensures it reruns on new text
                  animatedTexts: [
                    TypewriterAnimatedText(
                      _responseText,
                      textAlign: TextAlign.center,
                      textStyle: const TextStyle(fontSize: 14, color: Colors.black87),
                      speed: const Duration(milliseconds: 50),
                    ),
                  ],
                  totalRepeatCount: 1,
                  isRepeatingAnimation: false,
                ),
              ),
            // --- End of replacement ---
            const SizedBox(height: 100), // Space for bottom bar
          ],
        ),
      ),
    );
  }

  Widget _buildSlidingPanel() {
    return DraggableScrollableSheet(
      controller: _scrollController,
      initialChildSize: 0.15, // Start minimized
      minChildSize: 0.15,
      maxChildSize: 0.85, // Max height
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.1),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                _buildPanelHandle(),
                // This is the content that was in the old SingleChildScrollView
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildQuickActionCards(),
                      const SizedBox(height: 16),
                      _buildRecentActivity(),
                      const SizedBox(height: 24), // Add padding at bottom
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelHandle() {
    return InkWell(
      onTap: () {
        if (_isPanelExpanded) {
          _scrollController.animateTo(
            0.15,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _scrollController.animateTo(
            0.85,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Container( // The "grip"
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Icon(
              _isPanelExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomMicBar() {
    // This is the Padding(...) widget cut from the bottom of the old Column
    return Padding(
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
    );
  }
  // --- END NEW WIDGETS ---


  Widget _buildQuickActionCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // --- Added Entry Animations ---
        AnimationLimiter(
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: [
                _buildSplitTrackerCard(), // Replaced single card with split card
                _buildActionCard(
                  'Alarms',
                  Icons.alarm,
                  Colors.orange,
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => AlarmSchedulerPage())),
                ),
                _buildActionCard(
                  'Memos',
                  Icons.note,
                  Colors.green,
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => MemoKeeperPage())),
                ),
                _buildActionCard(
                  'Travel Guide',
                  Icons.flight,
                  Colors.purple,
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => TravelGuidePage())),
                ),
              ],
            ),
          ),
        ),
        // --- End of animation ---
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _handleCardTap(title, icon, onTap), // Updated to use helper
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ));
  }

  // Added new widget for the split card
  Widget _buildSplitTrackerCard() {
    const Color cardColor = Colors.blue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // Ensures InkWell ripples are clipped
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cardColor.withOpacity(0.1),
              cardColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Row(
          children: [
            // Box 1: Student Tracker
            Expanded(
              child: InkWell(
                onTap: () => _handleCardTap(
                  'Student Tracker',
                  Icons.school,
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => StudentTrackerPage())),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: 36, color: cardColor),
                      const SizedBox(height: 8),
                      Text(
                        'Student Tracker',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cardColor.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Divider
            VerticalDivider(width: 1, thickness: 1, color: Colors.black.withOpacity(0.05)),

            // Box 2: Classroom
            Expanded(
              child: InkWell(
                onTap: () => _handleCardTap(
                  'Classroom',
                  Icons.class_outlined,
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => ClassroomPage())),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_outlined, size: 36, color: cardColor),
                      const SizedBox(height: 8),
                      Text(
                        'Classroom',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cardColor.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Updated with Empty State ---
  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Your activity will appear here',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _recentActivity.clear();
                  });
                },
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: AnimationLimiter( // Added animation
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentActivity.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final activity = _recentActivity[index];
                final time = activity['time'] as DateTime;
                final now = DateTime.now();
                final diff = now.difference(time);
                String timeAgo;
                if (diff.inMinutes < 1) {
                  timeAgo = 'Just now';
                } else if (diff.inMinutes < 60) {
                  timeAgo = '${diff.inMinutes}m ago';
                } else {
                  timeAgo = '${diff.inHours}h ago';
                }

                return AnimationConfiguration.staggeredList( // Added animation
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Icon(
                            activity['icon'] as IconData,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          activity['content'] as String,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  // --- End of update ---

  Widget _buildCommandExample(String category, List<String> examples) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        ...examples.map((cmd) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            children: [
              const Icon(Icons.mic, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"$cmd"',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }
}