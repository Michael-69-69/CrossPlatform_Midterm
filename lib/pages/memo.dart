import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:intl/intl.dart'; // Added for date formatting

class MemoKeeperPage extends StatefulWidget {
  @override
  _MemoKeeperPageState createState() => _MemoKeeperPageState();
}

class _MemoKeeperPageState extends State<MemoKeeperPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;
  
  // NEW: State for search
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // UPDATED: Mock memo data using DateTime
  List<Memo> _memos = [
    Memo(
      id: 1,
      title: 'Project Deadline',
      content: 'Submit the Flutter app by November 30th',
      createdDate: DateTime(2025, 10, 18),
      expiryDate: DateTime(2025, 11, 30),
      priority: MemoPriority.high,
    ),
    Memo(
      id: 2,
      title: 'Team Meeting',
      content: 'Weekly sync with the development team at 2 PM',
      createdDate: DateTime(2025, 10, 17),
      expiryDate: null,
      priority: MemoPriority.medium,
    ),
    Memo(
      id: 3,
      title: 'Birthday Gift',
      content: 'Buy gift for Sarah\'s birthday next month',
      createdDate: DateTime(2025, 10, 15),
      expiryDate: DateTime(2025, 11, 15),
      priority: MemoPriority.low,
    ),
    Memo(
      id: 4,
      title: 'Code Review',
      content: 'Review pull requests from the team',
      createdDate: DateTime(2025, 10, 16),
      expiryDate: DateTime.now().add(Duration(days: 2)), // "Expires in 2 days"
      priority: MemoPriority.high,
    ),
    Memo(
      id: 5,
      title: 'Groceries',
      content: 'Milk, Eggs, Bread',
      createdDate: DateTime(2025, 10, 20),
      expiryDate: DateTime.now().subtract(Duration(days: 1)), // "Expired"
      priority: MemoPriority.low,
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

    // NEW: Listener for search
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose(); // NEW: Dispose controller
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
  
  // NEW: Helper for expiry countdown
  String _getExpiryText(DateTime? expiryDate) {
    if (expiryDate == null) {
      return '';
    }
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative && difference.inDays < -1) {
      return 'Expired';
    } else if (difference.inDays == 0 || (difference.isNegative && difference.inDays == 0)) {
      return 'Expires today';
    } else if (difference.inDays < 0) {
      return 'Expired';
    } else if (difference.inDays < 7) {
      return 'Expires in ${difference.inDays + 1} days';
    } else {
      return 'Expires ${DateFormat.yMMMd().format(expiryDate)}';
    }
  }

  // NEW: Helper for expiry color
  Color _getExpiryColor(DateTime? expiryDate) {
    if (expiryDate == null) {
      return Colors.grey;
    }
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.isNegative || difference.inDays == 0) {
      return Colors.red;
    } else if (difference.inDays < 7) {
      return Colors.orange;
    } else {
      return Colors.grey;
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

  // NEW: Add/Edit Memo Function
  void _showAddOrEditMemoDialog({Memo? existingMemo}) {
    final _titleController = TextEditingController(text: existingMemo?.title);
    final _contentController = TextEditingController(text: existingMemo?.content);
    MemoPriority _selectedPriority = existingMemo?.priority ?? MemoPriority.medium;

    showModalBottomSheet(
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
                      existingMemo == null ? 'New Memo' : 'Edit Memo',
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
                    TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        labelText: 'Content',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: 16),
                    Text('Priority', style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: MemoPriority.values.map((priority) {
                        return ChoiceChip(
                          label: Text(_getPriorityText(priority)),
                          selected: _selectedPriority == priority,
                          selectedColor: _getPriorityColor(priority).withOpacity(0.3),
                          onSelected: (isSelected) {
                            if (isSelected) {
                              setModalState(() {
                                _selectedPriority = priority;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final title = _titleController.text;
                              final content = _contentController.text;
                              if (title.isEmpty || content.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Title and content cannot be empty!')),
                                );
                                return;
                              }

                              if (existingMemo == null) {
                                // Add new memo
                                final newMemo = Memo(
                                  id: DateTime.now().millisecondsSinceEpoch, // Simple unique ID
                                  title: title,
                                  content: content,
                                  createdDate: DateTime.now(),
                                  expiryDate: null, // Can add expiry date picker later
                                  priority: _selectedPriority,
                                );
                                setState(() {
                                  _memos.insert(0, newMemo);
                                });
                              } else {
                                // Update existing memo
                                final updatedMemo = existingMemo.copyWith(
                                  title: title,
                                  content: content,
                                  priority: _selectedPriority,
                                );
                                setState(() {
                                  final index = _memos.indexWhere((m) => m.id == existingMemo.id);
                                  if (index != -1) {
                                    _memos[index] = updatedMemo;
                                  }
                                });
                              }
                              Navigator.pop(context);
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
    // NEW: Filter memos based on search
    final filteredMemos = _memos.where((memo) {
      final titleLower = memo.title.toLowerCase();
      final contentLower = memo.content.toLowerCase();
      final searchLower = _searchText.toLowerCase();
      return titleLower.contains(searchLower) || contentLower.contains(searchLower);
    }).toList();

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
              // UPDATED: Hook up add function
              _showAddOrEditMemoDialog();
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
                // NEW: Search Bar
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search memos...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: _searchText.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                _buildMemosSection(filteredMemos), // UPDATED: Pass filtered list
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

  // UPDATED: Accept filtered list
  Widget _buildMemosSection(List<Memo> memos) {
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
        if (memos.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    _searchText.isEmpty ? 'No memos yet' : 'No memos found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...memos.map((memo) => _buildMemoCard(memo)).toList(),
      ],
    );
  }

  Widget _buildMemoCard(Memo memo) {
    // NEW: Get expiry text and color
    final expiryText = _getExpiryText(memo.expiryDate);
    final expiryColor = _getExpiryColor(memo.expiryDate);

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
                        // UPDATED: Format DateTime
                        DateFormat.yMMMd().format(memo.createdDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // UPDATED: Use expiryText
                if (expiryText.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          expiryText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: expiryColor,
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
                      // UPDATED: Hook up edit function
                      _showAddOrEditMemoDialog(existingMemo: memo);
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
  final DateTime createdDate; // UPDATED: Use DateTime
  final DateTime? expiryDate; // UPDATED: Use DateTime
  final MemoPriority priority;

  Memo({
    required this.id,
    required this.title,
    required this.content,
    required this.createdDate,
    required this.expiryDate,
    required this.priority,
  });

  // NEW: copyWith method for easier updates
  Memo copyWith({
    String? title,
    String? content,
    DateTime? expiryDate,
    MemoPriority? priority,
  }) {
    return Memo(
      id: this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdDate: this.createdDate,
      expiryDate: expiryDate ?? this.expiryDate,
      priority: priority ?? this.priority,
    );
  }
}

enum MemoPriority { high, medium, low }