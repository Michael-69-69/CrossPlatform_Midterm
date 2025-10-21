import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StoragePage extends StatelessWidget {
  final List<Map<String, dynamic>> inventory;
  final String? equippedSkin;
  final Function(String) onUseWater;
  final Function(String) onEquipSkin;

  StoragePage({
    required this.inventory,
    required this.equippedSkin,
    required this.onUseWater,
    required this.onEquipSkin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade400,
        title: Text('Storage', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade200, Colors.blue.shade800],
          ),
        ),
        child:
            inventory.isEmpty
                ? Center(
                  child: Text(
                    'Your storage is empty!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: inventory.length,
                  itemBuilder: (context, index) {
                    final item = inventory[index];
                    return Card(
                      color: Colors.white.withOpacity(0.9),
                      margin: EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: Icon(
                          item['type'] == 'water'
                              ? Icons.battery_charging_full
                              : Icons.color_lens,
                          color: Colors.blue.shade600,
                          size: 30,
                        ),
                        title: Text(
                          item['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          item['type'] == 'water'
                              ? 'Restores ${item['energy']}% energy'
                              : 'Decorative skin',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (item['type'] == 'water') {
                              onUseWater(item['name']);
                            } else {
                              onEquipSkin(item['name']);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  item['type'] == 'water'
                                      ? 'Used ${item['name']}!'
                                      : 'Equipped ${item['name']}!',
                                ),
                                duration: Duration(seconds: 2),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            item['type'] == 'water' ? 'Use' : 'Equip',
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}