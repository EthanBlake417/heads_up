// deck_management_screen.dart
import 'package:flutter/material.dart';
import 'package:heads_up/repositories/category_repository.dart';
import 'package:heads_up/deck_editor_screen.dart';

class DeckManagementScreen extends StatefulWidget {
  final Function(int) navigateToTab;
  final Function refreshHomeTab; // Added callback to refresh home tab
  
  const DeckManagementScreen({
    Key? key, 
    required this.navigateToTab,
    required this.refreshHomeTab,
  }) : super(key: key);

  @override
  _DeckManagementScreenState createState() => _DeckManagementScreenState();
}

class _DeckManagementScreenState extends State<DeckManagementScreen> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  List<Map<String, dynamic>> _decks = [];
  bool _isLoading = true;
  bool _isProcessing = false; // Added to track processing state

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _categoryRepository.getAllCategories();
      
      setState(() {
        _decks = categories.where((c) => c['name'] != 'All Categories').toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      setState(() {
        _isLoading = false;
        _decks = [];
      });
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading decks: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Process actions with loading state and error handling
  Future<void> _processAction({
    required String actionName,
    required Future<bool> Function() action,
    required String successMessage,
    required String errorMessage,
  }) async {
    if (_isProcessing) return; // Prevent multiple simultaneous actions
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final success = await action();
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Refresh both screens
        await _loadCategories();
        widget.refreshHomeTab();
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error during $actionName: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorMessage: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Decks'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Add refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isProcessing ? null : _loadCategories,
            tooltip: 'Refresh deck list',
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // New Deck button at the top
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.add_circle),
                        label: Text(
                          'Create New Deck',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isProcessing ? null : () {
                          widget.navigateToTab(2);
                        },
                      ),
                    ),
                    // Divider
                    Divider(height: 1, thickness: 1),
                    // Deck list
                    Expanded(
                      child: _decks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_off, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No decks found',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadCategories,
                              child: ListView.builder(
                                itemCount: _decks.length,
                                itemBuilder: (context, index) {
                                  final deck = _decks[index];
                                  return Dismissible(
                                    key: Key(deck['id'] ?? 'deck-$index'),
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
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('Delete Deck'),
                                          content: Text('Are you sure you want to delete the deck "${deck['name']}"? This cannot be undone.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _processAction(
                                        actionName: 'deck deletion',
                                        action: () => _categoryRepository.deleteDeck(deck['id']),
                                        successMessage: 'Deck "${deck['name']}" deleted successfully',
                                        errorMessage: 'Failed to delete deck "${deck['name']}"',
                                      );
                                      
                                      // Optimistically remove from the list
                                      setState(() {
                                        _decks.removeAt(index);
                                      });
                                    },
                                    child: Card(
                                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: ListTile(
                                        leading: Icon(
                                          deck['icon'],
                                          color: deck['isCustom'] == true ? Colors.purple.shade700 : Colors.blue.shade700,
                                          size: 32,
                                        ),
                                        title: Text(
                                          deck['name'],
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: deck['isCustom'] == true
                                            ? Text('Custom deck')
                                            : null,
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit, color: Colors.blue.shade700),
                                              onPressed: _isProcessing ? null : () {
                                                if (deck.containsKey('id')) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => DeckEditorScreen(
                                                        deckId: deck['id'],
                                                        deckName: deck['name'],
                                                        isNewDeck: false,
                                                        onSaveCallback: () {
                                                          // Refresh both screens when saving
                                                          _loadCategories();
                                                          widget.refreshHomeTab();
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Error: Deck ID not found'),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.delete, color: Colors.red),
                                              onPressed: _isProcessing ? null : () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: Text('Delete Deck'),
                                                    content: Text('Are you sure you want to delete the deck "${deck['name']}"? This cannot be undone.'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                        },
                                                        child: Text('Cancel'),
                                                      ),
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          foregroundColor: Colors.white,
                                                        ),
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                          
                                                          if (!deck.containsKey('id')) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text('Error: Deck ID not found'),
                                                                backgroundColor: Colors.red,
                                                              ),
                                                            );
                                                            return;
                                                          }
                                                          
                                                          // Optimistically remove from the list
                                                          setState(() {
                                                            _decks.remove(deck);
                                                          });
                                                          
                                                          _processAction(
                                                            actionName: 'deck deletion',
                                                            action: () => _categoryRepository.deleteDeck(deck['id']),
                                                            successMessage: 'Deck "${deck['name']}" deleted successfully',
                                                            errorMessage: 'Failed to delete deck "${deck['name']}"',
                                                          );
                                                        },
                                                        child: Text('Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
          // Overlay a loading indicator when processing
          if (_isProcessing)
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
                          'Processing...',
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
    );
  }
}