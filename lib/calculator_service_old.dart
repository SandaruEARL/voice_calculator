// calculator_service_improved.dart - Enhanced decimal multiplier handling
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class CalculatorService {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // State variables
  String _lastWords = '';
  String _result = '';
  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isTtsSpeaking = false;
  double _soundLevel = 0.0;
  bool _soundDetected = false;
  bool _waitingForNewInput = false;

  // Stream controllers
  final StreamController<CalculatorState> _stateController = StreamController<CalculatorState>.broadcast();
  final StreamController<double> _soundLevelController = StreamController<double>.broadcast();

  // Comprehensive number mappings
  static const Map<String, int> _basicNumbers = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
    'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50,
    'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90
  };

  static const Map<String, int> _multipliers = {
    'hundred': 100,
    'thousand': 1000,
    'million': 1000000,
    'billion': 1000000000,
    'trillion': 1000000000000,
  };

  // Fraction mappings
  static const Map<String, double> _fractions = {
    'half': 0.5,
    'quarter': 0.25,
    'third': 0.333333,
    'two thirds': 0.666667,
    'three quarters': 0.75,
    'one half': 0.5,
    'one quarter': 0.25,
    'one third': 0.333333,
    'one and a half': 1.5,
    'two and a half': 2.5,
    'three and a half': 3.5,
    'four and a half': 4.5,
    'five and a half': 5.5,
    'six and a half': 6.5,
    'seven and a half': 7.5,
    'eight and a half': 8.5,
    'nine and a half': 9.5,
    'ten and a half': 10.5,
  };

  // Ordinal numbers
  static const Map<String, int> _ordinals = {

    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5,
    'sixth': 6, 'seventh': 7, 'eighth': 8, 'ninth': 9, 'tenth': 10,
    'eleventh': 11, 'twelfth': 12, 'thirteenth': 13, 'fourteenth': 14, 'fifteenth': 15,
    'sixteenth': 16, 'seventeenth': 17, 'eighteenth': 18, 'nineteenth': 19, 'twentieth': 20,

  };

  // Getters for streams
  Stream<CalculatorState> get stateStream => _stateController.stream;
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  // Getters for current state
  bool get isListening => _isListening;
  bool get isSpeaking => _isTtsSpeaking;
  bool get speechEnabled => _speechEnabled;
  String get lastWords => _lastWords;
  String get result => _result;
  double get soundLevel => _soundLevel;
  bool get soundDetected => _soundDetected;

  Future<void> initialize() async {
    await _initSpeech();
    await _initTts();
    _updateState();
  }

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.status;

    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _speechEnabled = false;
        return;
      }
    }

    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (errorNotification) {
          _isListening = false;
          _soundLevel = 0.0;
          _soundDetected = false;

          _lastWords = 'Error: ${errorNotification.errorMsg}';
          _updateState();

          Future.delayed(Duration(seconds: 2), () {
            if (!_isListening && !_isTtsSpeaking) {
              _lastWords = 'Touch screen to start listening';
              _updateState();
            }
          });
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'notListening' && _isListening) {
            _isListening = false;
            _soundLevel = 0.0;
            _soundDetected = false;
            _updateState();
          }
        },
      );
    } catch (e) {
      print('Speech initialization error: $e');
      _speechEnabled = false;
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.7);
    await _flutterTts.setVolume(0.8);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      _isTtsSpeaking = false;
      _updateState();

      if (_waitingForNewInput) {
        _waitingForNewInput = false;
        Future.delayed(Duration(milliseconds: 2000), () {
          _prepareForNewInput();
        });
      }
    });

    _flutterTts.setStartHandler(() {
      _isTtsSpeaking = true;
      _updateState();
    });
  }

  void _prepareForNewInput() {
    _lastWords = 'Touch screen to start listening';
    _result = '';
    _updateState();
  }

  Future<void> startListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) {
        _lastWords = 'Microphone permission required';
        _updateState();
        return;
      }
    }

    if (_isTtsSpeaking) {
      await _flutterTts.stop();
      await Future.delayed(Duration(milliseconds: 500));
    }

    try {
      _soundLevel = 0.0;
      _soundDetected = false;
      _lastWords = 'Listening...';
      _result = '';
      _isListening = true;
      _updateState();

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: Duration(minutes: 2),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        onSoundLevelChange: (level) {
          _soundLevel = level;
          _soundDetected = level > 0.15;
          _soundLevelController.add(level);
          _updateState();
        },
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
        localeId: "en_US",
      );

      if (!_speechToText.isListening) {
        _isListening = false;
        _lastWords = 'Failed to start listening. Touch to try again.';
        _updateState();
      }
    } catch (e) {
      print('Error starting listening: $e');
      _isListening = false;
      _lastWords = 'Touch screen to start listening';
      _updateState();
    }
  }

  Future<void> stopListening() async {
    if (_isListening && _speechToText.isListening) {
      await _speechToText.stop();
      await Future.delayed(Duration(milliseconds: 300));
    }

    _isListening = false;
    _soundLevel = 0.0;
    _soundDetected = false;

    if (!_isTtsSpeaking && _result.isEmpty) {
      _lastWords = 'Touch screen to start listening';
    }

    _updateState();
  }

  void _onSpeechResult(result) {
    String words = result.recognizedWords ?? '';
    bool isFinal = result.finalResult;

    if (words.isNotEmpty) {
      _lastWords = words;
      _updateState();
    }

    if (isFinal) {
      _isListening = false;
      _soundLevel = 0.0;
      _soundDetected = false;
      _updateState();

      if (words.isNotEmpty) {
        _calculateResult(words);
      } else {
        _lastWords = 'No speech detected. Touch screen to try again.';
        _updateState();
      }
    }
  }

  void _calculateResult(String expression) {
    try {
      String mathExpression = _convertWordsToMath(expression.toLowerCase());

      if (mathExpression.isNotEmpty && RegExp(r'[\d.]').hasMatch(mathExpression)) {
        double result = _evaluateExpression(mathExpression);
        _result = _formatResult(result);
        _updateState();

        _waitingForNewInput = true;

        Future.delayed(Duration(milliseconds: 1500), () {
          speakResult();
        });
      } else {
        _result = 'No numbers detected';
        _updateState();
        _speakWithCallback("I didn't hear any numbers. Please try again.");
        _waitingForNewInput = true;
      }
    } catch (e) {
      print('Calculation error: $e');
      _result = 'Error in calculation';
      _updateState();
      _speakWithCallback("There was an error. Please try again.");
      _waitingForNewInput = true;
    }
  }

  Future<void> _speakWithCallback(String message) async {
    _isTtsSpeaking = true;
    _updateState();
    await _flutterTts.speak(message);
  }

  Future<void> speakResult() async {
    if (_result.isNotEmpty &&
        _result != 'Could not understand' &&
        _result != 'Error in calculation' &&
        _result != 'No numbers detected') {
      String spokenResult = _result;
      if (_result.contains('.') && _result.endsWith('.0')) {
        spokenResult = _result.replaceAll('.0', '');
      }
      _speakWithCallback("The answer is $spokenResult");
    } else if (_result.isNotEmpty) {
      _speakWithCallback(_result);
    }
  }

  String _formatResult(double result) {
    if (result == result.roundToDouble()) {
      return result.round().toString();
    }

    String formatted = result.toStringAsFixed(8);
    formatted = formatted.replaceAll(RegExp(r'0*$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    return formatted;
  }

  String _convertWordsToMath(String words) {
    String mathExpression = words.toLowerCase().trim();

    // Pre-process common phrases and handle decimal multipliers
    mathExpression = _preprocessPhrases(mathExpression);

    // Replace operation words
    mathExpression = mathExpression
        .replaceAll(RegExp(r'\bplus\b|\badd\b|\baddition\b|\band\b'), ' + ')
        .replaceAll(RegExp(r'\bminus\b|\bsubtract\b|\btake away\b'), ' - ')
        .replaceAll(RegExp(r'\btimes\b|\bmultiply\b|\bmultiplied by\b|\binto\b'), ' * ')
        .replaceAll(RegExp(r'\bdivide\b|\bdivided by\b|\bover\b'), ' / ')
        .replaceAll('x', ' * ')
        .replaceAll('÷', ' / ');

    // Convert number words to digits
    mathExpression = _convertNumberWords(mathExpression);

    // Clean up
    mathExpression = mathExpression.replaceAll(RegExp(r'\s+'), ' ').trim();
    mathExpression = mathExpression.replaceAll(RegExp(r'[^0-9+\-*/().\s]'), '');
    mathExpression = mathExpression.replaceAll(RegExp(r'\s+'), '');

    return mathExpression;
  }

  String _preprocessPhrases(String text) {
    // Handle point multiplier combinations first (before general point handling)
    text = _handleDecimalMultipliers(text);

    // Handle negative numbers
    text = text.replaceAll(RegExp(r'\bnegative\b'), '-');

    // Handle "and" in compound numbers (e.g., "one hundred and five")
    text = text.replaceAll(RegExp(r'\band\b(?=\s+(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety))'), '');

    return text;
  }

  String _handleDecimalMultipliers(String text) {
    // Handle patterns like "one point five million", "two point three billion", etc.
    // Pattern: (number word) point (number word) (multiplier)
    RegExp decimalMultiplierPattern = RegExp(
        r'\b(\w+)\s+point\s+(\w+)\s+(million|billion|trillion)\b',
        caseSensitive: false
    );

    text = text.replaceAllMapped(decimalMultiplierPattern, (match) {
      String wholePart = match.group(1)!.toLowerCase();
      String decimalPart = match.group(2)!.toLowerCase();
      String multiplier = match.group(3)!.toLowerCase();

      // Convert word numbers to digits
      int? wholeNumber = _basicNumbers[wholePart];
      int? decimalNumber = _basicNumbers[decimalPart];

      if (wholeNumber != null && decimalNumber != null) {
        // Create decimal number string
        String decimalString = '$wholeNumber.$decimalNumber';
        return '$decimalString $multiplier';
      }

      // If conversion fails, return original
      return match.group(0)!;
    });

    // Handle "point" followed by multiplier (e.g., "point five million" = "0.5 million")
    RegExp pointMultiplierPattern = RegExp(
        r'\bpoint\s+(\w+)\s+(million|billion|trillion)\b',
        caseSensitive: false
    );

    text = text.replaceAllMapped(pointMultiplierPattern, (match) {
      String decimalPart = match.group(1)!.toLowerCase();
      String multiplier = match.group(2)!.toLowerCase();

      int? decimalNumber = _basicNumbers[decimalPart];
      if (decimalNumber != null) {
        return '0.$decimalNumber $multiplier';
      }

      // If conversion fails, return original
      return match.group(0)!;
    });

    // Handle regular "point" for decimal places (not followed by multipliers)
    text = text.replaceAll(RegExp(r'\bpoint\b(?!\s+(?:million|billion|trillion))'), '.');

    return text;
  }

  String _convertNumberWords(String text) {
    // First, handle fractions
    for (String fraction in _fractions.keys) {
      if (text.contains(fraction)) {
        text = text.replaceAll(fraction, _fractions[fraction].toString());
      }
    }

    // Handle ordinals
    for (String ordinal in _ordinals.keys) {
      if (text.contains(ordinal)) {
        text = text.replaceAll(ordinal, _ordinals[ordinal].toString());
      }
    }

    // Split by operators to handle each number segment
    List<String> parts = text.split(RegExp(r'(\s*[+\-*/]\s*)'));
    List<String> operators = [];

    // Extract operators
    RegExp operatorRegex = RegExp(r'\s*([+\-*/])\s*');
    Iterable<Match> matches = operatorRegex.allMatches(text);
    for (Match match in matches) {
      operators.add(match.group(1)!);
    }

    // Convert each number part
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].trim().isNotEmpty && !RegExp(r'^[+\-*/]$').hasMatch(parts[i].trim())) {
        double? number = _parseComplexNumber(parts[i].trim());
        if (number != null) {
          parts[i] = number.toString();
        }
      }
    }

    // Reconstruct expression
    String result = parts[0];
    for (int i = 0; i < operators.length && i + 1 < parts.length; i++) {
      result += operators[i] + parts[i + 1];
    }

    return result;
  }

  double? _parseComplexNumber(String numberText) {
    if (numberText.trim().isEmpty) return null;

    // Check if already a number
    double? directParse = double.tryParse(numberText.trim());
    if (directParse != null) return directParse;

    // Handle decimal numbers with multipliers (e.g., "1.5 million", "2.3 billion")
    RegExp decimalWithMultiplier = RegExp(r'^(\d+\.?\d*)\s+(million|billion|trillion)$');
    Match? decimalMatch = decimalWithMultiplier.firstMatch(numberText.toLowerCase());

    if (decimalMatch != null) {
      double baseNumber = double.parse(decimalMatch.group(1)!);
      String multiplierWord = decimalMatch.group(2)!;
      int multiplier = _multipliers[multiplierWord] ?? 1;
      return baseNumber * multiplier;
    }

    // Handle cases like "two point five million" that were already converted to "2.5 million"
    if (numberText.contains('.')) {
      List<String> parts = numberText.split('.');
      if (parts.length == 2) {
        // Check if the second part contains a multiplier
        String secondPart = parts[1];
        String? multiplierFound;
        int multiplierValue = 1;

        for (String multiplier in _multipliers.keys) {
          if (secondPart.contains(multiplier)) {
            multiplierFound = multiplier;
            multiplierValue = _multipliers[multiplier]!;
            secondPart = secondPart.replaceAll(multiplier, '').trim();
            break;
          }
        }

        // Parse the decimal number
        double? wholePart = _parseNumberWords(parts[0]) ?? double.tryParse(parts[0]);
        double? decimalPart = _parseNumberWords(secondPart) ?? double.tryParse(secondPart);

        if (wholePart != null && decimalPart != null) {
          // Create the decimal number
          String decimalString = decimalPart.toString();
          double combined = double.parse('${wholePart.round()}.$decimalString');
          return combined * multiplierValue;
        }
      }
    }

    return _parseNumberWords(numberText);
  }

  double? _parseNumberWords(String numberText) {
    if (numberText.trim().isEmpty) return null;

    // Check if already a number
    double? directParse = double.tryParse(numberText.trim());
    if (directParse != null) return directParse;

    List<String> words = numberText.toLowerCase().split(RegExp(r'\s+'));
    words = words.where((word) => word.isNotEmpty).toList();

    if (words.isEmpty) return null;

    double total = 0;
    double current = 0;

    for (int i = 0; i < words.length; i++) {
      String word = words[i];

      // Handle basic numbers
      if (_basicNumbers.containsKey(word)) {
        current += _basicNumbers[word]!;
      }
      // Handle multipliers
      else if (_multipliers.containsKey(word)) {
        int multiplier = _multipliers[word]!;

        if (word == 'hundred') {
          if (current == 0) current = 1;
          current *= multiplier;
        } else {
          // For million/billion/trillion
          if (current == 0) current = 1;
          current *= multiplier;
          total += current;  // Add to total
          current = 0;       // Reset current
        }
      }
      // Handle compound numbers with hyphens
      else if (word.contains('-')) {
        List<String> parts = word.split('-');
        double compoundValue = 0;
        for (String part in parts) {
          if (_basicNumbers.containsKey(part)) {
            compoundValue += _basicNumbers[part]!;
          }
        }
        if (compoundValue > 0) {
          current += compoundValue;
        }
      }
    }

    // Add any remaining current value
    total += current;

    return total > 0 ? total : null;
  }

  double _evaluateExpression(String expression) {
    if (expression.isEmpty) {
      throw Exception('Empty expression');
    }

    try {
      expression = expression.replaceAll(' ', '');

      if (!RegExp(r'^[0-9+\-*/().]+$').hasMatch(expression)) {
        throw Exception('Invalid characters in: $expression');
      }

      // If it's just a number, return it
      if (RegExp(r'^\d+(\.\d+)?$').hasMatch(expression)) {
        return double.parse(expression);
      }

      // Simple order of operations: multiplication and division first
      while (expression.contains('*') || expression.contains('/')) {
        RegExp multiplyDivide = RegExp(r'(\d+(?:\.\d+)?)\s*([*/])\s*(\d+(?:\.\d+)?)');
        Match? match = multiplyDivide.firstMatch(expression);

        if (match != null) {
          double num1 = double.parse(match.group(1)!);
          String operator = match.group(2)!;
          double num2 = double.parse(match.group(3)!);

          if (operator == '/' && num2 == 0) {
            throw Exception('Division by zero');
          }

          double result = operator == '*' ? num1 * num2 : num1 / num2;
          expression = expression.replaceFirst(match.group(0)!, result.toString());
        } else {
          break;
        }
      }

      // Then addition and subtraction
      while (expression.contains('+') || expression.contains('-')) {
        // Handle negative numbers at start
        if (expression.startsWith('-')) {
          RegExp negativeStart = RegExp(r'^-(\d+(?:\.\d+)?)\s*([+-])\s*(\d+(?:\.\d+)?)');
          Match? match = negativeStart.firstMatch(expression);

          if (match != null) {
            double num1 = -double.parse(match.group(1)!);
            String operator = match.group(2)!;
            double num2 = double.parse(match.group(3)!);

            double result = operator == '+' ? num1 + num2 : num1 - num2;
            expression = expression.replaceFirst(match.group(0)!, result.toString());
            continue;
          }
        }

        RegExp addSubtract = RegExp(r'(\d+(?:\.\d+)?)\s*([+-])\s*(\d+(?:\.\d+)?)');
        Match? match = addSubtract.firstMatch(expression);

        if (match != null) {
          double num1 = double.parse(match.group(1)!);
          String operator = match.group(2)!;
          double num2 = double.parse(match.group(3)!);

          double result = operator == '+' ? num1 + num2 : num1 - num2;
          expression = expression.replaceFirst(match.group(0)!, result.toString());
        } else {
          break;
        }
      }

      return double.parse(expression);
    } catch (e) {
      print('Evaluation error: $e');
      throw Exception('Failed to evaluate: $expression');
    }
  }

  void _updateState() {
    _stateController.add(CalculatorState(
      isListening: _isListening,
      isSpeaking: _isTtsSpeaking,
      lastWords: _lastWords,
      result: _result,
      speechEnabled: _speechEnabled,
      soundLevel: _soundLevel,
      soundDetected: _soundDetected,
    ));
  }

  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _stateController.close();
    _soundLevelController.close();
  }
}

class CalculatorState {
  final bool isListening;
  final bool isSpeaking;
  final String lastWords;
  final String result;
  final bool speechEnabled;
  final double soundLevel;
  final bool soundDetected;

  CalculatorState({
    required this.isListening,
    required this.isSpeaking,
    required this.lastWords,
    required this.result,
    required this.speechEnabled,
    required this.soundLevel,
    required this.soundDetected,
  });
}