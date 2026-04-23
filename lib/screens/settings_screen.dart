// lib/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guess_it/repositories/category_repository.dart';
import 'package:guess_it/screens/admin_auth_screen.dart';
import 'package:guess_it/utils/admin_mode_manager.dart';

class SettingsScreen extends StatefulWidget {
  final List<String> usedWords;
  final VoidCallback resetUsedWords;
  final VoidCallback onAdminModeChanged;
  final ValueChanged<bool> onSearchBarSettingChanged;

  const SettingsScreen({
    Key? key,
    required this.usedWords,
    required this.resetUsedWords,
    required this.onAdminModeChanged,
    required this.onSearchBarSettingChanged,
  }) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  int _gameDuration = 60;
  bool _removeWordsEnabled = false;
  bool _showSearchBars = true;
  bool _isAdminMode = false;
  final CategoryRepository _categoryRepository = CategoryRepository();
  final AdminModeManager _adminManager = AdminModeManager();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAdminMode();
  }

  _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _soundEnabled = prefs.getBool('soundEnabled') ?? true;
        _gameDuration = prefs.getInt('gameDuration') ?? 60;
        _removeWordsEnabled = prefs.getBool('removeWordsEnabled') ?? false;
        _showSearchBars = prefs.getBool('showSearchBars') ?? true;
      });
    } catch (e) {
      debugPrint('SettingsScreen._loadSettings error: $e');
    }
  }

  _checkAdminMode() async {
    try {
      final isAdmin = await _adminManager.isAdminModeEnabled();
      if (!mounted) return;
      setState(() {
        _isAdminMode = isAdmin;
      });
    } catch (e) {
      debugPrint('SettingsScreen._checkAdminMode error: $e');
    }
  }

  _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('soundEnabled', _soundEnabled);
      await prefs.setInt('gameDuration', _gameDuration);
      await prefs.setBool('removeWordsEnabled', _removeWordsEnabled);
      await prefs.setBool('showSearchBars', _showSearchBars);
    } catch (e) {
      debugPrint('SettingsScreen._saveSettings error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings. Please try again.')),
      );
    }
  }

  Future<void> _syncWithFirebase() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _categoryRepository.forceSync();
      if (!mounted) return;
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Categories and words updated successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed. Check your internet connection.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing data. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _toggleAdminMode() async {
    if (_isAdminMode) {
      // If already in admin mode, exit it
      await _adminManager.disableAdminMode();
      setState(() {
        _isAdminMode = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Admin mode disabled'),
          backgroundColor: Colors.blue,
        ),
      );
      
      // Notify parent about the change
      widget.onAdminModeChanged();
    } else {
      // If not in admin mode, show auth screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminAuthScreen(
            onAuthSuccess: () {
              Navigator.pop(context);
              setState(() {
                _isAdminMode = true;
              });
              
              // Notify parent about the change
              widget.onAdminModeChanged();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Admin mode enabled. You now have access to deck management.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 5),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
        child: ListView(
          children: [
            Card(
              margin: EdgeInsets.all(16),
              elevation: 4,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Game Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Sound'),
                    subtitle: const Text('Enable game sounds and effects'),
                    value: _soundEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _soundEnabled = value;
                        _saveSettings();
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Search Bars'),
                    subtitle: const Text('Show search bars in deck lists'),
                    value: _showSearchBars,
                    onChanged: (bool value) {
                      setState(() {
                        _showSearchBars = value;
                        _saveSettings();
                      });
                      widget.onSearchBarSettingChanged(value);
                    },
                  ),
                  ListTile(
                    title: const Text('Game Duration'),
                    subtitle: Text('$_gameDuration seconds'),
                    trailing: DropdownButton<int>(
                      value: _gameDuration,
                      items: [30, 45, 60, 75, 90, 105, 120].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value sec'),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _gameDuration = newValue;
                            _saveSettings();
                          });
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Reset Used Words'),
                    subtitle: const Text('Clear the list of words used in previous games'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        widget.resetUsedWords();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Used words list has been reset')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reset'),
                    ),
                  ),
                ],
              ),
            ),
            Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 4,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Admin Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'Admin Mode',
                      style: TextStyle(
                        fontWeight: _isAdminMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      _isAdminMode 
                        ? 'Enabled - You can manage decks and sync with Firebase' 
                        : 'Disabled - Login required'
                    ),
                    leading: Icon(
                      Icons.admin_panel_settings,
                      color: _isAdminMode ? Colors.green : Colors.grey,
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAdminMode ? Colors.orange.shade700 : Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _toggleAdminMode,
                      child: Text(_isAdminMode ? 'Disable' : 'Enable'),
                    ),
                  ),
                  if (_isAdminMode) ...[
                    SwitchListTile(
                      title: const Text('Enable Word Removal'),
                      subtitle: const Text('Allow removing played words after each game'),
                      value: _removeWordsEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _removeWordsEnabled = value;
                          _saveSettings();
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('Synchronize with Firebase'),
                      subtitle: const Text('Force refresh all categories and words from the server'),
                      trailing: ElevatedButton(
                        onPressed: _isSyncing ? null : _syncWithFirebase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSyncing 
                          ? SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : const Text('Sync Now'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Guess It Game v1.0.0',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}