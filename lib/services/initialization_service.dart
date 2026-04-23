import 'package:flutter/foundation.dart';
import 'package:guess_it/repositories/category_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InitializationService {
  final CategoryRepository _categoryRepository = CategoryRepository();

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isFirstRun = prefs.getBool('isFirstRun') ?? true;

      if (isFirstRun || !(await _categoryRepository.hasInitialData())) {
        final synced = await _categoryRepository.syncData();
        if (!synced) {
          await _categoryRepository.loadInitialData();
        }
        await prefs.setBool('isFirstRun', false);
      } else {
        if (await _categoryRepository.shouldSyncData()) {
          // Fire-and-forget background sync
          _categoryRepository.syncData();
        }
      }
    } catch (e) {
      debugPrint('InitializationService.initialize error: $e');
      if (!(await _categoryRepository.hasInitialData())) {
        await _categoryRepository.loadInitialData();
      }
    }
  }
}
