import 'mcp_client.dart';

class EmailService {
  McpClient? _mcp;

  Future<void> _ensure() async {
    _mcp ??= await McpClient.connect();
  }

  Future<Map<String, dynamic>> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? html,
  }) async {
    await _ensure();
    final result = await _mcp!.call('send_email', {
      'to': to,
      'subject': subject,
      'body': body,
      'html': html,
    });
    return (result as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> sendEmailToOwner({
    required String subject,
    required String body,
    String? html,
  }) async {
    await _ensure();
    final result = await _mcp!.call('send_email_to_owner', {
      'subject': subject,
      'body': body,
      'html': html,
    });
    return (result as Map).cast<String, dynamic>();
  }
}
