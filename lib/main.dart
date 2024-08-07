import 'package:flutter/material.dart';
import 'package:heads_up/game_screen.dart';
import 'package:heads_up/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: HomePage(title: 'Heads Up', usedWords: usedWords, resetUsedWords: resetUsedWords),
    );
  }
}

class HomePage extends StatelessWidget {
  final String title;
  final List<String> usedWords;
  final VoidCallback resetUsedWords;

  const HomePage({Key? key, required this.title, required this.usedWords, required this.resetUsedWords}) : super(key: key);

  final List<Deck> decks = const [
    Deck('All Categories', Icons.category),
    Deck('Animals', Icons.pets),
    Deck('Movies', Icons.movie),
    Deck('Food', Icons.restaurant),
    Deck('Sports', Icons.sports_soccer),
    Deck('Music', Icons.music_note),
    Deck('Countries', Icons.public),
    Deck('Celebrities', Icons.star),
    Deck('Professions', Icons.work),
    Deck('Science', Icons.science),
    Deck('Literature', Icons.book),
    Deck('History', Icons.history),
    Deck('Art', Icons.palette),
    Deck('TV Shows', Icons.tv),
    Deck('Brands', Icons.branding_watermark),
    Deck('Mythology', Icons.auto_stories),
    Deck('Video Games', Icons.gamepad),
    Deck('Nature', Icons.nature),
    Deck('Fashion', Icons.shopping_bag),
    Deck('Inventions', Icons.lightbulb),
    Deck('Disney', FontAwesomeIcons.crown),
    Deck('Olympic Sports', Icons.sports_gymnastics),
    Deck('Board Games', Icons.casino),
    Deck('Lord of the Rings', FontAwesomeIcons.ring),
    Deck('Chess', FontAwesomeIcons.chessKnight),
    Deck('Harry Potter', FontAwesomeIcons.wandSparkles),
    Deck('Bible', FontAwesomeIcons.bookBible),
    Deck('Cornerstone', Icons.church),
    Deck('Act It Out', Icons.theater_comedy),
    Deck('Impressions', Icons.face),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen(usedWords: usedWords, resetUsedWords: resetUsedWords)),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade300, Colors.blue.shade100],
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: decks.length,
          itemBuilder: (context, index) {
            return DeckCard(deck: decks[index], usedWords: usedWords);
          },
        ),
      ),
    );
  }
}

class Deck {
  final String name;
  final IconData icon;

  const Deck(this.name, this.icon);
}

class DeckCard extends StatelessWidget {
  final Deck deck;
  final List<String> usedWords;

  const DeckCard({Key? key, required this.deck, required this.usedWords}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameScreen(deckName: deck.name, usedWords: usedWords),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(deck.icon, size: 48, color: Colors.blue.shade700),
            const SizedBox(height: 8),
            Text(
              deck.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}