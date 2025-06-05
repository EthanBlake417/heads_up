// lib/admin_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:guess_it/utils/admin_mode_manager.dart';

class AdminAuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  
  const AdminAuthScreen({
    Key? key,
    required this.onAuthSuccess,
  }) : super(key: key);

  @override
  _AdminAuthScreenState createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final _passwordController = TextEditingController();
  final _adminManager = AdminModeManager();
  bool _isAuthenticating = false;
  String _errorMessage = '';
  
  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
  
  void _attemptAuth() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });
    
    try {
      final success = await _adminManager.enableAdminMode(_passwordController.text);
      
      if (success) {
        widget.onAuthSuccess();
      } else {
        setState(() {
          _errorMessage = 'Invalid password. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication error: $e';
      });
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Authentication'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade200, Colors.blue.shade100],
          ),
        ),
        child: Center(
          child: Card(
            margin: EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 64,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Admin Authentication',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enter the admin password to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Admin Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    onSubmitted: (_) => _attemptAuth(),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      minimumSize: Size(double.infinity, 54),
                    ),
                    onPressed: _isAuthenticating ? null : _attemptAuth,
                    child: _isAuthenticating
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Authenticate',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}