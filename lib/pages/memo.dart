import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/config_service.dart';

class MemoKeeperPage extends StatefulWidget {
  @override
  _MemoKeeperPageState createState() => _MemoKeeperPageState();
}

class _MemoKeeperPageState extends State<MemoKeeperPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isLoading = false;
  String _errorMessage = '';

  // Real data from backend
  List<Memo> _memos = [];
  String _newNoteContent = '';

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

    // Load existing notes when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotes();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _saveNote(String content) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${ConfigService.backendUrl}/note'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': content, 'expiry': null}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('status') && data['status'] == 'success') {
          setState(() {
            _memos.insert(
              0,
              Memo(
                id: DateTime.now().millisecondsSinceEpoch,
                title: content.length > 30
                    ? content.substring(0, 30) + '...'
                    : content,
                content: content,
                createdDate: DateTime.now().toString().split(' ')[0],
                expiryDate: null,
                priority: MemoPriority.medium,
              ),
            );
            _isLoading = false;
          });
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Note saved successfully!')));
        } else {
          setState(() {
            _errorMessage = 'Failed to save note';
            _isLoading = false;
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ?? 'Failed to save note';
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

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('${ConfigService.backendUrl}/notes'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('notes')) {
          List<dynamic> notesData = data['notes'];
          setState(() {
            _memos = notesData.asMap().entries.map((entry) {
              int index = entry.key;
              String content = entry.value;
              return Memo(
                id: DateTime.now().millisecondsSinceEpoch + index,
                title: content.length > 30
                    ? content.substring(0, 30) + '...'
                    : content,
                content: content,
                createdDate:
                    DateTime.now().subtract(Duration(days: index)).toString().split(' ')[0],
                expiryDate: null,
                priority: MemoPriority.medium,
              );
            }).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'No notes found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load notes';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading notes: $e';
        _isLoading = false;
      });
    }
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Memo deleted')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('MemoKeeper', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF4A90E2),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading
                ? null
                : () {
                    _loadNotes();
                  },
          ),
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: _isLoading
                ? null
                : () {
                    _showAddMemoDialog();
                  },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF50E3C2), Color(0xFF4A90E2)],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMemoStatsCard(),
                  SizedBox(height: 24),
                  if (_isLoading)
                    _buildLoadingCard()
                  else if (_errorMessage.isNotEmpty)
                    _buildErrorCard()
                  else if (_memos.isNotEmpty)
                    _buildMemosSection()
                  else
                    _buildEmptyStateCard(),
                  SizedBox(height: 100),
                ],
              ),
            ),
            Positioned(bottom: 20, right: 20, child: _buildFloatingAvatar()),
          ],
        ),
      ),
    );
  }

  void _showAddMemoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Note', style: TextStyle(color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Note Content',
                hintText: 'Enter your note here...',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.black),
              ),
              maxLines: 3,
              onChanged: (value) => _newNoteContent = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              Navigator.pop(context);
              if (_newNoteContent.isNotEmpty) {
                _saveNote(_newNoteContent);
                _newNoteContent = '';
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter note content')),
                );
              }
            },
            child: Text('Save Note', style: TextStyle(color: Colors.white)),
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
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text(
              'Loading notes...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                });
              },
              child: Text('Try Again', style: TextStyle(color: Colors.white)),
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
            Icon(Icons.note_outlined, color: Colors.blue, size: 64),
            SizedBox(height: 16),
            Text(
              'No Notes Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to create your first note',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoStatsCard() {
    final highPriority =
        _memos.where((m) => m.priority == MemoPriority.high).length;
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
            colors: [Colors.teal.withOpacity(0.1), Colors.blue.withOpacity(0.1)],
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black),
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
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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

  Widget _buildMemoStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), Colors.teal.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600, color: Colors.black),
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
                    gradient: LinearGradient(
                      colors: [
                        _getPriorityColor(memo.priority).withOpacity(0.15),
                        Colors.teal.withOpacity(0.1)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.teal),
                      foregroundColor: Colors.teal,
                    ),
                    onPressed: () {},
                    child: Text('Edit'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () => _deleteMemo(memo.id),
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
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/Starboy/Neutral_bot.png',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Center(
                    child: Text('Image not found: $error',
                        style: TextStyle(color: Colors.white)),
                  );
                },
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