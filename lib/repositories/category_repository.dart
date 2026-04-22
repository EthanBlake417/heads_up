import 'dart:async';
import 'package:flutter/material.dart';
import 'package:guess_it/models/category_model.dart';
import 'package:guess_it/models/word_model.dart';
import 'package:guess_it/services/firebase_service.dart';
import 'package:guess_it/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:guess_it/utils/icon_mapping.dart';
import 'package:guess_it/utils/admin_mode_manager.dart';

class CategoryRepository {
  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AdminModeManager _adminManager = AdminModeManager();
  final _uuid = Uuid();

  // Get icon for a category
  IconData getIconForCategory(String iconName) {
    return IconMapping.getIconFromKey(iconName);
  }

  // Get all categories with proper icon mapping
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final categories = await _databaseHelper.getCategories();
    
    // Convert to a format similar to your original decks list
    return categories.map((category) {
      // Check if this is a custom category (you can implement your own logic here)
      bool isCustom = false;
      
      // Get the icon from the icon string using the utility class
      IconData iconData = IconMapping.getIconFromKey(category.icon);
      
      return {
        'id': category.id,
        'name': category.name,
        'icon': iconData,
        'iconKey': category.icon, // Save the original icon key
        'isCustom': isCustom,
      };
    }).toList();
  }

  // Check if we should sync data
  Future<bool> shouldSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt('lastSyncTimestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // If it's been more than a day since the last sync
      if (now - lastSync > 86400000) {
        return true;
      }
      
      // Or if there's a newer version available
      final localVersion = await _databaseHelper.getLastUpdatedTimestamp();
      final remoteVersion = await _firebaseService.getLatestVersion();
      
      return remoteVersion > localVersion;
    } catch (e) {
      return false;
    }
  }

  // Sync data from Firebase to local storage
  Future<bool> syncData() async {
    try {
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (!hasInternet) {
        return false;
      }

      final localVersion = await _databaseHelper.getLastUpdatedTimestamp();
      final categories = await _firebaseService.getCategoriesSince(localVersion);

      if (categories.isEmpty) {
        // No new categories to sync
        await _updateLastSyncTimestamp();
        return true;
      }

      // For each updated category, fetch and update the words
      for (var category in categories) {
        final words = await _firebaseService.getWordsForCategory(category.id);
        
        // Update category in local database
        await _databaseHelper.insertCategory(category);
        
        // Clear old words and insert new ones
        await _databaseHelper.clearWordsForCategory(category.id);
        await _databaseHelper.insertWords(words);
      }

      await _updateLastSyncTimestamp();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Check if database has initial data
  Future<bool> hasInitialData() async {
    final categories = await _databaseHelper.getCategories();
    return categories.isNotEmpty;
  }

  // Load initial data if it's the first run and we can't connect to Firebase
  Future<void> loadInitialData() async {
    // Load default categories and words from embedded data
    await _loadDefaultCategories();
  }

  Future<void> _loadDefaultCategories() async {
    // Create a list of default categories
    final List<CategoryModel> defaultCategories = [
      CategoryModel(
        id: _uuid.v4(),
        name: 'Animals',
        icon: 'pets',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      ),
      CategoryModel(
        id: _uuid.v4(),
        name: 'Movies',
        icon: 'movie',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      ),
      // Add more default categories...
    ];

    // Insert the default categories into the database
    await _databaseHelper.insertCategories(defaultCategories);

    // For each category, insert a subset of words
    for (var category in defaultCategories) {
      List<WordModel> defaultWords = [];
      
      // Example for Animals category
      if (category.name == 'Animals') {
        final List<String> animalWords = [
          'Elephant', 'Lion', 'Giraffe', 'Penguin', 'Kangaroo',
          'Dolphin', 'Koala', 'Tiger', 'Panda', 'Cheetah',
          // Add more default animal words...
        ];
        
        defaultWords = animalWords.map((word) => WordModel(
          id: _uuid.v4(),
          categoryId: category.id,
          word: word,
        )).toList();
      }
      
      // Add similar blocks for other categories
      
      // Insert the default words for this category
      if (defaultWords.isNotEmpty) {
        await _databaseHelper.insertWords(defaultWords);
      }
    }
  }

  Future<void> _updateLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSyncTimestamp', DateTime.now().millisecondsSinceEpoch);
  }

  // Get words for a specific category
  Future<List<String>> getWordsForCategory(String categoryName) async {
    try {
      if (categoryName == 'All Categories') {
        return await _databaseHelper.getAllWords();
      }
      
      
      // First try to get the category
      final category = await _databaseHelper.getCategoryByName(categoryName);
      
      if (category == null) {
        return [];
      }
      
      
      // Try getting words by name first
      final wordsByName = await _databaseHelper.getWordStringsByCategory(categoryName);
      
      if (wordsByName.isNotEmpty) {
        return wordsByName;
      }
      
      // If that fails, try getting words by ID
      final wordsById = await _databaseHelper.getWordsByCategory(category.id);
      
      return wordsById.map((word) => word.word).toList();
    } catch (e) {
      return [];
    }
  }

  // Force sync with Firebase (simplified for admin mode)
  Future<bool> forceSync() async {
    try {
      // Show console logging for debugging
      
      // Check for internet connection
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (!hasInternet) {
        return false;
      }

      // Get all categories from Firestore
      final categories = await _firebaseService.getCategories();
      
      if (categories.isEmpty) {
        return false; // No categories to sync
      }


      // Clear existing data
      await _databaseHelper.clearAllData();
      
      // Insert all categories
      await _databaseHelper.insertCategories(categories);
      
      // For each category, fetch and save words
      int totalWords = 0;
      for (var category in categories) {
        final words = await _firebaseService.getWordsForCategory(category.id);
        totalWords += words.length;
        
        await _databaseHelper.insertWords(words);
      }

      // Update last sync timestamp
      await _updateLastSyncTimestamp();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<CategoryModel?> getCategoryByName(String name) async {
    try {
      // First check the local database
      final category = await _databaseHelper.getCategoryByName(name);
      if (category != null) {
        return category;
      }
      
      // If not found locally and we have internet, try to find it in Firebase
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (hasInternet) {
        final categories = await _firebaseService.getCategories();
        for (var c in categories) {
          if (c.name == name) {
            return c;
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // UPDATED: Remove words from category - now checks for admin mode to update Firebase directly
  Future<void> removeWordsFromCategory(String categoryName, List<String> wordsToRemove) async {
    try {
      // First get the category ID
      final category = await _databaseHelper.getCategoryByName(categoryName);
      if (category == null) {
        throw Exception('Category not found: $categoryName');
      }
      
      // Get current words for this category
      final currentWords = await _databaseHelper.getWordsByCategory(category.id);
      
      // Identify which words to keep
      final wordsToKeep = currentWords
          .where((word) => !wordsToRemove.contains(word.word))
          .toList();
      
      // Clear all words and re-insert the ones to keep (this removes them locally)
      await _databaseHelper.clearWordsForCategory(category.id);
      if (wordsToKeep.isNotEmpty) {
        await _databaseHelper.insertWords(wordsToKeep);
      }
      
      // Check if in admin mode and connected to internet
      bool isAdmin = await _adminManager.isAdminModeEnabled();
      
      if (isAdmin) {
        // In admin mode, update Firebase directly
        await _firebaseService.removeWordsFromFirebase(category.id, wordsToRemove);
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> saveCustomDeck(CategoryModel category, List<WordModel> words) async {
    try {
      // Insert or update the category locally
      await _databaseHelper.insertCategory(category);
      
      // Clear existing words and insert new ones locally
      await _databaseHelper.clearWordsForCategory(category.id);
      await _databaseHelper.insertWords(words);
      
      // Check if in admin mode
      bool isAdmin = await _adminManager.isAdminModeEnabled();
      
      if (isAdmin) {
        // In admin mode, update Firebase directly
        await _firebaseService.saveCategoryToFirebase(category, words);
      }
    } catch (e) {
      throw e;
    }
  }

  // Get all categories with their words for backup
  Future<List<Map<String, dynamic>>> getAllCategoriesWithWords() async {
    final categories = await _databaseHelper.getCategories();
    final List<Map<String, dynamic>> result = [];
    
    for (final category in categories) {
      final words = await _databaseHelper.getWordsByCategory(category.id);
      result.add({
        'category': category.toMap(),
        'words': words.map((w) => w.toMap()).toList(),
      });
    }
    
    return result;
  }

  // Restore from backup
  Future<void> restoreFromBackup(List<dynamic> backupData) async {
    // First clear all existing data
    await _databaseHelper.clearAllData();
    
    // Then restore from backup
    for (final item in backupData) {
      final categoryData = item['category'] as Map<String, dynamic>;
      final wordsData = item['words'] as List<dynamic>;
      
      final category = CategoryModel.fromMap(categoryData);
      await _databaseHelper.insertCategory(category);
      
      final words = wordsData.map((w) => WordModel.fromMap(w as Map<String, dynamic>)).toList();
      await _databaseHelper.insertWords(words);
    }

    // If in admin mode, also sync changes to Firebase
    bool isAdmin = await _adminManager.isAdminModeEnabled();
    if (isAdmin) {
      await syncDataToFirebase();
    }
  }

  // New method: Sync all local data to Firebase for admin mode
  Future<bool> syncDataToFirebase() async {
    try {
      if (!await _firebaseService.hasInternetConnection()) {
        return false;
      }
      
      // Only allow in admin mode
      if (!await _adminManager.isAdminModeEnabled()) {
        return false;
      }
      
      
      // Get all categories with words
      final localData = await getAllCategoriesWithWords();
      
      // For each category, update Firebase
      for (final item in localData) {
        final category = CategoryModel.fromMap(item['category'] as Map<String, dynamic>);
        final wordsList = (item['words'] as List<dynamic>)
            .map((w) => WordModel.fromMap(w as Map<String, dynamic>))
            .toList();
        
        // Upload to Firebase
        await _firebaseService.saveCategoryToFirebase(category, wordsList);
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteDeck(dynamic deckId) async {
    // Extract the string ID if we received a map
    final String categoryId = deckId is Map ? deckId['id'] : deckId;
    
    try {
      
      // Get words for this category first to verify it exists
      final words = await _databaseHelper.getWordsByCategory(categoryId);
      
      // Delete the words first
      await _databaseHelper.clearWordsForCategory(categoryId);
      
      // Then delete the category
      int result = await _databaseHelper.deleteCategory(categoryId);
      
      // Check if in admin mode
      bool isAdmin = await _adminManager.isAdminModeEnabled();
      
      if (isAdmin) {
        // In admin mode, delete from Firebase directly
        await _firebaseService.deleteCategoryFromFirebase(categoryId);
      }
      
      return result > 0; // Return true if at least one row was affected
    } catch (e) {
      return false;
    }
  }

  // Get a category by ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
      );
      
      if (maps.isNotEmpty) {
        return CategoryModel.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Download a deck from Firebase
  Future<bool> downloadDeck(String categoryId) async {
    try {
      // Check if we're online
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (!hasInternet) {
        return false;
      }
      
      
      // Fetch the category data from Firebase
      final category = await _firebaseService.getCategoryById(categoryId);
      if (category == null) {
        return false;
      }
      
      
      // Fetch the words for this category
      final words = await _firebaseService.getWordsForCategory(categoryId);
      
      if (words.isEmpty) {
      }
      
      // Save to local database with proper transaction management
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      
      try {
        // Use a transaction to ensure all-or-nothing saving
        await db.transaction((txn) async {
          
          // First check if category already exists locally
          final existingCat = await txn.query(
            'categories',
            where: 'id = ?',
            whereArgs: [categoryId],
          );
          
          if (existingCat.isNotEmpty) {
            // Update existing category
            await txn.update(
              'categories',
              {
                'name': category.name,
                'icon': category.icon,
                'lastUpdated': category.lastUpdated,
              },
              where: 'id = ?',
              whereArgs: [categoryId],
            );
            
            // Clear existing words
            await txn.delete(
              'words',
              where: 'categoryId = ?',
              whereArgs: [categoryId],
            );
          } else {
            // Insert new category
            await txn.insert(
              'categories',
              {
                'id': category.id,
                'name': category.name,
                'icon': category.icon,
                'lastUpdated': category.lastUpdated,
              },
            );
          }
          
          // Insert all words
          for (final word in words) {
            await txn.insert(
              'words',
              {
                'id': word.id,
                'categoryId': word.categoryId,
                'word': word.word,
              },
            );
          }
          
        });
        
        // Verify the download worked
        final savedCategory = await dbHelper.getCategoryByName(category.name);
        if (savedCategory == null) {
          return false;
        }
        
        final savedWords = await dbHelper.getWordsByCategory(category.id);
        
        if (savedWords.length != words.length) {
        }
        
        return savedWords.isNotEmpty; // Success if we have at least some words
        
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Sync selected decks with Firebase (optional admin mode check)
  Future<bool> syncSelectedDecks(List<String> deckNames, bool isHardSync) async {
    try {
      // First check internet connection
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (!hasInternet) {
        return false;
      }

      for (final deckName in deckNames) {
        
        // Get category by name to get its ID
        final category = await _databaseHelper.getCategoryByName(deckName);
        
        if (category == null) {
          // This is a new deck from Firebase, just fetch and add it
          final categories = await _firebaseService.getCategories();
          
          // Find the matching category
          CategoryModel? remoteCategory;
          for (var c in categories) {
            if (c.name == deckName) {
              remoteCategory = c;
              break;
            }
          }
          
          if (remoteCategory != null) {
            // Add the new category and its words
            final words = await _firebaseService.getWordsForCategory(remoteCategory.id);
            await _databaseHelper.insertCategory(remoteCategory);
            await _databaseHelper.insertWords(words);
          }
        } else {
          // Category exists locally
          if (isHardSync) {
            // Hard sync - replace everything
            final remoteCategory = await _firebaseService.getCategoryById(category.id);
            if (remoteCategory != null) {
              // Clear and replace with server version
              await _databaseHelper.clearWordsForCategory(category.id);
              final words = await _firebaseService.getWordsForCategory(category.id);
              await _databaseHelper.insertCategory(remoteCategory);
              await _databaseHelper.insertWords(words);
            }
          } else {
            // Soft sync - keep local changes and add new items from server
            final localWords = await _databaseHelper.getWordsByCategory(category.id);
            final localWordStrings = localWords.map((w) => w.word).toSet();
            
            // Get remote words
            final remoteWords = await _firebaseService.getWordsForCategory(category.id);
            final newWords = remoteWords.where(
              (w) => !localWordStrings.contains(w.word)
            ).toList();
            
            // Add only new words to the local database
            if (newWords.isNotEmpty) {
              await _databaseHelper.insertWords(newWords);
            }
          }
        }
      }
      
      // Update last sync timestamp
      await _updateLastSyncTimestamp();
      return true;
    } catch (e) {
      return false;
    }
  }
}