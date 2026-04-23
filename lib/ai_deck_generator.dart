import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:guess_it/database_helper.dart';
import 'package:guess_it/models/category_model.dart';
import 'package:guess_it/models/word_model.dart';
import 'package:uuid/uuid.dart';
import 'package:guess_it/utils/icon_mapping.dart'; // Import the icon mapping utility
import 'package:guess_it/repositories/category_repository.dart';

class AIDeckGenerator extends StatefulWidget {
  const AIDeckGenerator({Key? key}) : super(key: key);

  @override
  _AIDeckGeneratorState createState() => _AIDeckGeneratorState();
}

class _AIDeckGeneratorState extends State<AIDeckGenerator> {
  final _formKey = GlobalKey<FormState>();
  final _customWordController = TextEditingController();
  final _wordListController = TextEditingController();
  final _uuid = Uuid();
  
  String _categoryName = '';
  IconData _selectedIcon = Icons.category;
  List<String> _generatedWords = [];
  List<String> _selectedWords = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String _customWord = '';
  
  // Use the icon mapping utility instead of defining our own map
  Map<String, IconData> get _availableIcons => IconMapping.availableIcons;

  @override
  void dispose() {
    _customWordController.dispose();
    _wordListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Deck Creator'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade100, Colors.blue.shade100],
          ),
        ),
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    // Step 1: Create category and paste word list
    if (_generatedWords.isEmpty) {
      return _buildStep1();
    } 
    // Step 2: Review and select words
    else if (!_isProcessing) {
      return _buildStep2();
    } 
    // Step 3: Saving progress
    else {
      return _buildStep3();
    }
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step 1: Create Your Deck',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Deck Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.text_fields),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a deck name';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _categoryName = value?.trim() ?? '';
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select an Icon:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, index) {
                          final iconName = _availableIcons.keys.elementAt(index);
                          final iconData = _availableIcons.values.elementAt(index);
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIcon = iconData;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _selectedIcon == iconData 
                                    ? Colors.blue.shade100 
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _selectedIcon == iconData 
                                      ? Colors.blue.shade700 
                                      : Colors.transparent,
                                ),
                              ),
                              child: Tooltip(
                                message: iconName,
                                child: IconMapping.isFontAwesomeIcon(iconData)
                                    ? FaIcon(
                                        iconData,
                                        color: _selectedIcon == iconData 
                                            ? Colors.blue.shade700 
                                            : Colors.grey.shade700,
                                      )
                                    : Icon(
                                        iconData,
                                        color: _selectedIcon == iconData 
                                            ? Colors.blue.shade700 
                                            : Colors.grey.shade700,
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Words for Your Deck',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Paste a list of words below (one per line or comma-separated):',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _wordListController,
                      decoration: InputDecoration(
                        hintText: 'Example:\nWord 1\nWord 2\nWord 3\n\nor: Word 1, Word 2, Word 3',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 10,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please paste some words';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: You can generate this list from any source like ChatGPT, websites, or your own lists.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _isLoading ? null : _processWordList,
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Processing...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Process Words',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 2: Review and Select Words',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconMapping.isFontAwesomeIcon(_selectedIcon)
                          ? FaIcon(_selectedIcon, color: Colors.blue.shade700)
                          : Icon(_selectedIcon, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        _categoryName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the words you want to include in this deck:',
                    style: TextStyle(fontSize: 14),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.select_all),
                        label: Text('Select All'),
                        onPressed: () {
                          setState(() {
                            _selectedWords = List.from(_generatedWords);
                          });
                        },
                      ),
                      TextButton.icon(
                        icon: Icon(Icons.deselect),
                        label: Text('Deselect All'),
                        onPressed: () {
                          setState(() {
                            _selectedWords.clear();
                          });
                        },
                      ),
                      Text(
                        '${_selectedWords.length}/${_generatedWords.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  // Add a field to add custom words
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customWordController,
                          decoration: InputDecoration(
                            labelText: 'Add your own word',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            _customWord = value.trim();
                          },
                          onSubmitted: (_) => _addCustomWord(),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addCustomWord,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _generatedWords.length,
            itemBuilder: (context, index) {
              final word = _generatedWords[index];
              final isSelected = _selectedWords.contains(word);
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? Colors.blue.shade700 : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: CheckboxListTile(
                  title: Text(
                    word,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedWords.add(word);
                      } else {
                        _selectedWords.remove(word);
                      }
                    });
                  },
                  activeColor: Colors.blue.shade700,
                  // Add a delete button for custom words
                  secondary: IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.blueGrey.shade400),
                    onPressed: () {
                      setState(() {
                        _generatedWords.remove(word);
                        _selectedWords.remove(word);
                      });
                    },
                    tooltip: 'Remove word',
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _selectedWords.isEmpty ? null : _saveCategory,
            child: Text(
              'Create Deck with ${_selectedWords.length} Words',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Creating your deck...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This might take a moment.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _addCustomWord() {
    if (_customWord.isNotEmpty) {
      setState(() {
        if (!_generatedWords.contains(_customWord)) {
          _generatedWords.add(_customWord);
          _selectedWords.add(_customWord);
        }
        _customWordController.clear();
        _customWord = '';
      });
    }
  }

  // Process the pasted word list
  Future<void> _processWordList() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _formKey.currentState!.save();
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final wordListText = _wordListController.text.trim();
      List<String> words = [];
      
      // Try parsing as one-word-per-line first
      if (wordListText.contains('\n')) {
        words = wordListText
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .map((line) => line.trim())
            .toList();
      } 
      // If that doesn't yield much, try comma-separated
      else if (words.length < 2 && wordListText.contains(',')) {
        words = wordListText
            .split(',')
            .where((word) => word.trim().isNotEmpty)
            .map((word) => word.trim())
            .toList();
      }
      // Try other separators if needed
      else if (words.length < 2) {
        // Try semicolons
        if (wordListText.contains(';')) {
          words = wordListText
              .split(';')
              .where((word) => word.trim().isNotEmpty)
              .map((word) => word.trim())
              .toList();
        }
        // Try tabs
        else if (wordListText.contains('\t')) {
          words = wordListText
              .split('\t')
              .where((word) => word.trim().isNotEmpty)
              .map((word) => word.trim())
              .toList();
        }
        // Last resort, just split by whitespace
        else {
          words = wordListText
              .split(RegExp(r'\s+'))
              .where((word) => word.trim().isNotEmpty)
              .map((word) => word.trim())
              .toList();
        }
      }
      
      // Clean up and deduplicate the words
      words = words
          .where((word) => word.trim().length > 1) // Ensure words are at least 2 characters
          .map((word) => word.trim())
          .toSet() // Remove duplicates
          .toList();
      
      // Sort alphabetically for easier browsing
      words.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      
      setState(() {
        _generatedWords = words;
        _selectedWords = List.from(words); // Pre-select all by default
        _isLoading = false;
      });
      
      if (words.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No valid words found in the text. Please try again with a different format.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing the word list. Please try a different format.'),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }

// Modified _saveCategory method for AIDeckGenerator
Future<void> _saveCategory() async {
  if (_selectedWords.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please select at least one word'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  setState(() {
    _isProcessing = true;
  });
  
  try {
    final categoryId = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Map icon to its string representation using the utility
    String iconName = 'category'; // Default
    
    // Find the selected icon in the available icons map
    for (var entry in _availableIcons.entries) {
      if (entry.value == _selectedIcon) {
        // Convert display name to storage key
        iconName = IconMapping.displayNameToKey(entry.key);
        break;
      }
    }
    
    // Create the category model
    final category = CategoryModel(
      id: categoryId,
      name: _categoryName,
      icon: iconName,
      lastUpdated: timestamp,
    );
    
    final wordModels = _selectedWords.map((word) => WordModel(
      id: _uuid.v4(),
      categoryId: categoryId,
      word: word,
    )).toList();
    
    // Use the CategoryRepository's saveCustomDeck method
    // This will handle both local and Firebase storage
    final dbHelper = DatabaseHelper();
    final categoryRepository = CategoryRepository();
    
    // First save the category locally to ensure it exists
    await dbHelper.insertCategory(category);
    
    // Now use the repository method that we know works
    await categoryRepository.saveCustomDeck(category, wordModels);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deck "$_categoryName" created successfully with ${_selectedWords.length} words'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
    
    // Reset the state before navigating
    setState(() {
      _isProcessing = false;
      _generatedWords = [];
      _selectedWords = [];
      _wordListController.clear();
    });
    
    await Future.delayed(Duration(milliseconds: 50));

  } catch (e) {
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error creating deck: $e'),
        backgroundColor: Colors.red,
      ),
    );
    
    setState(() {
      _isProcessing = false;
    });
  }
}
}