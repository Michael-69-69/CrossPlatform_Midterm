import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/config_service.dart';

class AlarmSchedulerPage extends StatefulWidget {
  @override
  _AlarmSchedulerPageState createState() => _AlarmSchedulerPageState();
}

class _AlarmSchedulerPageState extends State<AlarmSchedulerPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;
  bool _isLoading = false;
  String _errorMessage = '';

  // Real alarm data from database
  List<AlarmData> _alarms = [];
  String _newAlarmTitle = '';
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _userId = 'default_user'; // In a real app, this would come from user authentication

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Load alarms when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAlarms();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadAlarms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${ConfigService.backendUrl}/alarms/$_userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final alarmsData = data['alarms'] as List<dynamic>;
        setState(() {
          _alarms = alarmsData.map((alarm) => AlarmData.fromJson(alarm)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error loading alarms: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading alarms: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createAlarm() async {
    if (_newAlarmTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter alarm title')));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      DateTime now = DateTime.now();
      DateTime alarmTime = DateTime(
        now.year,
        now.month,
        now.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // If the time has passed today, set for tomorrow
      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(Duration(days: 1));
      }

      final alarmData = AlarmData(
        id: '', // Will be set by the server
        title: _newAlarmTitle,
        time: alarmTime,
        isActive: true,
      );

      // Save to database
      final response = await http.post(
        Uri.parse('${ConfigService.backendUrl}/alarms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'title': alarmData.title,
          'alarm_time': alarmData.time.toIso8601String(),
          'is_active': alarmData.isActive,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final savedAlarm = AlarmData.fromJson(data['alarm']);
        setState(() {
          _alarms.add(savedAlarm);
          _isLoading = false;
          _newAlarmTitle = '';
        });
      } else {
        setState(() {
          _errorMessage = 'Error creating alarm: ${response.statusCode}';
          _isLoading = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alarm set for ${_selectedTime.format(context)}')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating alarm: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAlarm(String alarmId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('${ConfigService.backendUrl}/alarms/$alarmId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _alarms.removeWhere((alarm) => alarm.id == alarmId);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alarm deleted')));
      } else {
        setState(() {
          _errorMessage = 'Error deleting alarm: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error deleting alarm: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAlarm(String alarmId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final alarmIndex = _alarms.indexWhere((a) => a.id == alarmId);
      if (alarmIndex != -1) {
        final alarm = _alarms[alarmIndex];
        final newActiveState = !alarm.isActive;

        final response = await http.put(
          Uri.parse('${ConfigService.backendUrl}/alarms/$alarmId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'is_active': newActiveState}),
        );

        if (response.statusCode == 200) {
          final updatedAlarm = AlarmData(
            id: alarm.id,
            title: alarm.title,
            time: alarm.time,
            isActive: newActiveState,
          );

          setState(() {
            _alarms[alarmIndex] = updatedAlarm;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Error updating alarm: ${response.statusCode}';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error toggling alarm: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('AlarmScheduler'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _loadAlarms(),
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _isLoading ? null : () => _showAddAlarmDialog(),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAlarmStatsCard(),
                SizedBox(height: 24),
                if (_isLoading)
                  _buildLoadingCard()
                else if (_errorMessage.isNotEmpty)
                  _buildErrorCard()
                else if (_alarms.isNotEmpty)
                  _buildAlarmsSection()
                else
                  _buildEmptyStateCard(),
                SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(bottom: 20, right: 20, child: _buildFloatingAvatar()),
        ],
      ),
    );
  }

  void _showAddAlarmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set New Alarm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Alarm Title',
                hintText: 'Enter alarm title...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _newAlarmTitle = value,
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: Icon(Icons.access_time),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (picked != null) {
                  setState(() {
                    _selectedTime = picked;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createAlarm();
            },
            child: Text('Set Alarm'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading alarms...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                });
              },
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.alarm_outlined, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text(
              'No Alarms Set',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to set your first alarm',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmStatsCard() {
    final activeAlarms = _alarms.length; // All alarms are active in the new system

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Alarms',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${_alarms.length} total alarms',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$activeAlarms Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildAlarmStatItem(
                    'Total',
                    '${_alarms.length}',
                    Icons.alarm,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildAlarmStatItem(
                    'Active',
                    '$activeAlarms',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildAlarmStatItem(
                    'Inactive',
                    '${_alarms.length - activeAlarms}',
                    Icons.stop_circle,
                    Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Alarms',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12),
        if (_alarms.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.alarm_off, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No alarms set',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ..._alarms.map((alarm) => _buildAlarmCard(alarm)).toList(),
      ],
    );
  }

  Widget _buildAlarmCard(AlarmData alarm) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Text(
                            TimeOfDay.fromDateTime(alarm.time).format(context),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: alarm.isActive,
                    onChanged: (_) => _toggleAlarm(alarm.id),
                    activeColor: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    alarm.time.toString().split(' ')[0],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.music_note, size: 14, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'Default Ringtone',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteAlarm(alarm.id),
                  tooltip: 'Delete alarm',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Visibility(
                visible: !_reloadModel,
                replacement: Container(
                  color: Colors.grey.shade200,
                  child: Center(child: CircularProgressIndicator()),
                ),
                child: ModelViewer(
                  key: ValueKey('$_currentGlb$_reloadModel'),
                  backgroundColor: Colors.transparent,
                  src: _currentGlb,
                  alt: 'STARBOY',
                  ar: false,
                  autoRotate: true,
                  autoRotateDelay: 2000,
                  rotationPerSecond: '20deg',
                  cameraControls: false,
                  disableZoom: true,
                  touchAction: TouchAction.none,
                  interactionPrompt: InteractionPrompt.none,
                  cameraOrbit: '0deg 75deg 2m',
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
    );
  }
}

class AlarmData {
  final String id;
  final String title;
  final DateTime time;
  final bool isActive;

  AlarmData({
    required this.id,
    required this.title,
    required this.time,
    required this.isActive,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'time': time.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory AlarmData.fromJson(Map<String, dynamic> json) {
    return AlarmData(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      time: DateTime.parse(json['alarm_time'] ?? json['time']),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
    );
  }
}