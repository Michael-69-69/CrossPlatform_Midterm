import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:intl/intl.dart'; // Added for date/number formatting

class TravelGuidePage extends StatefulWidget {
  @override
  _TravelGuidePageState createState() => _TravelGuidePageState();
}

class _TravelGuidePageState extends State<TravelGuidePage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentGlb = 'assets/glb/c_neutral.glb';
  bool _reloadModel = false;

  // UPDATED: Mock trip data with new fields
  List<TripItinerary> _itineraries = [
    TripItinerary(
      id: 1,
      destination: 'Paris, France',
      startDate: DateTime.now().add(Duration(days: 29)),
      endDate: DateTime.now().add(Duration(days: 36)),
      activities: ['Eiffel Tower', 'Louvre Museum', 'Arc de Triomphe', 'Seine River Cruise'],
      imageUrl: 'https://images.unsplash.com/photo-1502602898657-3e91760c0341?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80',
      budget: 2500,
      weather: 'Mild, 18°C',
      packingList: ['Passport', 'Comfortable Shoes', 'Rain Jacket', 'Camera'],
      travelDocuments: ['Flight Tickets', 'Hotel Reservation', 'Visa'],
    ),
    TripItinerary(
      id: 2,
      destination: 'Tokyo, Japan',
      startDate: DateTime.now().add(Duration(days: 49)),
      endDate: DateTime.now().add(Duration(days: 59)),
      activities: ['Senso-ji Temple', 'Shibuya Crossing', 'Mount Fuji', 'Tsukiji Market'],
      imageUrl: 'https://images.unsplash.com/photo-1542051841857-5f90071e7989?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80',
      budget: 4500,
      weather: 'Cool, 12°C',
      packingList: ['JR Pass', 'Pocket Wi-Fi', 'Good walking shoes', 'Power Adapter'],
      travelDocuments: ['Passport', 'Flight Tickets', 'Ryokan Bookings', 'Insurance'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)
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

  // NEW: Add/Edit Trip Function
  void _showAddOrEditTripDialog({TripItinerary? existingTrip}) async {
    final _destinationController = TextEditingController(text: existingTrip?.destination);
    final _budgetController = TextEditingController(text: existingTrip?.budget.toString());
    DateTimeRange? _selectedDateRange = existingTrip != null
        ? DateTimeRange(start: existingTrip.startDate, end: existingTrip.endDate)
        : null;
    
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
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
                      existingTrip == null ? 'New Trip' : 'Edit Trip',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _budgetController,
                      decoration: InputDecoration(
                        labelText: 'Budget (\$)',
                        prefixText: '\$',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Trip Dates', style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                        _selectedDateRange == null
                            ? 'Select dates'
                            // --- FIX 1: Added ! here ---
                            : '${DateFormat.yMMMd().format(_selectedDateRange!.start)} - ${DateFormat.yMMMd().format(_selectedDateRange!.end)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final newRange = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 1095)),
                          initialDateRange: _selectedDateRange,
                        );
                        if (newRange != null) {
                          setModalState(() {
                            _selectedDateRange = newRange;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final destination = _destinationController.text;
                              final budget = double.tryParse(_budgetController.text) ?? 0.0;
                              if (destination.isEmpty || _selectedDateRange == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Destination and dates are required!')),
                                );
                                return;
                              }

                              if (existingTrip == null) {
                                // Add new trip
                                final newTrip = TripItinerary(
                                  id: DateTime.now().millisecondsSinceEpoch,
                                  destination: destination,
                                  // --- FIX 2: Added ! here ---
                                  startDate: _selectedDateRange!.start,
                                  endDate: _selectedDateRange!.end,
                                  budget: budget,
                                  activities: ['New Activity'], // Default
                                  imageUrl: 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1470&q=80', // Default
                                  weather: 'TBD',
                                  packingList: ['Passport'],
                                  travelDocuments: ['Tickets'],
                                );
                                setState(() {
                                  _itineraries.insert(0, newTrip);
                                });
                              } else {
                                // Update existing trip
                                final updatedTrip = existingTrip.copyWith(
                                  destination: destination,
                                  // --- FIX 3: Added ! here ---
                                  startDate: _selectedDateRange!.start,
                                  endDate: _selectedDateRange!.end,
                                  budget: budget,
                                );
                                setState(() {
                                  final index = _itineraries.indexWhere((t) => t.id == existingTrip.id);
                                  if (index != -1) {
                                    _itineraries[index] = updatedTrip;
                                  }
                                });
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // NEW: Show Details Modal (scrollable, constrained and with persistent checkboxes)
  void _showDetailsModal(TripItinerary itinerary) {
    // ensure map entries exist
    _checkedPacking.putIfAbsent(itinerary.id, () => <String>{});
    _checkedDocs.putIfAbsent(itinerary.id, () => <String>{});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Use StatefulBuilder for modal-local updates
        return StatefulBuilder(builder: (context, setModalState) {
          final checkedPacking = _checkedPacking[itinerary.id]!;
          final checkedDocs = _checkedDocs[itinerary.id]!;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // keep modal from overflowing the screen
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details for ${itinerary.destination}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Packing list with checkboxes
                      Text(
                        'Packing List',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...itinerary.packingList.map((item) {
                        final checked = checkedPacking.contains(item);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            setModalState(() {
                              if (v == true) {
                                checkedPacking.add(item);
                              } else {
                                checkedPacking.remove(item);
                              }
                              // persist to parent state so it remains across modal opens
                              setState(() => _checkedPacking[itinerary.id] = checkedPacking);
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item),
                        );
                      }).toList(),

                      const Divider(height: 24),

                      // Travel documents with checkboxes
                      Text(
                        'Travel Documents',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...itinerary.travelDocuments.map((item) {
                        final checked = checkedDocs.contains(item);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            setModalState(() {
                              if (v == true) {
                                checkedDocs.add(item);
                              } else {
                                checkedDocs.remove(item);
                              }
                              // persist to parent state so it remains across modal opens
                              setState(() => _checkedDocs[itinerary.id] = checkedDocs);
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item),
                        );
                      }).toList(),

                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // NEW: Helper for countdown
  String _getDaysUntilText(DateTime startDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDay = DateTime(startDate.year, startDate.month, startDate.day);
    final difference = tripDay.difference(today).inDays;

    if (difference < 0) {
      return 'Trip ended';
    } else if (difference == 0) {
      return 'Starts today!';
    } else if (difference == 1) {
      return 'Starts tomorrow!';
    } else {
      return 'In $difference days';
    }
  }

  // NEW: Helper for weather icon
  IconData _getWeatherIcon(String weather) {
    if (weather.contains('Mild') || weather.contains('Sunny')) return Icons.wb_sunny;
    if (weather.contains('Cool')) return Icons.ac_unit;
    if (weather.contains('Rain')) return Icons.grain;
    return Icons.cloud;
  }

  // Persist checkbox state per itinerary so ticks remain across modal opens
  final Map<int, Set<String>> _checkedPacking = {};
  final Map<int, Set<String>> _checkedDocs = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Travel Guide'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // UPDATED: Hook up add function
              _showAddOrEditTripDialog();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTripSummary(),
                const SizedBox(height: 24),
                _buildItinerariesSection(),
                const SizedBox(height: 100),
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

  Widget _buildTripSummary() {
    // UPDATED: Use DateTime and budget
    final totalDays = _itineraries.fold(0, (sum, trip) => (trip.endDate.difference(trip.startDate).inDays + 1).clamp(1, 999));
    final totalBudget = _itineraries.fold(0.0, (sum, trip) => sum + trip.budget);
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
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
                      'My Trips',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_itineraries.length} upcoming trips',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flight, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$totalDays days',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildQuickStat('Destinations', '${_itineraries.length}', Icons.location_on),
                ),
                const SizedBox(width: 12),
                // NEW: Total Budget Stat
                Expanded(
                  child: _buildQuickStat(
                    'Total Budget',
                    NumberFormat.compactCurrency(symbol: '\$').format(totalBudget),
                    Icons.attach_money,
                  ),
                ),
              ],
            ),
          ],
        ),
      ));
  }

  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _buildItinerariesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Itineraries',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._itineraries.map((itinerary) => _buildItineraryCard(itinerary)).toList(),
      ],
    );
  }

  Widget _buildItineraryCard(TripItinerary itinerary) {
    final int days = (itinerary.endDate.difference(itinerary.startDate).inDays + 1).clamp(1, 999);
    final countdownText = _getDaysUntilText(itinerary.startDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // To clip the image
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Header
          SizedBox(
            height: 150,
            width: double.infinity,
            child: Image.network(
              itinerary.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (context, error, stack) =>
                  const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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
                            itinerary.destination,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            countdownText,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: countdownText.toLowerCase().contains('today') || countdownText.toLowerCase().contains('tomorrow')
                                  ? Colors.green
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${days}d',
                        style: TextStyle(
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(_getWeatherIcon(itinerary.weather), size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      itinerary.weather,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Activities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: itinerary.activities.take(3).map((activity) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            activity,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                if (itinerary.activities.length > 3)
                  Text(
                    '+${itinerary.activities.length - 3} more...',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showAddOrEditTripDialog(existingTrip: itinerary);
                        },
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _showDetailsModal(itinerary);
                        },
                        child: const Text('Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                  child: const Center(child: CircularProgressIndicator()),
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

class TripItinerary {
  final int id; // NEW
  final String destination;
  final DateTime startDate; // UPDATED
  final DateTime endDate; // UPDATED
  final List<String> activities;
  final String imageUrl; // NEW
  final double budget; // NEW
  final String weather; // NEW
  final List<String> packingList; // NEW
  final List<String> travelDocuments; // NEW

  TripItinerary({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.activities,
    required this.imageUrl,
    required this.budget,
    required this.weather,
    required this.packingList,
    required this.travelDocuments,
  });

  // NEW: copyWith for editing
  TripItinerary copyWith({
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
  }) {
    return TripItinerary(
      id: this.id,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      activities: this.activities,
      imageUrl: this.imageUrl,
      budget: budget ?? this.budget,
      weather: this.weather,
      packingList: this.packingList,
      travelDocuments: this.travelDocuments,
    );
  }
}