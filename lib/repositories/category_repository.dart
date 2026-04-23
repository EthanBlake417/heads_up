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
  static final CategoryRepository _instance = CategoryRepository._internal();
  factory CategoryRepository() => _instance;
  CategoryRepository._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final AdminModeManager _adminManager = AdminModeManager();
  final _uuid = Uuid();

  IconData getIconForCategory(String iconName) {
    return IconMapping.getIconFromKey(iconName);
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final categories = await _databaseHelper.getCategories();

    return categories.map((category) {
      return {
        'id': category.id,
        'name': category.name,
        'icon': IconMapping.getIconFromKey(category.icon),
        'iconKey': category.icon,
        'isCustom': false,
      };
    }).toList();
  }

  Future<bool> shouldSyncData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt('lastSyncTimestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - lastSync > 86400000) {
        return true;
      }

      final localVersion = await _databaseHelper.getLastUpdatedTimestamp();
      final remoteVersion = await _firebaseService.getLatestVersion();

      return remoteVersion > localVersion;
    } catch (e) {
      debugPrint('CategoryRepository.shouldSyncData error: $e');
      return false;
    }
  }

  Future<bool> syncData() async {
    try {
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (!hasInternet) {
        return false;
      }

      final localVersion = await _databaseHelper.getLastUpdatedTimestamp();
      final categories = await _firebaseService.getCategoriesSince(localVersion);

      if (categories.isEmpty) {
        await _updateLastSyncTimestamp();
        return true;
      }

      // Fetch all categories' words in parallel instead of sequentially
      final wordLists = await Future.wait(
        categories.map((c) => _firebaseService.getWordsForCategory(c.id)),
      );

      for (int i = 0; i < categories.length; i++) {
        await _databaseHelper.insertCategory(categories[i]);
        await _databaseHelper.clearWordsForCategory(categories[i].id);
        await _databaseHelper.insertWords(wordLists[i]);
      }

      await _updateLastSyncTimestamp();
      return true;
    } catch (e) {
      debugPrint('CategoryRepository.syncData error: $e');
      return false;
    }
  }

  Future<bool> hasInitialData() async {
    final categories = await _databaseHelper.getCategories();
    return categories.isNotEmpty;
  }

  Future<void> loadInitialData() async {
    await _loadDefaultCategories();
  }

  Future<void> _loadDefaultCategories() async {
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
    ];

    await _databaseHelper.insertCategories(defaultCategories);

    for (var category in defaultCategories) {
      List<WordModel> defaultWords = [];

      if (category.name == 'Animals') {
        final List<String> animalWords = [
          'Elephant', 'Lion', 'Giraffe', 'Penguin', 'Kangaroo',
          'Dolphin', 'Koala', 'Tiger', 'Panda', 'Cheetah',
        ];

        defaultWords = animalWords.map((word) => WordModel(
          id: _uuid.v4(),
          categoryId: category.id,
          word: word,
        )).toList();
      }

      if (defaultWords.isNotEmpty) {
        await _databaseHelper.insertWords(defaultWords);
      }
    }
  }

  Future<void> _updateLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastSyncTimestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<List<String>> getWordsForCategory(String categoryName) async {
    try {
      if (categoryName == 'All Categories') {
        return await _databaseHelper.getAllWords();
      }

      final category = await _databaseHelper.getCategoryByName(categoryName);

      if (category == null) {
        return [];
      }

      final wordsByName = await _databaseHelper.getWordStringsByCategory(categoryName);

      if (wordsByName.isNotEmpty) {
        return wordsByName;
      }

      final wordsById = await _databaseHelper.getWordsByCategory(category.id);
      return wordsById.map((word) => word.word).toList();
    } catch (e) {
      debugPrint('CategoryRepository.getWordsForCategory error: $e');
      return [];
    }
  }

  Future<bool> forceSync() async {
    try {
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (!hasInternet) {
        return false;
      }

      final categories = await _firebaseService.getCategories();

      if (categories.isEmpty) {
        return false;
      }

      await _databaseHelper.clearAllData();
      await _databaseHelper.insertCategories(categories);

      // Fetch all words in parallel
      final wordLists = await Future.wait(
        categories.map((c) => _firebaseService.getWordsForCategory(c.id)),
      );

      for (final words in wordLists) {
        await _databaseHelper.insertWords(words);
      }

      await _updateLastSyncTimestamp();
      return true;
    } catch (e) {
      debugPrint('CategoryRepository.forceSync error: $e');
      return false;
    }
  }

  Future<CategoryModel?> getCategoryByName(String name) async {
    try {
      final category = await _databaseHelper.getCategoryByName(name);
      if (category != null) {
        return category;
      }

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
      debugPrint('CategoryRepository.getCategoryByName error: $e');
      return null;
    }
  }

  Future<void> removeWordsFromCategory(String categoryName, List<String> wordsToRemove) async {
    final category = await _databaseHelper.getCategoryByName(categoryName);
    if (category == null) {
      throw Exception('Category not found: $categoryName');
    }

    final currentWords = await _databaseHelper.getWordsByCategory(category.id);
    final wordsToKeep = currentWords
        .where((word) => !wordsToRemove.contains(word.word))
        .toList();

    await _databaseHelper.clearWordsForCategory(category.id);
    if (wordsToKeep.isNotEmpty) {
      await _databaseHelper.insertWords(wordsToKeep);
    }

    if (await _adminManager.isAdminModeEnabled()) {
      await _firebaseService.removeWordsFromFirebase(category.id, wordsToRemove);
    }
  }

  Future<void> saveCustomDeck(CategoryModel category, List<WordModel> words) async {
    await _databaseHelper.insertCategory(category);
    await _databaseHelper.clearWordsForCategory(category.id);
    await _databaseHelper.insertWords(words);

    if (await _adminManager.isAdminModeEnabled()) {
      await _firebaseService.saveCategoryToFirebase(category, words);
    }
  }

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

  Future<void> restoreFromBackup(List<dynamic> backupData) async {
    await _databaseHelper.clearAllData();

    for (final item in backupData) {
      final category = CategoryModel.fromMap(item['category'] as Map<String, dynamic>);
      await _databaseHelper.insertCategory(category);

      final words = (item['words'] as List<dynamic>)
          .map((w) => WordModel.fromMap(w as Map<String, dynamic>))
          .toList();
      await _databaseHelper.insertWords(words);
    }

    if (await _adminManager.isAdminModeEnabled()) {
      await syncDataToFirebase();
    }
  }

  Future<bool> syncDataToFirebase() async {
    try {
      if (!await _firebaseService.hasInternetConnection()) {
        return false;
      }

      if (!await _adminManager.isAdminModeEnabled()) {
        return false;
      }

      final localData = await getAllCategoriesWithWords();

      for (final item in localData) {
        final category = CategoryModel.fromMap(item['category'] as Map<String, dynamic>);
        final wordsList = (item['words'] as List<dynamic>)
            .map((w) => WordModel.fromMap(w as Map<String, dynamic>))
            .toList();
        await _firebaseService.saveCategoryToFirebase(category, wordsList);
      }

      return true;
    } catch (e) {
      debugPrint('CategoryRepository.syncDataToFirebase error: $e');
      return false;
    }
  }

  Future<bool> deleteDeck(dynamic deckId) async {
    final String categoryId = deckId is Map ? deckId['id'] : deckId;

    try {
      await _databaseHelper.clearWordsForCategory(categoryId);
      final result = await _databaseHelper.deleteCategory(categoryId);

      if (await _adminManager.isAdminModeEnabled()) {
        await _firebaseService.deleteCategoryFromFirebase(categoryId);
      }

      return result > 0;
    } catch (e) {
      debugPrint('CategoryRepository.deleteDeck error: $e');
      return false;
    }
  }

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
      debugPrint('CategoryRepository.getCategoryById error: $e');
      return null;
    }
  }

  Future<bool> downloadDeck(String categoryId) async {
    try {
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (!hasInternet) {
        return false;
      }

      final category = await _firebaseService.getCategoryById(categoryId);
      if (category == null) {
        return false;
      }

      final words = await _firebaseService.getWordsForCategory(categoryId);

      final db = await _databaseHelper.database;

      try {
        await db.transaction((txn) async {
          final existingCat = await txn.query(
            'categories',
            where: 'id = ?',
            whereArgs: [categoryId],
          );

          if (existingCat.isNotEmpty) {
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
            await txn.delete(
              'words',
              where: 'categoryId = ?',
              whereArgs: [categoryId],
            );
          } else {
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

        final savedCategory = await _databaseHelper.getCategoryByName(category.name);
        if (savedCategory == null) {
          return false;
        }

        final savedWords = await _databaseHelper.getWordsByCategory(category.id);
        return savedWords.isNotEmpty;
      } catch (e) {
        debugPrint('CategoryRepository.downloadDeck transaction error: $e');
        return false;
      }
    } catch (e) {
      debugPrint('CategoryRepository.downloadDeck error: $e');
      return false;
    }
  }

  Future<bool> syncSelectedDecks(List<String> deckNames, bool isHardSync) async {
    try {
      final hasInternet = await _firebaseService.hasInternetConnection();
      if (!hasInternet) {
        return false;
      }

      for (final deckName in deckNames) {
        final category = await _databaseHelper.getCategoryByName(deckName);

        if (category == null) {
          // New deck — fetch all remote categories once and find matching one
          final categories = await _firebaseService.getCategories();
          CategoryModel? remoteCategory;
          for (var c in categories) {
            if (c.name == deckName) {
              remoteCategory = c;
              break;
            }
          }

          if (remoteCategory != null) {
            final words = await _firebaseService.getWordsForCategory(remoteCategory.id);
            await _databaseHelper.insertCategory(remoteCategory);
            await _databaseHelper.insertWords(words);
          }
        } else if (isHardSync) {
          final remoteCategory = await _firebaseService.getCategoryById(category.id);
          if (remoteCategory != null) {
            await _databaseHelper.clearWordsForCategory(category.id);
            final words = await _firebaseService.getWordsForCategory(category.id);
            await _databaseHelper.insertCategory(remoteCategory);
            await _databaseHelper.insertWords(words);
          }
        } else {
          // Soft sync — only add words that don't exist locally
          final localWords = await _databaseHelper.getWordsByCategory(category.id);
          final localWordStrings = localWords.map((w) => w.word).toSet();
          final remoteWords = await _firebaseService.getWordsForCategory(category.id);
          final newWords = remoteWords
              .where((w) => !localWordStrings.contains(w.word))
              .toList();
          if (newWords.isNotEmpty) {
            await _databaseHelper.insertWords(newWords);
          }
        }
      }

      await _updateLastSyncTimestamp();
      return true;
    } catch (e) {
      debugPrint('CategoryRepository.syncSelectedDecks error: $e');
      return false;
    }
  }
}
