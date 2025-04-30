// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heads_up/models/category_model.dart';
import 'package:heads_up/models/word_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:heads_up/utils/admin_mode_manager.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminModeManager _adminManager = AdminModeManager();

  // Check internet connection
  Future<bool> hasInternetConnection() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // Additional check - try to reach Firebase
      try {
        final DocumentSnapshot testDoc = await _firestore.collection('metadata').doc('version').get();
        // If we got here, we definitely have a connection
        return true;
      } catch (e) {
        print('Could not reach Firebase: $e');
        return false;
      }
    } catch (e) {
      print('Error checking connectivity: $e');
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
      print('Error fetching category by ID: $e');
      return null;
    }
  }

  Future<List<CategoryModel>> getCategories() async {
    try {
      if (!await hasInternetConnection()) {
        print('No internet connection while getting categories');
        return [];
      }
      
      print('Fetching all categories from Firestore...');
      final QuerySnapshot snapshot = await _firestore.collection('categories').get();
      
      final categories = snapshot.docs.map((doc) {
        return CategoryModel.fromFirestore(
          doc.data() as Map<String, dynamic>, 
          doc.id
        );
      }).toList();
      
      print('Successfully fetched ${categories.length} categories from Firestore');
      return categories;
    } catch (e) {
      print('Error fetching categories from Firestore: $e');
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
      print('Error fetching updated categories: $e');
      return [];
    }
  }

  // Get words for a category
  Future<List<WordModel>> getWordsForCategory(String categoryId) async {
    try {
      if (!await hasInternetConnection()) {
        print('No internet connection while getting words');
        return [];
      }
      
      print('Fetching words for category $categoryId...');
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
        
        print('Fetched ${words.length} words in this batch');
        
        if (snapshot.docs.length < 1000) {
          hasMoreDocs = false;
        } else {
          lastDoc = snapshot.docs.last;
        }
      }
      
      print('Successfully fetched ${allWords.length} total words for category $categoryId');
      return allWords;
    } catch (e) {
      print('Error fetching words for category $categoryId: $e');
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
      
      return 0;
    } catch (e) {
      print('Error fetching version: $e');
      return 0;
    }
  }

  // SIMPLIFIED: Direct update methods for admin mode

  // Save or update a category directly to Firebase
  Future<bool> saveCategoryToFirebase(CategoryModel category, List<WordModel> words) async {
    try {
      if (!await hasInternetConnection()) {
        return false;
      }
      
      // Only allow this operation in admin mode
      if (!await _adminManager.isAdminModeEnabled()) {
        print('Not in admin mode, Firebase update rejected');
        return false;
      }
      
      // Update the category document
      await _firestore.collection('categories').doc(category.id).set({
        'name': category.name,
        'icon': category.icon,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Get existing words to find ones to delete
      QuerySnapshot existingWords = await _firestore
          .collection('categories')
          .doc(category.id)
          .collection('words')
          .get();
      
      // Get word strings for faster comparison
      Set<String> newWordStrings = words.map((w) => w.word).toSet();
      
      // Create a batch for better performance
      WriteBatch batch = _firestore.batch();
      
      // Handle deletions - remove words that are no longer in the deck
      for (var doc in existingWords.docs) {
        String wordText = (doc.data() as Map<String, dynamic>)['word'] ?? '';
        if (!newWordStrings.contains(wordText)) {
          batch.delete(doc.reference);
        }
      }
      
      // Handle additions - add all new words
      Set existingWordStrings = existingWords.docs.map((doc) => (doc.data() as Map<String, dynamic>)['word'] ?? '').toSet();
      
      for (var word in words) {
        if (!existingWordStrings.contains(word.word)) {
          DocumentReference wordRef = _firestore
              .collection('categories')
              .doc(category.id)
              .collection('words')
              .doc();
          
          batch.set(wordRef, {'word': word.word});
        }
      }
      
      // Commit all changes
      await batch.commit();
      
      print('Category and words updated in Firebase: ${category.name}');
      return true;
    } catch (e) {
      print('Error saving category to Firebase: $e');
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
        print('Not in admin mode, Firebase deletion rejected');
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
      
      print('Category and words deleted from Firebase: $categoryId');
      return true;
    } catch (e) {
      print('Error deleting category from Firebase: $e');
      return false;
    }
  }
  
  // Remove specific words from a category in Firebase
  Future<bool> removeWordsFromFirebase(String categoryId, List<String> wordsToRemove) async {
    try {
      if (!await hasInternetConnection()) {
        return false;
      }
      
      // Only allow this operation in admin mode
      if (!await _adminManager.isAdminModeEnabled()) {
        print('Not in admin mode, Firebase word removal rejected');
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
      
      print('Words removed from Firebase: ${wordsToRemove.length} words');
      return true;
    } catch (e) {
      print('Error removing words from Firebase: $e');
      return false;
    }
  }
}