import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailPage extends StatefulWidget {
  @override
  _EmailPageState createState() => _EmailPageState();
}

class _EmailPageState extends State<EmailPage> {
  final _formKey = GlobalKey<FormState>();
  String _recipient = '';
  String _senderEmail = '';
  String _senderPassword = '';
  String _subject = '';
  String _message = '';
  bool _useTesterAccount = false;
  bool _isLoading = false;
  String _errorMessage = '';

  final String _testerEmail = 'juuzo3326@gmail.com';
  final String _testerAppPassword = 'iqodnnmribawoclx'; 


  Future<void> _sendEmail() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        String username = _useTesterAccount ? _testerEmail : _senderEmail;
        String password = _useTesterAccount ? _testerAppPassword : _senderPassword;

        final smtpServer = SmtpServer('smtp.gmail.com',
            port: 587,
            ssl: false,
            ignoreBadCertificate: false,
            username: username,
            password: password);
        final message = Message()
          ..from = Address(username, 'Your App')
          ..recipients.add(_recipient)
          ..subject = _subject
          ..text = _message;

        await send(message, smtpServer);
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email sent successfully!')),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to send email: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Email'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SwitchListTile(
                title: const Text('Use Tester Account'),
                value: _useTesterAccount,
                onChanged: (value) {
                  setState(() {
                    _useTesterAccount = value;
                    if (value) {
                      _senderEmail = _testerEmail; // Set sender to tester email
                      _senderPassword = ''; // Clear password field
                    } else {
                      _senderEmail = ''; // Clear sender email
                      _senderPassword = ''; // Clear password
                    }
                  });
                },
                secondary: const Icon(Icons.email),
              ),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Sender Email',
                  border: OutlineInputBorder(),
                ),
                initialValue: _useTesterAccount ? _testerEmail : '',
                enabled: !_useTesterAccount,
                validator: (value) {
                  if (!_useTesterAccount && (value == null || value.isEmpty))
                    return 'Please enter your email';
                  if (value != null && !value.contains('@'))
                    return 'Please enter a valid email';
                  return null;
                },
                onSaved: (value) => _senderEmail = value!,
              ),
              if (!_useTesterAccount)
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Sender Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (!_useTesterAccount && (value == null || value.isEmpty))
                      return 'Please enter your password';
                    return null;
                  },
                  onSaved: (value) => _senderPassword = value!,
                ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Recipient Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter an email';
                  if (!value.contains('@')) return 'Please enter a valid email';
                  return null;
                },
                onSaved: (value) => _recipient = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a subject';
                  return null;
                },
                onSaved: (value) => _subject = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a message';
                  return null;
                },
                onSaved: (value) => _message = value!,
              ),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendEmail,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('Send Email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}