import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class StudentTrackerPage extends StatefulWidget {
  @override
  _StudentTrackerPageState createState() => _StudentTrackerPageState();
}

class _StudentTrackerPageState extends State<StudentTrackerPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;

  // Mock data - replace with real API calls
  List<SubjectScore> _scores = [
    SubjectScore(subject: 'Mathematics', score: 85, maxScore: 100, trend: ScoreTrend.up),
    SubjectScore(subject: 'Physics', score: 78, maxScore: 100, trend: ScoreTrend.down),
    SubjectScore(subject: 'Chemistry', score: 92, maxScore: 100, trend: ScoreTrend.up),
    SubjectScore(subject: 'Biology', score: 88, maxScore: 100, trend: ScoreTrend.stable),
    SubjectScore(subject: 'English', score: 90, maxScore: 100, trend: ScoreTrend.up),
  ];

  double get _overallAverage => _scores.fold(0.0, (sum, score) => sum + score.score) / _scores.length;
  String get _grade => _getGrade(_overallAverage);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: Duration(milliseconds: 2000), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _bounceController = AnimationController(duration: Duration(milliseconds: 600), vsync: this);
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _bounceController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  String _getGrade(double average) {
    if (average >= 90) return 'A+';
    if (average >= 80) return 'A';
    if (average >= 70) return 'B';
    if (average >= 60) return 'C';
    return 'D';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Student Score Tracker'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              _bounceController.reset();
              _bounceController.forward();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Scores refreshed!')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverallStatsCard(),
                SizedBox(height: 20),
                _buildSubjectScoresList(),
                SizedBox(height: 20),
                _buildPerformanceChart(),
                SizedBox(height: 100), // Space for floating avatar
              ],
            ),
          ),
          // Floating STARBOY avatar
          Positioned(
            bottom: 20,
            right: 20,
            child: _buildFloatingAvatar(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatsCard() {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_bounceAnimation.value * 0.1),
          child: Card(
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
                            'Overall Performance',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${_scores.length} subjects tracked',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getGradeColor(_grade),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Grade: $_grade',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Average',
                          '${_overallAverage.toStringAsFixed(1)}%',
                          Icons.trending_up,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem(
                          'Best Subject',
                          _scores.reduce((a, b) => a.score > b.score ? a : b).subject,
                          Icons.star,
                          Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
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

  Widget _buildSubjectScoresList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject Scores',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        ..._scores.map((score) => _buildSubjectCard(score)).toList(),
      ],
    );
  }

  Widget _buildSubjectCard(SubjectScore score) {
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
                color: _getScoreColor(score.score).withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                _getSubjectIcon(score.subject),
                color: _getScoreColor(score.score),
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    score.subject,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${score.score}/${score.maxScore}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(score.score),
                        ),
                      ),
                      SizedBox(width: 8),
                      _buildTrendIcon(score.trend),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: score.score / score.maxScore,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score.score)),
                strokeWidth: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIcon(ScoreTrend trend) {
    IconData icon;
    Color color;
    
    switch (trend) {
      case ScoreTrend.up:
        icon = Icons.trending_up;
        color = Colors.green;
        break;
      case ScoreTrend.down:
        icon = Icons.trending_down;
        color = Colors.red;
        break;
      case ScoreTrend.stable:
        icon = Icons.trending_flat;
        color = Colors.blue;
        break;
    }
    
    return Icon(icon, color: color, size: 20);
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.blue;
    if (score >= 70) return Colors.orange;
    return Colors.red;
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return Icons.calculate;
      case 'physics':
        return Icons.science;
      case 'chemistry':
        return Icons.biotech;
      case 'biology':
        return Icons.eco;
      case 'english':
        return Icons.menu_book;
      default:
        return Icons.school;
    }
  }

  Widget _buildPerformanceChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: _buildSimpleChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleChart() {
    return CustomPaint(
      painter: ScoreChartPainter(_scores),
      child: Container(),
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

class SubjectScore {
  final String subject;
  final int score;
  final int maxScore;
  final ScoreTrend trend;

  SubjectScore({
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.trend,
  });
}

enum ScoreTrend { up, down, stable }

class ScoreChartPainter extends CustomPainter {
  final List<SubjectScore> scores;

  ScoreChartPainter(this.scores);

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    final maxScore = scores.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    final stepX = size.width / (scores.length - 1);
    final stepY = size.height / maxScore;

    for (int i = 0; i < scores.length; i++) {
      final x = i * stepX;
      final y = size.height - (scores[i].score * stepY);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    paint.color = Colors.blue;
    canvas.drawPath(path, paint);

    // Draw points
    for (int i = 0; i < scores.length; i++) {
      final x = i * stepX;
      final y = size.height - (scores[i].score * stepY);
      
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = Colors.blue,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
