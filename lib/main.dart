import 'package:flutter/material.dart';
import 'package:guess_it/game_screen.dart';
import 'package:guess_it/settings_screen.dart';
import 'package:guess_it/repositories/category_repository.dart';
import 'package:guess_it/services/initialization_service.dart';
import 'package:guess_it/deck_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:guess_it/online_decks_screen.dart';
import 'package:guess_it/ai_deck_generator.dart';
import 'package:guess_it/utils/admin_mode_manager.dart';

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
      title: 'Guess It',
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
  bool _isAdminMode = false;
  final AdminModeManager _adminManager = AdminModeManager();
  
  @override
  void initState() {
    super.initState();
    _checkAdminMode();
  }
  
  Future<void> _checkAdminMode() async {
    final isAdmin = await _adminManager.isAdminModeEnabled();
    if (mounted) {
      setState(() {
        _isAdminMode = isAdmin;
        // Ensure current index is valid with the new navigation state
        if (!_isAdminMode && _currentIndex == 1) {
          _currentIndex = 0;  // Reset to home if manage decks was selected
        }
      });
    }
  }
  
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
  
  // Listener for admin mode changes
  void _onAdminModeChanged() {
    _checkAdminMode();
  }
  
  @override
  Widget build(BuildContext context) {
    // Define navigation items based on admin mode
    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.category),
        label: 'Play',
      ),
    ];
    
    // Add "Manage Decks" only in admin mode
    if (_isAdminMode) {
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.edit),
        label: 'Manage Decks',
      ));
    }
    
    // Add common items for all users
    navItems.addAll([
      const BottomNavigationBarItem(
        icon: Icon(Icons.cloud_download),
        label: 'Store',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ]);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home/Categories page with key for refreshing
          HomePage(
            key: _homePageKey,
            title: 'Guess It', 
            usedWords: widget.usedWords, 
            resetUsedWords: widget.resetUsedWords
          ),
          // Deck Management Screen (only accessible in admin mode)
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
            resetUsedWords: widget.resetUsedWords,
            onAdminModeChanged: _onAdminModeChanged,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getAdjustedIndex(),
        onTap: (index) {
          final actualIndex = _getActualIndexFromTap(index);
          setState(() {
            _currentIndex = actualIndex;
          });
          
          // Refresh home page when switching to it
          if (actualIndex == 0) {
            _refreshHomeTab();
          }
        },
        items: navItems,
        selectedItemColor: Colors.blue.shade700,
        type: BottomNavigationBarType.fixed, // Ensures all labels are visible
      ),
    );
  }
  
  // Get the adjusted index for the navigation bar
  int _getAdjustedIndex() {
    if (_currentIndex == 0) return 0; // Home tab
    
    if (_isAdminMode) {
      // In admin mode:
      // 0 = Home
      // 1 = Manage Decks
      // 2 = AI Deck Generator (hidden)
      // 3 = Store
      // 4 = Settings
      if (_currentIndex == 1) return 1; // Manage decks
      if (_currentIndex == 3) return 2; // Store
      if (_currentIndex == 4) return 3; // Settings
      return 0; // Default to home for any other case (including hidden AI tab)
    } else {
      // In non-admin mode:
      // 0 = Home
      // 1 = Manage Decks (not accessible)
      // 2 = AI Deck Generator (hidden)
      // 3 = Store
      // 4 = Settings
      if (_currentIndex == 3) return 1; // Store (2nd position without admin tab)
      if (_currentIndex == 4) return 2; // Settings (3rd position without admin tab)
      return 0; // Default to home
    }
  }
  
  // Convert tapped index to actual content index
  int _getActualIndexFromTap(int tappedIndex) {
    if (_isAdminMode) {
      // In admin mode:
      switch (tappedIndex) {
        case 0: return 0; // Home
        case 1: return 1; // Manage Decks
        case 2: return 3; // Store (skip AI generator)
        case 3: return 4; // Settings
        default: return 0;
      }
    } else {
      // In non-admin mode (no Manage Decks tab):
      switch (tappedIndex) {
        case 0: return 0; // Home
        case 1: return 3; // Store (skip Manage Decks & AI generator)
        case 2: return 4; // Settings
        default: return 0;
      }
    }
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
// Replace the SimpleDeckCard class in main.dart with this fixed version
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
              Icon(icon, size: 48, color: isCustomDeck ? Colors.purple.shade700 : Colors.blue.shade700), // Reduced from 48 to 40
              const SizedBox(height: 6), // Reduced from 8 to 6
              Flexible( // Wrap the text in Flexible
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16, // Reduced from 18 to 16
                    fontWeight: FontWeight.bold,
                    color: isCustomDeck ? Colors.purple.shade700 : Colors.blue.shade700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2, // Allow up to 2 lines
                  overflow: TextOverflow.ellipsis, // Add ellipsis if text is too long
                ),
              ),
              if (isCustomDeck)
                Flexible( // Wrap the custom text in Flexible too
                  child: Text(
                    '(Custom)',
                    style: TextStyle(
                      fontSize: 10, // Reduced from 12 to 10
                      color: Colors.purple.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

extension HomePageStateExtension on _HomePageState {
  Future<void> loadCategories() async {
    return _loadCategories();
  }
}