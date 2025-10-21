import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class AlarmSchedulerPage extends StatefulWidget {
  @override
  _AlarmSchedulerPageState createState() => _AlarmSchedulerPageState();
}

class _AlarmSchedulerPageState extends State<AlarmSchedulerPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;

  // Mock alarm data - replace with real API calls
  List<Alarm> _alarms = [
    Alarm(
      id: 1,
      title: 'Wake Up',
      time: '07:00 AM',
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      isActive: true,
      sound: 'Default Ringtone',
    ),
    Alarm(
      id: 2,
      title: 'Gym Time',
      time: '06:30 AM',
      days: ['Monday', 'Wednesday', 'Friday'],
      isActive: true,
      sound: 'Energetic Beep',
    ),
    Alarm(
      id: 3,
      title: 'Meditation',
      time: '08:00 PM',
      days: ['Daily'],
      isActive: false,
      sound: 'Calm Bell',
    ),
    Alarm(
      id: 4,
      title: 'Study Time',
      time: '02:00 PM',
      days: ['Tuesday', 'Thursday', 'Saturday'],
      isActive: true,
      sound: 'Focus Chime',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: Duration(milliseconds: 2000), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleAlarm(int id) {
    setState(() {
      final index = _alarms.indexWhere((a) => a.id == id);
      final alarm = _alarms[index];
      _alarms[index] = Alarm(
        id: alarm.id,
        title: alarm.title,
        time: alarm.time,
        days: alarm.days,
        isActive: !alarm.isActive,
        sound: alarm.sound,
      );
    });
  }

  void _deleteAlarm(int id) {
    setState(() {
      _alarms.removeWhere((alarm) => alarm.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Alarm deleted')),
    );
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
            icon: Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Create new alarm coming soon!')),
              );
            },
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
                _buildAlarmsSection(),
                SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: _buildFloatingAvatar(),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmStatsCard() {
    final activeAlarms = _alarms.where((a) => a.isActive).length;

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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildAlarmStatItem(String label, String value, IconData icon, Color color) {
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
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

  Widget _buildAlarmCard(Alarm alarm) {
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
                            alarm.time,
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
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: alarm.days.map((day) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
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
                    alarm.sound,
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
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Edit alarm coming soon!')),
                      );
                    },
                    child: Text('Edit'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _deleteAlarm(alarm.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: Text('Delete'),
                  ),
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

class Alarm {
  final int id;
  final String title;
  final String time;
  final List<String> days;
  final bool isActive;
  final String sound;

  Alarm({
    required this.id,
    required this.title,
    required this.time,
    required this.days,
    required this.isActive,
    required this.sound,
  });
}