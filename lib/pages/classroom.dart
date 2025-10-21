import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ClassroomPage extends StatefulWidget { // Renamed to match file
  @override
  _ClassroomPageState createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;

  // Mock attendance data
  final List<AttendanceRecord> _attendanceRecords = [
    AttendanceRecord(date: 'Oct 21, 2025', status: AttendanceStatus.present, subject: 'Mathematics'),
    AttendanceRecord(date: 'Oct 20, 2025', status: AttendanceStatus.present, subject: 'Physics'),
    AttendanceRecord(date: 'Oct 19, 2025', status: AttendanceStatus.present, subject: 'Chemistry'),
    AttendanceRecord(date: 'Oct 18, 2025', status: AttendanceStatus.absent, subject: 'English'),
    AttendanceRecord(date: 'Oct 17, 2025', status: AttendanceStatus.present, subject: 'Biology'),
    AttendanceRecord(date: 'Oct 16, 2025', status: AttendanceStatus.present, subject: 'Mathematics'),
    AttendanceRecord(date: 'Oct 15, 2025', status: AttendanceStatus.late, subject: 'Physics'),
  ];

  // NEW: Mock schedule data
  final List<Map<String, String>> _todaysSchedule = [
    {'subject': 'Mathematics', 'time': '09:00 AM', 'room': 'B-102'},
    {'subject': 'Physics', 'time': '11:00 AM', 'room': 'C-305'},
    {'subject': 'English', 'time': '02:00 PM', 'room': 'A-110'},
  ];

  // NEW: Mock test data
  final List<Map<String, String>> _upcomingTests = [
    {'subject': 'Chemistry', 'type': 'Midterm Exam', 'date': 'Oct 24, 2025'},
    {'subject': 'Biology', 'type': 'Quiz 4', 'date': 'Oct 27, 2025'},
  ];

  // NEW: Mock teacher data
  final Map<String, Map<String, String>> _teacherInfo = {
    'Mathematics': {'name': 'Prof. Alan Turing', 'email': 'a.turing@school.edu', 'office': 'D-201'},
    'Physics': {'name': 'Prof. Marie Curie', 'email': 'm.curie@school.edu', 'office': 'C-301'},
    'Chemistry': {'name': 'Prof. Linus Pauling', 'email': 'l.pauling@school.edu', 'office': 'C-404'},
    'English': {'name': 'Prof. Jane Austen', 'email': 'j.austen@school.edu', 'office': 'A-105'},
    'Biology': {'name': 'Prof. Gregor Mendel', 'email': 'g.mendel@school.edu', 'office': 'E-112'},
  };

  double get _attendancePercentage => 
    (_attendanceRecords.where((r) => r.status == AttendanceStatus.present).length / _attendanceRecords.length) * 100;

  // NEW: Calculate streak
  int get _attendanceStreak {
    int streak = 0;
    for (var record in _attendanceRecords) {
      if (record.status == AttendanceStatus.present) {
        streak++;
      } else {
        break; // Stop at the first non-present day
      }
    }
    return streak;
  }

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

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.late:
        return Colors.orange;
    }
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
    }
  }

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle;
      case AttendanceStatus.absent:
        return Icons.cancel;
      case AttendanceStatus.late:
        return Icons.schedule;
    }
  }

  // NEW: Function to show class details modal
  void _showClassDetails(AttendanceRecord record) {
    HapticFeedback.lightImpact();
    final teacher = _teacherInfo[record.subject] ?? 
        {'name': 'N/A', 'email': 'N/A', 'office': 'N/A'};
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.subject,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(_getStatusIcon(record.status), color: _getStatusColor(record.status)),
                title: Text('Status on ${record.date}'),
                trailing: Text(
                  _getStatusText(record.status),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(record.status),
                  ),
                ),
              ),
              Divider(height: 24),
              Text(
                'Teacher Contact Info',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              ListTile(dense: true, leading: Icon(Icons.person_outline), title: Text(teacher['name']!)),
              ListTile(dense: true, leading: Icon(Icons.email_outlined), title: Text(teacher['email']!)),
              ListTile(dense: true, leading: Icon(Icons.meeting_room_outlined), title: Text('Office: ${teacher['office']}')),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Classroom Assistant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAttendanceSummaryCard(),
                SizedBox(height: 24),
                _buildTodaysSchedule(), // NEW
                SizedBox(height: 24),
                _buildUpcomingTests(), // NEW
                SizedBox(height: 24),
                _buildAttendanceHistorySection(),
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

  Widget _buildAttendanceSummaryCard() {
    final streak = _attendanceStreak;
    final double goalPercentage = 0.95; // 95% goal
    final double currentGoalProgress = _attendancePercentage / (goalPercentage * 100);

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
                      'Attendance Summary',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${_attendanceRecords.length} records',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                // replace the previous Container (width:100,height:100) block with this safer, smaller, padded widget
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: CircularProgressIndicator(
                            value: (_attendancePercentage / 100).clamp(0.0, 1.0),
                            strokeWidth: 8,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${_attendancePercentage.toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // NEW: Streak Badge
            if (streak > 2)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '$streak-Day Attendance Streak!',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Present',
                    _attendanceRecords.where((r) => r.status == AttendanceStatus.present).length.toString(),
                    Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Absent',
                    _attendanceRecords.where((r) => r.status == AttendanceStatus.absent).length.toString(),
                    Colors.red,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Late',
                    _attendanceRecords.where((r) => r.status == AttendanceStatus.late).length.toString(),
                    Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            // NEW: Attendance Goal
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Goal: ${(goalPercentage * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: currentGoalProgress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
          ),
        ],
      ),
    );
  }

  // NEW: Today's Schedule Widget
  Widget _buildTodaysSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Schedule",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _todaysSchedule.length,
            separatorBuilder: (context, index) => SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _todaysSchedule[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: 160,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['subject']!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Text(
                            item['time']!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.meeting_room, size: 14, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Text(
                            item['room']!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // NEW: Upcoming Tests Widget
  Widget _buildUpcomingTests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Tests',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: _upcomingTests.map((test) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.edit_calendar, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Text(
                    test['subject']!,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(test['type']!),
                  trailing: Text(
                    test['date']!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent History',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        ..._attendanceRecords.map((record) => _buildAttendanceCard(record)).toList(),
      ],
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( // UPDATED: Wrapped in InkWell
        onTap: () => _showClassDetails(record), // UPDATED: Added onTap
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getStatusColor(record.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(
                  _getStatusIcon(record.status),
                  color: _getStatusColor(record.status),
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.subject,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      record.date,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(record.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(record.status),
                  style: TextStyle(
                    color: _getStatusColor(record.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
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

class AttendanceRecord {
  final String date;
  final AttendanceStatus status;
  final String subject;

  AttendanceRecord({
    required this.date,
    required this.status,
    required this.subject,
  });
}

enum AttendanceStatus { present, absent, late }