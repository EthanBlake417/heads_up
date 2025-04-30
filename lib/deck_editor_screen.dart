// Update DeckEditorScreen to use the IconMapping utility
import 'package:flutter/material.dart';
import 'package:heads_up/repositories/category_repository.dart';
import 'package:heads_up/models/category_model.dart';
import 'package:heads_up/models/word_model.dart';
import 'package:heads_up/utils/icon_mapping.dart';
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
  final TextEditingController _wordController = TextEditingController();
  final _uuid = Uuid();
  
  List<String> _words = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _shouldSubmitToFirebase = false;
  String _statusMessage = '';
  String _selectedIcon = 'category'; // Default icon key
  IconData _iconData = Icons.category; // Default icon
  
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
        final category = await _categoryRepository.getCategoryByName(widget.deckName);
        if (category == null) {
          setState(() {
            _isLoading = false;
            _words = [];
            _statusMessage = 'Category not found';
          });
          return;
        }
        
        // Set the icon from the category
        _selectedIcon = category.icon;
        _iconData = IconMapping.getIconFromKey(_selectedIcon);
        
        final wordsList = await _categoryRepository.getWordsForCategory(widget.deckName);
        
        if (mounted) {
          setState(() {
            _words = wordsList;
            _isLoading = false;
            _statusMessage = '';
          });
        }
      } catch (e) {
        print('Error loading words: $e');
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _words = [];
            _statusMessage = 'Error: ${e.toString()}';
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading words: ${e.toString()}'),
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
  
  Future<void> _saveDeck() async {
    if (_words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one word to the deck'))
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
      _statusMessage = 'Saving deck...';
    });
    
    try {
      // Create or update the category and words locally
      final CategoryModel category = CategoryModel(
        id: widget.isNewDeck ? _uuid.v4() : widget.deckId,
        name: widget.deckName,
        icon: _selectedIcon, // Use the selected icon key
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );
      
      final List<WordModel> wordModels = _words.map((word) => WordModel(
        id: _uuid.v4(),
        categoryId: category.id,
        word: word,
      )).toList();
      
      // Save to local database
      await _categoryRepository.saveCustomDeck(category, wordModels);
      
      // If the user wants to submit to Firebase for approval
      if (_shouldSubmitToFirebase) {
        setState(() {
          _statusMessage = 'Submitting to online store...';
        });
        // await _categoryRepository.submitDeckToFirebase(category, wordModels);
      }
      
      // Only show success message and call callback if we're still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deck saved successfully!'),
            backgroundColor: Colors.green,
          )
        );
        
        // Call the callback if provided
        if (widget.onSaveCallback != null) {
          widget.onSaveCallback!();
        }
        
        // Use Navigator.pop with a delay to avoid black screen
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            Navigator.pop(context, true); // Return success
          }
        });
      }
    } catch (e) {
      print('Error saving deck: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving deck: ${e.toString()}'),
            backgroundColor: Colors.red,
          )
        );
        
        setState(() {
          _isSaving = false;
          _statusMessage = '';
        });
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
          title: Text(widget.isNewDeck ? 'Create New Deck' : 'Edit Deck: ${widget.deckName}'),
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
                tooltip: 'Save Deck',
              ),
          ],
        ),
        body: _isLoading
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CheckboxListTile(
                          title: Text('Submit to Online Store'),
                          subtitle: Text('Allow other users to download this deck'),
                          value: _shouldSubmitToFirebase,
                          onChanged: (value) {
                            setState(() {
                              _shouldSubmitToFirebase = value ?? false;
                            });
                          },
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
                      Expanded(
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
                                      'Add words using the field above',
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
                                  _statusMessage.isEmpty ? 'Saving...' : _statusMessage,
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
    );
  }
}