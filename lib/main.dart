import 'package:flutter/material.dart';
import 'package:heads_up/game_screen.dart';
import 'package:heads_up/settings_screen.dart';
import 'package:heads_up/repositories/category_repository.dart';
import 'package:heads_up/services/initialization_service.dart';
import 'package:heads_up/deck_editor_screen.dart';
import 'package:heads_up/deck_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:heads_up/online_decks_screen.dart';
import 'package:heads_up/ai_deck_generator.dart';
import 'package:heads_up/utils/admin_mode_manager.dart';
import 'package:heads_up/admin_auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize our app's services
  final initService = InitializationService();
  await initService.initialize();
  
  // Get shared preferences instance
  await SharedPreferences.getInstance();
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<String> usedWords = [];

  void resetUsedWords() {
    setState(() {
      usedWords.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heads Up',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MainTabScreen(usedWords: usedWords, resetUsedWords: resetUsedWords),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  final List<String> usedWords;
  final VoidCallback resetUsedWords;
  
  const MainTabScreen({
    Key? key, 
    required this.usedWords, 
    required this.resetUsedWords
  }) : super(key: key);

  @override
  _MainTabScreenState createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  // Key to force homepage refresh when returning from custom deck creator
  final GlobalKey<_HomePageState> _homePageKey = GlobalKey<_HomePageState>();
  
  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  
  // Method to explicitly refresh the home page
  void _refreshHomeTab() {
    if (_homePageKey.currentState != null) {
      _homePageKey.currentState?.loadCategories();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home/Categories page with key for refreshing
          HomePage(
            key: _homePageKey,
            title: 'Heads Up', 
            usedWords: widget.usedWords, 
            resetUsedWords: widget.resetUsedWords
          ),
          // Deck Management Screen with refresh callback
          DeckManagementScreen(
            navigateToTab: _navigateToTab,
            refreshHomeTab: _refreshHomeTab,
          ),
          // AI Deck Generator (hidden from bottom tabs)
          AIDeckGenerator(),
          // Online Decks Screen with refresh callback
          OnlineDecksScreen(
            refreshHomeTab: _refreshHomeTab,
          ),
          // Settings page
          SettingsScreen(
            usedWords: widget.usedWords, 
            resetUsedWords: widget.resetUsedWords
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex < 2 ? _currentIndex : _currentIndex - 1, // Adjust for hidden tab
        onTap: (index) {
          // Adjust the index for the hidden tab
          final actualIndex = index >= 2 ? index + 1 : index;
          setState(() {
            _currentIndex = actualIndex;
          });
          
          // Refresh home page when switching to it
          if (actualIndex == 0) {
            _refreshHomeTab();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Play',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Manage Decks',
          ),
          // Create Deck tab is hidden from bottom navigation
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_download),
            label: 'Store',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        selectedItemColor: Colors.blue.shade700,
        type: BottomNavigationBarType.fixed, // Ensures all labels are visible
      ),
    );
  }
}
class HomePage extends StatefulWidget {
  final String title;
  final List<String> usedWords;
  final VoidCallback resetUsedWords;

  const HomePage({
    Key? key, 
    required this.title, 
    required this.usedWords, 
    required this.resetUsedWords
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CategoryRepository _categoryRepository = CategoryRepository();
  List<Map<String, dynamic>> _decks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final categories = await _categoryRepository.getAllCategories();
      
      if (mounted) {
        setState(() {
          _decks = [
            {'name': 'All Categories', 'icon': Icons.category, 'id': 'all_categories', 'isCustom': false},
            ...categories.map((category) => {
              ...category,
              'isCustom': category.containsKey('isCustom') ? category['isCustom'] : false,
            }).toList(),
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _decks = [{'name': 'All Categories', 'icon': Icons.category, 'id': 'all_categories', 'isCustom': false}]; // Fallback
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        // Removed sync and refresh buttons
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.blue.shade100],
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadCategories,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _decks.length,
                  itemBuilder: (context, index) {
                    return SimpleDeckCard(
                      name: _decks[index]['name'],
                      icon: _decks[index]['icon'],
                      usedWords: widget.usedWords,
                      isCustomDeck: _decks[index]['isCustom'] ?? false,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

// Simplified deck card with only game launch functionality
class SimpleDeckCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final List<String> usedWords;
  final bool isCustomDeck;

  const SimpleDeckCard({
    Key? key,
    required this.name,
    required this.icon,
    required this.usedWords,
    this.isCustomDeck = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCustomDeck ? Colors.purple.shade300 : Colors.transparent,
          width: isCustomDeck ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(deckName: name, usedWords: usedWords),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: isCustomDeck ? Colors.purple.shade700 : Colors.blue.shade700),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCustomDeck ? Colors.purple.shade700 : Colors.blue.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              if (isCustomDeck)
                Text(
                  '(Custom)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple.shade500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
class DeckCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final List<String> usedWords;
  final bool isCustomDeck;
  final String deckId;
  final VoidCallback onRefresh;

  const DeckCard({
    Key? key,
    required this.name,
    required this.icon,
    required this.usedWords,
    required this.deckId,
    this.isCustomDeck = false,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final CategoryRepository _categoryRepository = CategoryRepository();

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCustomDeck ? Colors.purple.shade300 : Colors.transparent,
          width: isCustomDeck ? 2 : 0,
        ),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameScreen(deckName: name, usedWords: usedWords),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 48, color: isCustomDeck ? Colors.purple.shade700 : Colors.blue.shade700),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCustomDeck ? Colors.purple.shade700 : Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isCustomDeck)
                    Text(
                      '(Custom)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple.shade500,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isCustomDeck || name != 'All Categories')
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
                onSelected: (value) async {
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeckEditorScreen(
                          deckId: deckId,
                          deckName: name,
                          isNewDeck: false,
                        ),
                      ),
                    ).then((_) {
                      // Refresh the deck list when returning
                      onRefresh();
                    });
                  } else if (value == 'delete') {
                    // Confirm before deleting
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Delete Deck'),
                        content: Text('Are you sure you want to delete the deck "$name"? This cannot be undone.'),
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
                            onPressed: () async {
                              Navigator.pop(context);
                              // Delete the deck
                              await _categoryRepository.deleteDeck(deckId);
                              onRefresh();
                            },
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  if (name != 'All Categories')
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue.shade700),
                          SizedBox(width: 8),
                          Text('Edit Deck'),
                        ],
                      ),
                    ),
                  if (name != 'All Categories')
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Deck'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension HomePageStateExtension on _HomePageState {
  Future<void> loadCategories() async {
    return _loadCategories();
  }
}