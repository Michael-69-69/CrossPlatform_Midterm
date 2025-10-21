import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class MemoKeeperPage extends StatefulWidget {
  @override
  _MemoKeeperPageState createState() => _MemoKeeperPageState();
}

class _MemoKeeperPageState extends State<MemoKeeperPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;

  // Mock memo data - replace with real API calls
  List<Memo> _memos = [
    Memo(
      id: 1,
      title: 'Project Deadline',
      content: 'Submit the Flutter app by November 30th',
      createdDate: 'Oct 18, 2024',
      expiryDate: 'Nov 30, 2024',
      priority: MemoPriority.high,
    ),
    Memo(
      id: 2,
      title: 'Team Meeting',
      content: 'Weekly sync with the development team at 2 PM',
      createdDate: 'Oct 17, 2024',
      expiryDate: null,
      priority: MemoPriority.medium,
    ),
    Memo(
      id: 3,
      title: 'Birthday Gift',
      content: 'Buy gift for Sarah\'s birthday next month',
      createdDate: 'Oct 15, 2024',
      expiryDate: 'Nov 15, 2024',
      priority: MemoPriority.low,
    ),
    Memo(
      id: 4,
      title: 'Code Review',
      content: 'Review pull requests from the team',
      createdDate: 'Oct 16, 2024',
      expiryDate: null,
      priority: MemoPriority.high,
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

  Color _getPriorityColor(MemoPriority priority) {
    switch (priority) {
      case MemoPriority.high:
        return Colors.red;
      case MemoPriority.medium:
        return Colors.orange;
      case MemoPriority.low:
        return Colors.green;
    }
  }

  String _getPriorityText(MemoPriority priority) {
    switch (priority) {
      case MemoPriority.high:
        return 'High';
      case MemoPriority.medium:
        return 'Medium';
      case MemoPriority.low:
        return 'Low';
    }
  }

  void _deleteMemo(int id) {
    setState(() {
      _memos.removeWhere((memo) => memo.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Memo deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('MemoKeeper'),
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
                SnackBar(content: Text('Create new memo coming soon!')),
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
                _buildMemoStatsCard(),
                SizedBox(height: 24),
                _buildMemosSection(),
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

  Widget _buildMemoStatsCard() {
    final highPriority = _memos.where((m) => m.priority == MemoPriority.high).length;
    final withExpiry = _memos.where((m) => m.expiryDate != null).length;

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
                      'My Memos',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${_memos.length} total memos',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$highPriority High Priority',
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
                  child: _buildMemoStatItem(
                    'Total',
                    '${_memos.length}',
                    Icons.note,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildMemoStatItem(
                    'With Expiry',
                    '$withExpiry',
                    Icons.schedule,
                    Colors.amber,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildMemoStatItem(
                    'High Priority',
                    '$highPriority',
                    Icons.priority_high,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoStatItem(String label, String value, IconData icon, Color color) {
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

  Widget _buildMemosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Memos',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        if (_memos.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.note_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No memos yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._memos.map((memo) => _buildMemoCard(memo)).toList(),
      ],
    );
  }

  Widget _buildMemoCard(Memo memo) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memo.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        memo.content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(memo.priority).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getPriorityColor(memo.priority).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getPriorityText(memo.priority),
                    style: TextStyle(
                      color: _getPriorityColor(memo.priority),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Created',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        memo.createdDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (memo.expiryDate != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expires',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          memo.expiryDate!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Edit memo coming soon!')),
                      );
                    },
                    child: Text('Edit'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _deleteMemo(memo.id),
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

class Memo {
  final int id;
  final String title;
  final String content;
  final String createdDate;
  final String? expiryDate;
  final MemoPriority priority;

  Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdDate,
    required this.expiryDate,
    required this.priority,
  });
}

enum MemoPriority { high, medium, low }