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

  // NEW: Constants for day selection and sounds
  final List<String> _dayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _soundOptions = ['Default Ringtone', 'Energetic Beep', 'Calm Bell', 'Focus Chime', 'None'];

  // UPDATED: Mock alarm data to use TimeOfDay and Set<String>
  List<Alarm> _alarms = [
    Alarm(
      id: 1,
      title: 'Wake Up',
      time: TimeOfDay(hour: 7, minute: 0),
      days: {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'},
      isActive: true,
      sound: 'Default Ringtone',
    ),
    Alarm(
      id: 2,
      title: 'Gym Time',
      time: TimeOfDay(hour: 6, minute: 30),
      days: {'Mon', 'Wed', 'Fri'},
      isActive: true,
      sound: 'Energetic Beep',
    ),
    Alarm(
      id: 3,
      title: 'Meditation',
      time: TimeOfDay(hour: 20, minute: 0),
      days: {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'},
      isActive: false,
      sound: 'Calm Bell',
    ),
    Alarm(
      id: 4,
      title: 'Study Time',
      time: TimeOfDay(hour: 14, minute: 0),
      days: {'Tue', 'Thu', 'Sat'},
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
      _alarms[index] = alarm.copyWith(isActive: !alarm.isActive);
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

  // NEW: Add/Edit Alarm Function
  void _showAddOrEditAlarmDialog({Alarm? existingAlarm}) async {
    final _titleController = TextEditingController(text: existingAlarm?.title);
    TimeOfDay _selectedTime = existingAlarm?.time ?? TimeOfDay.now();
    Set<String> _selectedDays = Set.from(existingAlarm?.days ?? {});
    String _selectedSound = existingAlarm?.sound ?? _soundOptions.first;
    
    // Use preset data if alarm is null but we are using a preset
    if (existingAlarm != null && existingAlarm.id == -1) {
      _titleController.text = existingAlarm.title;
      _selectedTime = existingAlarm.time;
      _selectedDays = existingAlarm.days;
      _selectedSound = existingAlarm.sound;
    }

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for keyboard
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existingAlarm?.id == -1 || existingAlarm == null ? 'New Alarm' : 'Edit Alarm',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Time', style: Theme.of(context).textTheme.titleMedium),
                      trailing: TextButton(
                        onPressed: () async {
                          final newTime = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (newTime != null) {
                            setModalState(() {
                              _selectedTime = newTime;
                            });
                          }
                        },
                        child: Text(
                          _selectedTime.format(context),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Repeat', style: Theme.of(context).textTheme.titleMedium),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _dayAbbreviations.map((day) {
                        final isSelected = _selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setModalState(() {
                              if (selected) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                          shape: CircleBorder(),
                          padding: EdgeInsets.all(10),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: Theme.of(context).colorScheme.primary,
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSound,
                      decoration: InputDecoration(
                        labelText: 'Sound',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _soundOptions.map((sound) {
                        return DropdownMenuItem(
                          value: sound,
                          child: Text(sound),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            _selectedSound = value;
                          });
                        }
                      },
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false), // Return false for cancel
                            child: Text('Cancel'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final title = _titleController.text;
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Title cannot be empty!')),
                                );
                                return;
                              }

                              if (existingAlarm == null || existingAlarm.id == -1) {
                                // Add new alarm
                                final newAlarm = Alarm(
                                  id: DateTime.now().millisecondsSinceEpoch,
                                  title: title,
                                  time: _selectedTime,
                                  days: _selectedDays,
                                  isActive: true,
                                  sound: _selectedSound,
                                );
                                setState(() {
                                  _alarms.insert(0, newAlarm);
                                });
                              } else {
                                // Update existing alarm
                                final updatedAlarm = existingAlarm.copyWith(
                                  title: title,
                                  time: _selectedTime,
                                  days: _selectedDays,
                                  sound: _selectedSound,
                                );
                                setState(() {
                                  final index = _alarms.indexWhere((m) => m.id == existingAlarm.id);
                                  if (index != -1) {
                                    _alarms[index] = updatedAlarm;
                                  }
                                });
                              }
                              Navigator.pop(context, true); // Return true for save
                            },
                            child: Text('Save'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Alarm Scheduler'),
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
              // UPDATED: Hook up add function
              _showAddOrEditAlarmDialog();
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
                _buildQuickPresets(), // NEW: Quick Presets
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
  
  // NEW: Quick Presets Widget
  Widget _buildQuickPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Presets',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () {
                  _showAddOrEditAlarmDialog(
                    existingAlarm: Alarm(
                      id: -1, // Use -1 to signify a preset
                      title: 'Wake Up',
                      time: TimeOfDay(hour: 7, minute: 0),
                      days: {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'},
                      isActive: true,
                      sound: 'Default Ringtone',
                    ),
                  );
                },
                child: Text('Morning (7 AM)'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () {
                  _showAddOrEditAlarmDialog(
                    existingAlarm: Alarm(
                      id: -1,
                      title: 'Study Time',
                      time: TimeOfDay(hour: 14, minute: 0),
                      days: {'Mon', 'Wed', 'Fri'},
                      isActive: true,
                      sound: 'Focus Chime',
                    ),
                  );
                },
                child: Text('Study (2 PM)'),
              ),
            ),
          ],
        ),
      ],
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

  // NEW: Helper widget for the day visual
  Widget _buildDayChip(String day, bool isActive) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.withOpacity(0.8) : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          day.substring(0, 1), // M, T, W...
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                            // UPDATED: Format TimeOfDay
                            alarm.time.format(context),
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
            // UPDATED: Replaced Wrap with visual day selector
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _dayAbbreviations.map((day) {
                  return _buildDayChip(day, alarm.days.contains(day));
                }).toList(),
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
                      // UPDATED: Hook up edit function
                      _showAddOrEditAlarmDialog(existingAlarm: alarm);
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
  final TimeOfDay time; // UPDATED
  final Set<String> days; // UPDATED
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

  // NEW: copyWith method for easier updates
  Alarm copyWith({
    String? title,
    TimeOfDay? time,
    Set<String>? days,
    bool? isActive,
    String? sound,
  }) {
    return Alarm(
      id: this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      days: days ?? this.days,
      isActive: isActive ?? this.isActive,
      sound: sound ?? this.sound,
    );
  }
}