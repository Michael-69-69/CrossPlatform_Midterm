import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/config_service.dart';

class StudentTrackerPage extends StatefulWidget {
  @override
  _StudentTrackerPageState createState() => _StudentTrackerPageState();
}

class _StudentTrackerPageState extends State<StudentTrackerPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  bool _isLoading = false;
  String _errorMessage = '';

  List<SubjectScore> _scores = [];
  String _mssv = '';
  String _password = '';

  double get _overallAverage {
    double totalScore = 0.0;
    int totalCredits = 0;
    for (var score in _scores) {
      if (score.score != null) {
        totalScore += score.score! * (score.credits ?? 0);
        totalCredits += score.credits ?? 0;
      }
    }
    return totalCredits > 0 ? totalScore / totalCredits : 0.0;
  }

  String get _grade => _getGrade(_overallAverage);

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
    _bounceController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _bounceController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mssv.isNotEmpty) {
        _loadExistingScores(_mssv);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _fetchScores(String mssv, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${ConfigService.backendUrl}/check_scores'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mssv': mssv, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('scores')) {
          List<dynamic> scoresData = data['scores'];
          setState(() {
            _scores = scoresData.map((score) {
              double? parsedScore = double.tryParse(score['score'].toString());
              return SubjectScore(
                code: score['code'] ?? '',
                subject: score['course'] ?? 'Unknown',
                credits: int.tryParse(score['credits'].toString()) ?? 0,
                score: parsedScore,
                maxScore: parsedScore != null ? 10.0 : null,
                trend: ScoreTrend.stable,
              );
            }).toList();
            _mssv = mssv;
            _password = password;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'No scores found';
            _isLoading = false;
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ?? 'Failed to fetch scores';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to server: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExistingScores(String mssv) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${ConfigService.backendUrl}/scores/$mssv'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('scores') && data['scores'].isNotEmpty) {
          List<dynamic> scoresData = data['scores'];
          setState(() {
            _scores = scoresData.map((score) {
              double? parsedScore = double.tryParse(score['score'].toString());
              return SubjectScore(
                code: score['code'] ?? '',
                subject: score['course'] ?? 'Unknown',
                credits: int.tryParse(score['credits'].toString()) ?? 0,
                score: parsedScore,
                maxScore: parsedScore != null ? 10.0 : null,
                trend: ScoreTrend.stable,
              );
            }).toList();
            _mssv = mssv;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'No existing scores found for MSSV $mssv';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load existing scores';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading scores: $e';
        _isLoading = false;
      });
    }
  }

  String _getGrade(double average) {
    if (average >= 8.5) return 'A+';
    if (average >= 8.0) return 'A';
    if (average >= 7.0) return 'B';
    if (average >= 6.0) return 'C';
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
            onPressed: _isLoading
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _bounceController.reset();
                    _bounceController.forward();
                    if (_mssv.isNotEmpty) {
                      _loadExistingScores(_mssv);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter MSSV first')),
                      );
                    }
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
                _buildInputSection(),
                SizedBox(height: 20),
                if (_isLoading)
                  _buildLoadingCard()
                else if (_errorMessage.isNotEmpty)
                  _buildErrorCard()
                else if (_scores.isNotEmpty) ...[
                  _buildOverallStatsCard(),
                  SizedBox(height: 20),
                  _buildSubjectScoresList(),
                  SizedBox(height: 20),
                  _buildPerformanceChart(),
                ] else
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

  Widget _buildInputSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Student Credentials',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'MSSV',
                hintText: 'Enter your student ID (e.g., A12345)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.school),
              ),
              onChanged: (value) => _mssv = value,
              keyboardType: TextInputType.text, // Changed to text for alphanumeric input
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')), // Allow letters and numbers
              ],
            ),
            SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.lock),
              ),
              onChanged: (value) => _password = value,
              obscureText: true,
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_mssv.isNotEmpty && _password.isNotEmpty) {
                          _fetchScores(_mssv, _password);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please enter both MSSV and password')),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Fetch Scores'),
              ),
            ),
          ],
        ),
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
              'Fetching scores...',
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
            Icon(Icons.school_outlined, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text(
              'No Scores Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Enter MSSV and password to fetch your scores',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${_scores.where((s) => s.score != null).length} subjects with scores',
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
                          'Weighted Average',
                          _overallAverage.isNaN ? 'N/A' : '${_overallAverage.toStringAsFixed(1)}/10.0',
                          Icons.trending_up,
                          Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem(
                          'Best Subject',
                          _scores.where((s) => s.score != null).isEmpty
                              ? 'N/A'
                              : _scores.where((s) => s.score != null).reduce((a, b) => a.score! > b.score! ? a : b).subject,
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
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
                color: score.score != null ? _getScoreColor(score.score!).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                _getSubjectIcon(score.subject),
                color: score.score != null ? _getScoreColor(score.score!) : Colors.grey,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Code: ${score.code}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        score.score != null ? '${score.score}/10.0' : score.scoreText ?? 'M',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: score.score != null ? _getScoreColor(score.score!) : Colors.grey,
                            ),
                      ),
                      SizedBox(width: 8),
                      if (score.score != null) _buildTrendIcon(score.trend),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Credits: ${score.credits}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (score.score != null)
              Container(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: score.score! / score.maxScore!,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score.score!)),
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

  Color _getScoreColor(double score) {
    if (score >= 8.5) return Colors.green;
    if (score >= 8.0) return Colors.blue;
    if (score >= 7.0) return Colors.orange;
    return Colors.red;
  }

  IconData _getSubjectIcon(String subject) {
    String lowerSubject = subject.toLowerCase();
    if (lowerSubject.contains('calculus') || lowerSubject.contains('algebra')) {
      return Icons.calculate;
    } else if (lowerSubject.contains('programming')) {
      return Icons.code;
    } else if (lowerSubject.contains('english')) {
      return Icons.menu_book;
    } else if (lowerSubject.contains('database')) {
      return Icons.storage;
    } else if (lowerSubject.contains('network')) {
      return Icons.network_check;
    }
    return Icons.school;
  }

  Widget _buildPerformanceChart() {
    final validScores = _scores.where((s) => s.score != null).toList();
    if (validScores.isEmpty) return SizedBox.shrink();

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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Container(height: 200, child: _buildSimpleChart(validScores)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleChart(List<SubjectScore> validScores) {
    return CustomPaint(painter: ScoreChartPainter(validScores), child: Container());
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
              child: Image.asset(
                'assets/Starboy/Neutral_bot.png', 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(child: Text('Image not found'));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class SubjectScore {
  final String code;
  final String subject;
  final int? credits;
  final double? score;
  final double? maxScore;
  final String? scoreText;
  final ScoreTrend trend;

  SubjectScore({
    required this.code,
    required this.subject,
    required this.credits,
    this.score,
    this.maxScore,
    this.scoreText,
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
    final maxScore = 10.0; // Fixed max score for consistency
    final stepX = size.width / (scores.length - 1);
    final stepY = size.height / maxScore;

    for (int i = 0; i < scores.length; i++) {
      if (scores[i].score != null) {
        final x = i * stepX;
        final y = size.height - (scores[i].score! * stepY);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    paint.color = Colors.blue;
    canvas.drawPath(path, paint);

    for (int i = 0; i < scores.length; i++) {
      if (scores[i].score != null) {
        final x = i * stepX;
        final y = size.height - (scores[i].score! * stepY);
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.blue);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}