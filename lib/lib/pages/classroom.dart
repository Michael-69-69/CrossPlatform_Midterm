import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ClassroomAssistantPage extends StatefulWidget {
  @override
  _ClassroomAssistantPageState createState() => _ClassroomAssistantPageState();
}

class _ClassroomAssistantPageState extends State<ClassroomAssistantPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;

  // Mock attendance data - replace with real API calls
  List<AttendanceRecord> _attendanceRecords = [
    AttendanceRecord(date: 'Oct 18, 2024', status: AttendanceStatus.present, subject: 'Mathematics'),
    AttendanceRecord(date: 'Oct 17, 2024', status: AttendanceStatus.present, subject: 'Physics'),
    AttendanceRecord(date: 'Oct 16, 2024', status: AttendanceStatus.absent, subject: 'Chemistry'),
    AttendanceRecord(date: 'Oct 15, 2024', status: AttendanceStatus.present, subject: 'English'),
    AttendanceRecord(date: 'Oct 14, 2024', status: AttendanceStatus.late, subject: 'Biology'),
  ];

  double get _attendancePercentage => 
    (_attendanceRecords.where((r) => r.status == AttendanceStatus.present).length / _attendanceRecords.length) * 100;

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
                Container(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _attendancePercentage / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      Text(
                        '${_attendancePercentage.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
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