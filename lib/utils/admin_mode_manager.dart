// lib/utils/admin_mode_manager.dart
import 'package:shared_preferences/shared_preferences.dart';

class AdminModeManager {
  static const String _adminPasswordKey = 'admin_password';
  static const String _adminModeKey = 'admin_mode_enabled';
  static const String _correctPassword = 'ethanb';
  
  // Singleton instance
  static final AdminModeManager _instance = AdminModeManager._internal();
  
  factory AdminModeManager() {
    return _instance;
  }
  
  AdminModeManager._internal();
  
  // Check if admin mode is enabled
  Future<bool> isAdminModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adminModeKey) ?? false;
  }
  
  // Try to enable admin mode with password
  Future<bool> enableAdminMode(String password) async {
    if (password == _correctPassword) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adminModeKey, true);
      return true;
    }
    return false;
  }
  
  // Disable admin mode
  Future<void> disableAdminMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adminModeKey, false);
  }
  
  // Check if a given password is correct
  bool isPasswordCorrect(String password) {
    return password == _correctPassword;
  }
}