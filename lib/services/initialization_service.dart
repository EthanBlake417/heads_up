import 'package:heads_up/repositories/category_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InitializationService {
  final CategoryRepository _categoryRepository = CategoryRepository();
  
  Future<void> initialize() async {
    try {
      // Check if this is the first run
      final prefs = await SharedPreferences.getInstance();
      final bool isFirstRun = prefs.getBool('isFirstRun') ?? true;
      
      // If it's the first run or if we don't have any data
      if (isFirstRun || !(await _categoryRepository.hasInitialData())) {
        // Try to sync from Firebase first
        bool synced = await _categoryRepository.syncData();
        
        // If sync failed (likely offline on first run), load embedded data
        if (!synced) {
          await _categoryRepository.loadInitialData();
        }
        
        // Mark that we've completed the first run
        await prefs.setBool('isFirstRun', false);
      } else {
        // For subsequent runs, check if we should sync in the background
        if (await _categoryRepository.shouldSyncData()) {
          _categoryRepository.syncData(); // Don't await - let it happen in background
        }
      }
    } catch (e) {
      print('Error during initialization: $e');
      // Ensure we at least have default data
      if (!(await _categoryRepository.hasInitialData())) {
        await _categoryRepository.loadInitialData();
      }
    }
  }
}