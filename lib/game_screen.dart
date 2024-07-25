import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_sensors/flutter_sensors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'categories.dart';
import 'results_screen.dart';
import 'package:vibration/vibration.dart';

class GameScreen extends StatefulWidget {
  final String deckName;

  const GameScreen({Key? key, required this.deckName}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<String> words;
  late List<bool> usedWords;
  late String currentWord;
  int score = 0;
  late Timer timer;
  int remainingTime = 15; // 60 seconds game time
  bool isGameStarted = false;

  StreamSubscription? _accelerometerSubscription;

  List<Color> _backgroundColors = [Colors.blue.shade700, Colors.blue.shade300];
  String _displayText = '';
  bool _isTriggered = false;

  List<String> correctWords = [];
  List<String> passedWords = [];

  double _dragStartX = 0.0;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    words = getWordsForDeck(widget.deckName);
    usedWords = List.filled(words.length, false);
    currentWord = getNextWord();
    _displayText = '3';
    startCountdown();
  }

  void startCountdown() {
    int count = 3;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _processCountdown(count, timer);
      count--;
    });
  }

  Future<void> _processCountdown(int count, Timer timer) async {
    if (count > 0) {
      setState(() {
        _displayText = count.toString();
      });

      // Play sound
      _playSound('countdown.mp3');

      // Delay haptic feedback slightly
      await Future.delayed(Duration(milliseconds: 150));
      Vibration.vibrate(duration: 100);
    } else if (count == 0) {
      setState(() {
        _displayText = 'GO!';
      });

      // Play 'GO!' sound
      _playSound('countdown.mp3');

      // Delay haptic feedback slightly
      await Future.delayed(Duration(milliseconds: 100));
      Vibration.vibrate(duration: 100);
    } else {
      timer.cancel();
      setState(() {
        isGameStarted = true;
        _displayText = currentWord;
      });
      startTimer();
      _startListeningToAccelerometer();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    timer.cancel();
    _accelerometerSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  List<String> getWordsForDeck(String deckName) {
    if (deckName == 'All Categories') {
      return Categories.categoryWords.values.expand((words) => words).toList();
    }
    return Categories.categoryWords[deckName] ?? [];
  }

  String getNextWord() {
    if (usedWords.every((used) => used)) return 'Game Over';
    final random = Random();
    int index;
    do {
      index = random.nextInt(words.length);
    } while (usedWords[index]);
    usedWords[index] = true;
    return words[index];
  }

void startTimer() {
  timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    setState(() {
      if (remainingTime > 0) {
        remainingTime--;
        if (remainingTime <= 10) {
          // Vibrate for each of the last 10 seconds
          // _playSound('tick.mp3');
          Vibration.vibrate(duration: (15 + (10-remainingTime)*10));
          // You can also play a sound here if you want
        }
      } else {
        endGame();
      }
    });
  });
}

  void _startListeningToAccelerometer() async {
    final stream = await SensorManager().sensorUpdates(
      sensorId: Sensors.ACCELEROMETER,
      interval: Sensors.SENSOR_DELAY_GAME,
    );
    _accelerometerSubscription = stream.listen((SensorEvent event) {
      if (event.data[2].abs() > 9 && !_isTriggered) {
        if (event.data[2] > 0) {
          onPass();
        } else {
          onCorrect();
        }
        _isTriggered = true;
      } else if (event.data[2].abs() < 3 && _isTriggered) {
        _resetToNeutral();
      }
    });
  }

  void onCorrect() {
    Vibration.vibrate(duration: 350);

    // HapticFeedback.heavyImpact();
    _playSound('correct.mp3');
    setState(() {
      score++;
      correctWords.add(currentWord);
      _backgroundColors = [Colors.green.shade700, Colors.green.shade300];
      _displayText = 'CORRECT!';
    });
  }

  void onPass() {
    Vibration.vibrate(duration: 175);
    // HapticFeedback.heavyImpact();
    // _playSound('pass.mp3');
    setState(() {
      passedWords.add(currentWord);
      _backgroundColors = [Colors.orange.shade700, Colors.orange.shade300];
      _displayText = 'PASS';
    });
  }

  void _resetToNeutral() {
    setState(() {
      _isTriggered = false;
      _backgroundColors = [Colors.blue.shade700, Colors.blue.shade300];
      currentWord = getNextWord();
      _displayText = currentWord;
    });
  }

  void endGame() {
    timer.cancel();
    _playSound('times_up.mp3');
    setState(() {
      _displayText = "Time's Up!";
    });
    Vibration.vibrate(duration: 500);

    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            score: score,
            deckName: widget.deckName,
            correctWords: correctWords,
            passedWords: passedWords,
          ),
        ),
      );
    });
  }

  Future<void> _playSound(String soundFile) async {
    await _audioPlayer.play(AssetSource(soundFile));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        if (isGameStarted) _dragStartX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        if (isGameStarted) {
          double dragDistance = (details.globalPosition.dx - _dragStartX).abs();
          double screenWidth = MediaQuery.of(context).size.width;

          if (dragDistance > screenWidth * 0.3) {
            endGame();
          }
        }
      },
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _backgroundColors,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isGameStarted)
                    Text(
                      'Time: $remainingTime',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 40),
                  Text(
                    _displayText,
                    style: const TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
