import 'package:flutter/material.dart';
import 'package:guess_it/repositories/category_repository.dart';
import 'package:guess_it/utils/admin_mode_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordRemovalScreen extends StatefulWidget {
  final String deckName;
  final List<String> correctWords;
  final List<String> passedWords;

  const WordRemovalScreen({
    Key? key,
    required this.deckName,
    required this.correctWords,
    required this.passedWords,
  }) : super(key: key);

  @override
  _WordRemovalScreenState createState() => _WordRemovalScreenState();
}

class _WordRemovalScreenState extends State<WordRemovalScreen> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  final AdminModeManager _adminManager = AdminModeManager();
  Set<String> _selectedWords = {};
  bool _isLoading = false;
  bool _isAdminMode = false;

  @override
  void initState() {
    super.initState();
    _checkAdminMode();
  }
  
  Future<void> _checkAdminMode() async {
    final isAdmin = await _adminManager.isAdminModeEnabled();
    setState(() {
      _isAdminMode = isAdmin;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allWords = [...widget.correctWords, ...widget.passedWords];

    return Scaffold(
      appBar: AppBar(
        title: Text('Remove Words from "${widget.deckName}"'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade200, Colors.blue.shade100],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Select words to remove from this deck:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Admin mode indicator
            if (_isAdminMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.green.shade700),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Admin Mode: Words will be removed from Firebase and locally',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: allWords.length,
                itemBuilder: (context, index) {
                  final word = allWords[index];
                  final isCorrect = widget.correctWords.contains(word);
                  
                  return CheckboxListTile(
                    title: Text(
                      word,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isCorrect ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    subtitle: Text(
                      isCorrect ? 'Correct' : 'Passed',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCorrect ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    value: _selectedWords.contains(word),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedWords.add(word);
                        } else {
                          _selectedWords.remove(word);
                        }
                      });
                    },
                    activeColor: Colors.red.shade600,
                    checkColor: Colors.white,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedWords.length == allWords.length) {
                          _selectedWords.clear();
                        } else {
                          _selectedWords = Set.from(allWords);
                        }
                      });
                    },
                    child: Text(
                      _selectedWords.length == allWords.length 
                          ? 'Unselect All' 
                          : 'Select All',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${_selectedWords.length} selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _selectedWords.isEmpty || _isLoading
                    ? null 
                    : _removeSelectedWords,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isAdminMode
                            ? 'Remove Selected Words'
                            : 'Remove Locally & Request Admin Approval',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSelectedWords() async {
    if (_selectedWords.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Call the repository method to remove the words
      await _categoryRepository.removeWordsFromCategory(
        widget.deckName, 
        _selectedWords.toList()
      );

      // Show a dialog explaining what happened
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: _isAdminMode 
              ? Text('Words Removed') 
              : Text('Words Removed Locally'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isAdminMode
                    ? '${_selectedWords.length} words have been removed from Firebase and your local deck.'
                    : '${_selectedWords.length} words have been removed from your local deck.',
                style: TextStyle(fontSize: 16),
              ),
              if (!_isAdminMode) ...[
                SizedBox(height: 16),
                Text(
                  'Additionally, a removal request has been sent to the administrator. If approved, these words will be removed for all users.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );

      Navigator.pop(context, true); // Return success to previous screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing words: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}