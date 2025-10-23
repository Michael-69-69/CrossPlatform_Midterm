import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test script to verify backend integration
/// Run this to test all voice commands and backend functionality
void main() async {
  print('🧪 Testing STARBOY AI Assistant Backend Integration\n');

  const baseUrl = 'http://localhost:5002';

  // Test 1: Create Alarm
  print('1. Testing Alarm Creation...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/alarms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': 'test_user',
        'title': 'Test Alarm',
        'alarm_time': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
        'is_active': true,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Alarm creation successful');
      final data = jsonDecode(response.body);
      print('   Alarm ID: ${data['alarm']['_id']}');
    } else {
      print('❌ Alarm creation failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Alarm creation error: $e');
  }

  // Test 2: Create Travel Plan
  print('\n2. Testing Travel Plan Creation...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/plan_trip'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'trip_id': 'test_trip_${DateTime.now().millisecondsSinceEpoch}',
        'plan': 'Test Trip to Paris',
        'end_date': DateTime.now().add(Duration(days: 7)).toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Travel plan creation successful');
    } else {
      print('❌ Travel plan creation failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Travel plan creation error: $e');
  }

  // Test 3: Save Note
  print('\n3. Testing Note Saving...');
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/note'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': 'Test note from integration test',
        'expiry': null,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Note saving successful');
    } else {
      print('❌ Note saving failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Note saving error: $e');
  }

  // Test 4: Get Alarms
  print('\n4. Testing Alarm Retrieval...');
  try {
    final response = await http.get(Uri.parse('$baseUrl/alarms/test_user'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Alarm retrieval successful');
      print('   Found ${data['alarms'].length} alarms');
    } else {
      print('❌ Alarm retrieval failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Alarm retrieval error: $e');
  }

  // Test 5: Get Notes
  print('\n5. Testing Note Retrieval...');
  try {
    final response = await http.get(Uri.parse('$baseUrl/notes'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Note retrieval successful');
      print('   Found ${data['notes'].length} notes');
    } else {
      print('❌ Note retrieval failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Note retrieval error: $e');
  }

  print('\n🎉 Backend integration test completed!');
  print('\n📝 Voice Commands to Test:');
  print('   - "Tools alarm" - Opens alarm page');
  print('   - "Tools scores" - Opens student tracker page');
  print('   - "Tools travel" - Opens travel guide page');
  print('   - "Tools memo" - Opens memo keeper page');
  print('\n🚀 Make sure the backend is running on http://0.0.0.0:5002');
}
