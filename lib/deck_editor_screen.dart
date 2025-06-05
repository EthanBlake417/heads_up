// Updated deck_editor_screen.dart with scrollable view to fix pixel overflow
import 'package:flutter/material.dart';
import 'package:guess_it/repositories/category_repository.dart';
import 'package:guess_it/services/firebase_service.dart';
import 'package:guess_it/models/category_model.dart';
import 'package:guess_it/models/word_model.dart';
import 'package:guess_it/utils/icon_mapping.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:uuid/uuid.dart';

class DeckEditorScreen extends StatefulWidget {
  final String deckId;
  final String deckName;
  final bool isNewDeck;
  final VoidCallback? onSaveCallback;

  const DeckEditorScreen({
    Key? key, 
    required this.deckId, 
    required this.deckName, 
    this.isNewDeck = false,
    this.onSaveCallback,
  }) : super(key: key);

  @override
  _DeckEditorScreenState createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _bulkWordController = TextEditingController();
  final _uuid = Uuid();
  
  List<String> _words = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _statusMessage = '';
  String _selectedIcon = 'category'; // Default icon key
  IconData _iconData = Icons.category; // Default icon
  
  bool _showBulkImport = false;
  
  @override
  void initState() {
    super.initState();
    _loadWords();
  }
  
  void _loadWords() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading words...';
    });
    
    if (!widget.isNewDeck) {
      try {
        // For existing decks, load data directly from Firebase
        final category = await _firebaseService.getCategoryById(widget.deckId);
        if (category == null) {
          setState(() {
            _isLoading = false;
            _words = [];
            _statusMessage = 'Category not found on Firebase';
          });
          return;
        }
        
        // Set the icon from the category
        _selectedIcon = category.icon;
        _iconData = IconMapping.getIconFromKey(_selectedIcon);
        
        // Load words directly from Firebase
        final wordModels = await _firebaseService.getWordsForCategory(widget.deckId);
        final wordsList = wordModels.map((w) => w.word).toList();
        
        if (mounted) {
          setState(() {
            _words = wordsList;
            _isLoading = false;
            _statusMessage = '';
          });
        }
      } catch (e) {
        print('Error loading words from Firebase: $e');
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _words = [];
            _statusMessage = 'Error: ${e.toString()}';
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading words from Firebase: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      setState(() {
        _words = [];
        _isLoading = false;
        _statusMessage = '';
      });
    }
  }
  
  void _addWord() {
    final word = _wordController.text.trim();
    if (word.isNotEmpty) {
      setState(() {
        if (!_words.contains(word)) {
          _words.add(word);
        } else {
          // Show message that word already exists
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Word "$word" already exists in this deck'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        _wordController.clear();
      });
    }
  }
  
  void _removeWord(String word) {
    setState(() {
      _words.remove(word);
    });
  }
  
  // Process bulk word import
  void _processBulkWords() {
    final wordListText = _bulkWordController.text.trim();
    if (wordListText.isEmpty) return;
    
    List<String> newWords = [];
    
    // Try parsing as one-word-per-line first
    if (wordListText.contains('\n')) {
      newWords = wordListText
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.trim())
          .toList();
    } 
    // If that doesn't yield much, try comma-separated
    else if (wordListText.contains(',')) {
      newWords = wordListText
          .split(',')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();
    }
    // Try other separators if needed
    else if (wordListText.contains(';')) {
      newWords = wordListText
          .split(';')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();
    }
    // Last resort, just split by whitespace
    else {
      newWords = wordListText
          .split(RegExp(r'\s+'))
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();
    }
    
    // Clean up and deduplicate the words
    newWords = newWords
        .where((word) => word.trim().length > 1) // Ensure words are at least 2 characters
        .toList();
    
    // Add new words and remove duplicates
    setState(() {
      for (var word in newWords) {
        if (!_words.contains(word)) {
          _words.add(word);
        }
      }
      
      // Clear the bulk input
      _bulkWordController.clear();
      // Hide the bulk input after processing
      _showBulkImport = false;
    });
    
    // Show success message
    if (newWords.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${newWords.length} new unique words'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No new unique words found in the text'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  Future<void> _saveDeck() async {
    if (_words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one word to the deck'))
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
      _statusMessage = 'Saving deck to Firebase...';
    });
    
    try {
      // Generate a valid category ID
      final String categoryId = widget.isNewDeck ? _uuid.v4() : widget.deckId;
      
      // Create or update the category
      final CategoryModel category = CategoryModel(
        id: categoryId,
        name: widget.deckName,
        icon: _selectedIcon,
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );
      
      // Create word models for all words
      final List<WordModel> wordModels = _words.map((word) => WordModel(
        id: _uuid.v4(),
        categoryId: categoryId,
        word: word,
      )).toList();
      
      // First try to save to Firebase
      print('Saving to Firebase: ${category.name} with ${wordModels.length} words');
      final success = await _firebaseService.saveCategoryToFirebase(category, wordModels);
      
      if (success) {
        // If Firebase succeeds, save locally
        print('Firebase save successful, now saving locally...');
        await _categoryRepository.saveCustomDeck(category, wordModels);
        
        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deck saved successfully!'),
              backgroundColor: Colors.green,
            )
          );
          
          // Set state to not saving before callbacks
          setState(() {
            _isSaving = false;
            _statusMessage = '';
          });
          
          // Call the callback if provided
          if (widget.onSaveCallback != null) {
            widget.onSaveCallback!();
          }
          
          // IMPORTANT: To prevent black screen, handle navigation correctly
          // Use a post-frame callback to ensure the state update is processed
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          });
        }
      } else {
        // Only update state if still mounted
        if (mounted) {
          setState(() {
            _isSaving = false;
            _statusMessage = '';
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving to Firebase. Please try again.'),
              backgroundColor: Colors.red,
            )
          );
        }
      }
    } catch (e) {
      print('Error saving deck: $e');
      
      // Only update state if still mounted
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = '';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving deck: ${e.toString()}'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }
  
  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choose an Icon'),
        content: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.6, // Set a fixed height
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.85, // Adjusted to fit text
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: IconMapping.availableIcons.length,
            itemBuilder: (context, index) {
              final iconName = IconMapping.availableIcons.keys.elementAt(index);
              final iconData = IconMapping.availableIcons.values.elementAt(index);
              
              // Convert display name to storage key
              final iconKey = IconMapping.displayNameToKey(iconName);
              
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedIcon = iconKey;
                    _iconData = iconData;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedIcon == iconKey ? Colors.blue : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Use the utility to check for FontAwesome icons
                      IconMapping.isFontAwesomeIcon(iconData)
                          ? FaIcon(iconData, size: 24)
                          : Icon(iconData, size: 24),
                      SizedBox(height: 4),
                      Text(
                        iconName,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _wordController.dispose();
    _bulkWordController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog if there are unsaved changes
        if (_words.isNotEmpty && !_isSaving) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Discard changes?'),
              content: Text('You have unsaved changes. Are you sure you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Stay'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Discard'),
                ),
              ],
            ),
          ) ?? false;
          
          return shouldExit;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNewDeck ? 'Create New Deck' : 'Edit Firebase Deck: ${widget.deckName}'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          actions: [
            if (_isSaving)
              Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ))
            else
              IconButton(
                icon: Icon(Icons.save),
                onPressed: _saveDeck,
                tooltip: 'Save to Firebase',
              ),
          ],
        ),
        // Wrap the entire body in a SingleChildScrollView to fix pixel overflow
        body: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                        AppBar().preferredSize.height - 
                        MediaQuery.of(context).padding.top,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple.shade200, Colors.blue.shade100],
              ),
            ),
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(_statusMessage),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Icon selection
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Use the utility to check for FontAwesome icons
                                    IconMapping.isFontAwesomeIcon(_iconData)
                                        ? FaIcon(_iconData, size: 48, color: Colors.blue.shade700)
                                        : Icon(_iconData, size: 48, color: Colors.blue.shade700),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Deck Icon',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Choose an icon to represent this deck',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _showIconPicker,
                                      child: Text('Change'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Word input
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _wordController,
                                    decoration: InputDecoration(
                                      labelText: 'Add a word',
                                      hintText: 'Enter a word to add to the deck',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.add_circle_outline),
                                    ),
                                    onSubmitted: (_) => _addWord(),
                                    textInputAction: TextInputAction.done,
                                  ),
                                ),
                                SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: _addWord,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: Text('Add'),
                                ),
                              ],
                            ),
                          ),
                          // Bulk import option
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton.icon(
                                  icon: Icon(_showBulkImport ? Icons.expand_less : Icons.expand_more),
                                  label: Text(_showBulkImport ? 'Hide Bulk Import' : 'Show Bulk Import'),
                                  onPressed: () {
                                    setState(() {
                                      _showBulkImport = !_showBulkImport;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          // Bulk import area
                          if (_showBulkImport)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Card(
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bulk Import Words',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Paste a list of words below (one per line or comma-separated):',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      SizedBox(height: 8),
                                      TextField(
                                        controller: _bulkWordController,
                                        decoration: InputDecoration(
                                          hintText: 'Example:\nWord 1\nWord 2\nWord 3\n\nor: Word 1, Word 2, Word 3',
                                          border: OutlineInputBorder(),
                                          alignLabelWithHint: true,
                                        ),
                                        maxLines: 8,
                                      ),
                                      SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton(
                                            onPressed: _processBulkWords,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade600,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: Text('Process Words'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Firebase note
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_upload, color: Colors.blue.shade700),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Changes will be saved to Firebase when you press Save',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Words (${_words.length})',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_words.isNotEmpty)
                                  TextButton.icon(
                                    icon: Icon(Icons.sort_by_alpha),
                                    label: Text('Sort Alphabetically'),
                                    onPressed: () {
                                      setState(() {
                                        _words.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                          // Word list
                          Container(
                            constraints: BoxConstraints(minHeight: 200, maxHeight: MediaQuery.of(context).size.height * 0.6),
                            // height: 300, // Fixed height for word list
                            child: _words.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.info_outline, size: 48, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text(
                                          'No words added yet',
                                          style: TextStyle(fontSize: 18, color: Colors.grey),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Add words using the field above or bulk import',
                                          style: TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _words.length,
                                    itemBuilder: (context, index) {
                                      final word = _words[index];
                                      return Dismissible(
                                        key: Key('word-$word-$index'),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: EdgeInsets.only(right: 20.0),
                                          color: Colors.red,
                                          child: Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                          ),
                                        ),
                                        onDismissed: (direction) {
                                          _removeWord(word);
                                        },
                                        child: ListTile(
                                          title: Text(
                                            word,
                                            style: TextStyle(fontSize: 16),
                                          ),
                                          trailing: IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _removeWord(word),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          SizedBox(height: 20), // Add some bottom padding
                        ],
                      ),
                      // Status overlay
                      if (_isSaving)
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: Center(
                            child: Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      _statusMessage.isEmpty ? 'Saving to Firebase...' : _statusMessage,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}