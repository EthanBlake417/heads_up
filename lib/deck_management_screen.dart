// deck_management_screen.dart
import 'package:flutter/material.dart';
import 'package:guess_it/services/firebase_service.dart';
import 'package:guess_it/deck_editor_screen.dart';
import 'package:guess_it/models/category_model.dart';
import 'package:guess_it/utils/icon_mapping.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
  final FirebaseService _firebaseService = FirebaseService();
  List<CategoryModel> _firebaseDecks = [];
  bool _isLoading = true;
  bool _isProcessing = false; // Added to track processing state

  @override
  void initState() {
    super.initState();
    _loadFirebaseCategories();
  }

  Future<void> _loadFirebaseCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get categories directly from Firebase instead of local database
      final categories = await _firebaseService.getCategories();
      
      setState(() {
        _firebaseDecks = categories;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading Firebase categories: $e');
      setState(() {
        _isLoading = false;
        _firebaseDecks = [];
      });
      
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading decks from Firebase: ${e.toString()}'),
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
        await _loadFirebaseCategories();
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
        title: Text('Firebase Deck Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Add refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isProcessing ? null : _loadFirebaseCategories,
            tooltip: 'Refresh deck list from Firebase',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple.shade200, Colors.blue.shade100],
              ),
            ),
            child: _isLoading
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
                            'Create New Firebase Deck',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isProcessing ? null : () {
                            widget.navigateToTab(2);
                          },
                        ),
                      ),
                      // Firebase label
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.cloud, color: Colors.blue.shade700),
                            SizedBox(width: 8),
                            Text(
                              'Firebase Decks',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider
                      Divider(height: 1, thickness: 1),
                      // Deck list
                      Expanded(
                        child: _firebaseDecks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No decks found on Firebase',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadFirebaseCategories,
                                child: ListView.builder(
                                  itemCount: _firebaseDecks.length,
                                  itemBuilder: (context, index) {
                                    final deck = _firebaseDecks[index];
                                    final IconData iconData = IconMapping.getIconFromKey(deck.icon);
                                    
                                    return Dismissible(
                                      key: Key(deck.id),
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
                                            title: Text('Delete Deck from Firebase'),
                                            content: Text('Are you sure you want to delete the deck "${deck.name}" from Firebase? This will remove it for all users and cannot be undone.'),
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
                                          actionName: 'deck deletion from Firebase',
                                          action: () => _firebaseService.deleteCategoryFromFirebase(deck.id),
                                          successMessage: 'Deck "${deck.name}" deleted from Firebase successfully',
                                          errorMessage: 'Failed to delete deck "${deck.name}" from Firebase',
                                        );
                                        
                                        // Optimistically remove from the list
                                        setState(() {
                                          _firebaseDecks.removeAt(index);
                                        });
                                      },
                                      child: Card(
                                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: ListTile(
                                          leading: IconMapping.isFontAwesomeIcon(iconData)
                                            ? FaIcon(iconData, color: Colors.blue.shade700, size: 32)
                                            : Icon(iconData, color: Colors.blue.shade700, size: 32),
                                          title: Text(
                                            deck.name,
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Text(
                                            'Last updated: ${_formatDate(deck.lastUpdated)}',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(Icons.edit, color: Colors.blue.shade700),
                                                onPressed: _isProcessing ? null : () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => DeckEditorScreen(
                                                        deckId: deck.id,
                                                        deckName: deck.name,
                                                        isNewDeck: false,
                                                        onSaveCallback: () {
                                                          // Refresh both screens when saving
                                                          _loadFirebaseCategories();
                                                          widget.refreshHomeTab();
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete, color: Colors.red),
                                                onPressed: _isProcessing ? null : () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: Text('Delete Deck from Firebase'),
                                                      content: Text('Are you sure you want to delete the deck "${deck.name}" from Firebase? This will remove it for all users and cannot be undone.'),
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
                                                            
                                                            // Optimistically remove from the list
                                                            setState(() {
                                                              _firebaseDecks.remove(deck);
                                                            });
                                                            
                                                            _processAction(
                                                              actionName: 'deck deletion from Firebase',
                                                              action: () => _firebaseService.deleteCategoryFromFirebase(deck.id),
                                                              successMessage: 'Deck "${deck.name}" deleted from Firebase successfully',
                                                              errorMessage: 'Failed to delete deck "${deck.name}" from Firebase',
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
  
  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}