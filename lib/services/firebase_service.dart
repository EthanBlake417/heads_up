import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:guess_it/models/category_model.dart';
import 'package:guess_it/models/word_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:guess_it/utils/admin_mode_manager.dart';
import 'package:guess_it/utils/word_filter.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminModeManager _adminManager = AdminModeManager();

  Future<bool> hasInternetConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('FirebaseService.hasInternetConnection error: $e');
      return false;
    }
  }

  // Get a category by ID
  Future<CategoryModel?> getCategoryById(String categoryId) async {
    try {
      if (!await hasInternetConnection()) {
        return null;
      }
      
      final DocumentSnapshot doc = await _firestore.collection('categories').doc(categoryId).get();
      
      if (doc.exists) {
        return CategoryModel.fromFirestore(
          doc.data() as Map<String, dynamic>, 
          doc.id
        );
      }
      
      return null;
    } catch (e) {
      debugPrint('FirebaseService.getCategoryById error: $e');
      return null;
    }
  }

  Future<List<CategoryModel>> getCategories() async {
    try {
      if (!await hasInternetConnection()) {
        return [];
      }

      final QuerySnapshot snapshot = await _firestore.collection('categories').get();

      final categories = snapshot.docs.map((doc) {
        return CategoryModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id
        );
      }).toList();

      return categories;
    } catch (e) {
      debugPrint('FirebaseService.getCategories error: $e');
      return [];
    }
  }

  // Get categories updated since a timestamp
  Future<List<CategoryModel>> getCategoriesSince(int timestamp) async {
    try {
      if (!await hasInternetConnection()) {
        return [];
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('categories')
          .where('lastUpdated', isGreaterThan: timestamp)
          .get();

      return snapshot.docs.map((doc) {
        return CategoryModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id
        );
      }).toList();
    } catch (e) {
      debugPrint('FirebaseService.getCategoriesSince error: $e');
      return [];
    }
  }

  // Get words for a category
  Future<List<WordModel>> getWordsForCategory(String categoryId) async {
    try {
      if (!await hasInternetConnection()) {
        return [];
      }
      
      List<WordModel> allWords = [];
      
      // Use pagination to get all words (Firebase limits to ~1000 docs per query)
      QuerySnapshot snapshot;
      DocumentSnapshot? lastDoc;
      bool hasMoreDocs = true;
      
      while (hasMoreDocs) {
        Query query = _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('words')
            .limit(1000); // Max batch size
        
        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }
        
        snapshot = await query.get();
        
        final words = snapshot.docs.map((doc) {
          return WordModel.fromFirestore(
            doc.data() as Map<String, dynamic>, 
            doc.id,
            categoryId
          );
        }).toList();
        
        allWords.addAll(words);
        
        
        if (snapshot.docs.length < 1000) {
          hasMoreDocs = false;
        } else {
          lastDoc = snapshot.docs.last;
        }
      }
      
      return allWords;
    } catch (e) {
      debugPrint('FirebaseService.getWordsForCategory error: $e');
      return [];
    }
  }

  // Version check - to see if we need to update data
  Future<int> getLatestVersion() async {
    try {
      if (!await hasInternetConnection()) {
        return 0;
      }
      
      final DocumentSnapshot snapshot = await _firestore
          .collection('metadata')
          .doc('version')
          .get();
      
      if (snapshot.exists) {
        return (snapshot.data() as Map<String, dynamic>)['timestamp'] ?? 0;
      }
      
      // If no version document exists, try to get the latest timestamp from categories
      try {
        final QuerySnapshot categoriesSnapshot = await _firestore
            .collection('categories')
            .orderBy('lastUpdated', descending: true)
            .limit(1)
            .get();
            
        if (categoriesSnapshot.docs.isNotEmpty) {
          final latestCategory = categoriesSnapshot.docs.first.data() as Map<String, dynamic>;
          return latestCategory['lastUpdated'] ?? 0;
        }
      } catch (innerError) {
      }
      
      return 0;
    } catch (e) {
      debugPrint('FirebaseService.getLatestVersion error: $e');
      return 0;
    }
  }

  // IMPROVED: Save a category and its words to Firebase - fixes word saving issue
  Future<bool> saveCategoryToFirebase(CategoryModel category, List<WordModel> words) async {
    try {
      if (!await hasInternetConnection()) {
        return false;
      }
      
      // Only allow this operation in admin mode
      if (!await _adminManager.isAdminModeEnabled()) {
        return false;
      }
      
      
      // First, make sure the category exists
      await _firestore.collection('categories').doc(category.id).set({
        'name': category.name,
        'icon': category.icon,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        'custom': true, // Mark as a custom category
      });
      
      
      // Clear existing words for this category to avoid duplicates
      // Get reference to words collection
      CollectionReference wordsCollection = _firestore
          .collection('categories')
          .doc(category.id)
          .collection('words');
      
      // First, clear out any existing words to avoid duplicates
      try {
        // Get all existing words
        QuerySnapshot existingWords = await wordsCollection.get();
        
        // Delete in batches (Firestore limits batch size)
        int batchSize = 0;
        WriteBatch deleteBatch = _firestore.batch();
        
        for (var doc in existingWords.docs) {
          deleteBatch.delete(doc.reference);
          batchSize++;
          
          // Commit batch when it reaches limit
          if (batchSize >= 500) {
            await deleteBatch.commit();
            deleteBatch = _firestore.batch();
            batchSize = 0;
          }
        }
        
        // Commit remaining deletes
        if (batchSize > 0) {
          await deleteBatch.commit();
        }
      } catch (e) {
        debugPrint('FirebaseService.saveCategoryToFirebase delete error: $e');
      }

      // Add all new words in batches of 500 (Firestore limit)
      int totalAdded = 0;

      for (int i = 0; i < words.length; i += 500) {
        final chunk = words.sublist(i, (i + 500 < words.length) ? i + 500 : words.length);

        try {
          final batch = _firestore.batch();
          for (var word in chunk) {
            final wordRef = wordsCollection.doc(word.id);
            batch.set(wordRef, {'word': word.word});
          }
          await batch.commit();
          totalAdded += chunk.length;
        } catch (e) {
          debugPrint('FirebaseService.saveCategoryToFirebase batch error: $e');
        }
      }
      
      
      // Update category timestamp to reflect the change
      await _firestore.collection('categories').doc(category.id).update({
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
      
      return totalAdded > 0 || words.isEmpty;
    } catch (e) {
      debugPrint('FirebaseService.saveCategoryToFirebase error: $e');
      return false;
    }
  }

  // Delete a category directly from Firebase
  Future<bool> deleteCategoryFromFirebase(String categoryId) async {
    try {
      if (!await hasInternetConnection()) {
        return false;
      }
      
      // Only allow this operation in admin mode
      if (!await _adminManager.isAdminModeEnabled()) {
        return false;
      }
      
      // Delete all words in the category
      QuerySnapshot wordDocs = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('words')
          .get();
      
      WriteBatch batch = _firestore.batch();
      
      // Add word deletions to batch
      for (var doc in wordDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // Add category deletion to batch
      batch.delete(_firestore.collection('categories').doc(categoryId));
      
      // Execute all deletions
      await batch.commit();
      
      return true;
    } catch (e) {
      debugPrint('FirebaseService.deleteCategoryFromFirebase error: $e');
      return false;
    }
  }

  Future<Map<String, int>> pruneInappropriateWords() async {
    int totalChecked = 0;
    int totalRemoved = 0;

    if (!await hasInternetConnection()) {
      return {'checked': 0, 'removed': 0};
    }

    if (!await _adminManager.isAdminModeEnabled()) {
      return {'checked': 0, 'removed': 0};
    }

    final categories = await getCategories();

    for (final category in categories) {
      final words = await getWordsForCategory(category.id);
      totalChecked += words.length;

      final toRemove = words.where((w) => WordFilter.isInappropriate(w.word)).toList();
      if (toRemove.isEmpty) continue;

      // Delete in batches of 500 (Firestore limit)
      for (int i = 0; i < toRemove.length; i += 500) {
        final chunk = toRemove.sublist(i, (i + 500 < toRemove.length) ? i + 500 : toRemove.length);
        final batch = _firestore.batch();
        for (final word in chunk) {
          batch.delete(
            _firestore.collection('categories').doc(category.id).collection('words').doc(word.id),
          );
        }
        await batch.commit();
      }

      // Bump the category's lastUpdated so clients re-sync the word list
      await _firestore.collection('categories').doc(category.id).update({
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });

      totalRemoved += toRemove.length;
    }

    return {'checked': totalChecked, 'removed': totalRemoved};
  }

  // Remove specific words from a category in Firebase
  Future<bool> removeWordsFromFirebase(String categoryId, List<String> wordsToRemove) async {
    try {
      if (!await hasInternetConnection()) {
        return false;
      }
      
      // Only allow this operation in admin mode
      if (!await _adminManager.isAdminModeEnabled()) {
        return false;
      }
      
      // Find all matching words
      WriteBatch batch = _firestore.batch();
      
      for (String word in wordsToRemove) {
        QuerySnapshot matchingWords = await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('words')
            .where('word', isEqualTo: word)
            .get();
        
        for (var doc in matchingWords.docs) {
          batch.delete(doc.reference);
        }
      }
      
      // Update the category's timestamp
      batch.update(
        _firestore.collection('categories').doc(categoryId),
        {'lastUpdated': DateTime.now().millisecondsSinceEpoch}
      );
      
      // Execute all deletions
      await batch.commit();
      
      return true;
    } catch (e) {
      debugPrint('FirebaseService.removeWordsFromFirebase error: $e');
      return false;
    }
  }
}