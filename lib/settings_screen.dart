import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  int _gameDuration = 60;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _soundEnabled = prefs.getBool('soundEnabled') ?? true;
        _gameDuration = prefs.getInt('gameDuration') ?? 60;
      });
    } catch (e) {
      print('Error loading settings: $e');
      // Use default values if loading fails
    }
  }

  _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('soundEnabled', _soundEnabled);
      await prefs.setInt('gameDuration', _gameDuration);
    } catch (e) {
      print('Error saving settings: $e');
      // Show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings. Please try again.')),
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
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Sound'),
            value: _soundEnabled,
            onChanged: (bool value) {
              setState(() {
                _soundEnabled = value;
                _saveSettings();
              });
            },
          ),
          ListTile(
            title: const Text('Game Duration'),
            subtitle: Text('$_gameDuration seconds'),
            trailing: DropdownButton<int>(
              value: _gameDuration,
              items: [30, 60, 90, 120].map((int value) {
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
        ],
      ),
    );
  }
}
