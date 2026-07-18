import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'api_service.dart';
import 'voice_manager.dart';

class VoiceAssistantService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final ApiService _apiService = ApiService();
  final VoiceManager _voiceManager = VoiceManager.instance;

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  String _lastWords = '';
  String _currentLang = 'en';
  Timer? _speechTimeout;

  final List<String> _interruptKeywords = [
    'stop',
    'wait',
    'appa',
    'अप्पा', // Hindi/Marathi Appa
    'आप्पा', // Marathi variant
    'ruko',
    'रुको', // Hindi stop
    'thamba',
    'थांबा', // Marathi wait
    'bas',
    'बस', // Hindi enough
    'enough'
  ];

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isProcessing => _isProcessing;
  String get lastWords => _lastWords;

  VoiceAssistantService() {
    _initVoiceManager();
  }

  Future<void> _initVoiceManager() async {
    _voiceManager.onStart = () {
      debugPrint('[Voice Assistant] TTS Started - Showing BLUE speaking animation');
      _isSpeaking = true;
      notifyListeners();
    };

    _voiceManager.onComplete = () {
      debugPrint('[Voice Assistant] TTS Finished - Hiding animation');
      _isSpeaking = false;
      notifyListeners();
    };

    _voiceManager.onCancel = () {
      debugPrint('[Voice Assistant] TTS Cancelled');
      _isSpeaking = false;
      notifyListeners();
    };

    await _voiceManager.init();
  }

  Future<void> startListening(String lang) async {
    _currentLang = lang;
    
    var permStatus = await Permission.microphone.status;
    if (!permStatus.isGranted) {
      permStatus = await Permission.microphone.request();
      if (!permStatus.isGranted) {
        debugPrint('Microphone permission denied.');
        return;
      }
    }

    // Stop speaking if currently speaking
    if (_isSpeaking) {
      await _voiceManager.stop();
    }

    bool available = await _speech.initialize(
      onError: (errorNotification) {
        debugPrint('[Voice Assistant] Listener error: ${errorNotification.errorMsg}');
        _isListening = false;
        notifyListeners();
      },
      onStatus: (status) {
        debugPrint('[Voice Assistant] Status: $status');
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
          notifyListeners();
          
          if (!_isSpeaking && !_isProcessing && _lastWords.isNotEmpty) {
            _executeCommand(_lastWords);
          }
        }
      },
    );

    if (available) {
      if (_isListening || _isProcessing) return;

      try {
        await _speech.listen(
          onResult: (SpeechRecognitionResult result) => _handleSpeechResult(result),
          listenOptions: SpeechListenOptions(
            localeId: _currentLang == 'en'
                ? 'en_US'
                : (_currentLang == 'hi' ? 'hi_IN' : 'mr_IN'),
            listenFor: const Duration(seconds: 15),
            pauseFor: const Duration(seconds: 3), // Restored back to 3 seconds
            partialResults: true,
            cancelOnError: true,
          ),
        );
        _isListening = true;
        _lastWords = '';
        notifyListeners();
        debugPrint('[Voice Assistant] 🎤 Mic activated. Tap to talk started...');
      } catch (e) {
        debugPrint('[Voice Assistant] Listen failed: $e');
        _isListening = false;
      }
    }
  }

  void updateLanguage(String newLang) {
    if (_currentLang != newLang) {
      debugPrint('[Voice Assistant] Language changed to: $newLang');
      _currentLang = newLang;
      if (_isListening) {
        _speech.cancel();
        _isListening = false;
        notifyListeners();
      }
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.toLowerCase().trim();
    if (words.isEmpty) return;

    _lastWords = words;
    notifyListeners();

    if (_isSpeaking) {
      // Barge-in check (Immediate)
      bool containsInterrupt = _interruptKeywords.any((k) => words.contains(k));
      if (containsInterrupt) {
        debugPrint('[Barge-In] 🚨 Keyword Detected! Interrupting Appa...');
        _speechTimeout?.cancel();
        _voiceManager.stop();
        _isSpeaking = false;
        notifyListeners();

        String newCommand = words;
        for (final keyword in _interruptKeywords) {
          newCommand = newCommand.replaceAll(keyword, '').trim();
        }
        newCommand = newCommand.replaceAll(RegExp(r'[,\.!\?]+'), '').trim();

        if (newCommand.length > 2) {
          _speech.cancel();
          Future.delayed(const Duration(milliseconds: 300), () {
            _processCommand(newCommand, _currentLang);
          });
        }
      } else {
        debugPrint('[Barge-In] Ignored echo: "$words"');
      }
    } else {
      // Tap-to-talk logic: Execute immediately if it's the final result from Android
      if (result.finalResult) {
        _executeCommand(words);
      } else {
        // Debounce timer for when Android takes too long to send 'finalResult'
        _speechTimeout?.cancel();
        _speechTimeout = Timer(const Duration(milliseconds: 2000), () { // Restored back to 2000ms
          if (_lastWords.isNotEmpty) {
            _executeCommand(_lastWords);
          }
        });
      }
    }
  }

  void _executeCommand(String words) {
    _speechTimeout?.cancel();
    if (words.isEmpty || _isProcessing) return;

    debugPrint('[Voice Assistant] 🚨 Command executed: "$words"');
    
    _lastWords = '';
    _speech.cancel();
    _processCommand(words, _currentLang);
  }

  Future<void> _processCommand(String command, String lang) async {
    final cleanCommand = command.trim().toLowerCase().replaceAll(RegExp(r'[,\.!\?]+'), '');
    if (cleanCommand.isEmpty) return;

    // Local override for simple greetings
    final greetings = {'appa', 'hello appa', 'hi appa', 'hey appa', 'hello', 'hi', 'namaste', 'namaskar', 'अप्पा', 'आप्पा', 'नमस्ते', 'नमस्कार', 'हेल्लो अप्पा', 'हाय अप्पा', 'हाय'};
    if (greetings.contains(cleanCommand)) {
      debugPrint('[Voice Assistant] Intercepted local greeting!');
      _isListening = false;
      notifyListeners();
      
      String greetingText;
      if (lang == 'hi') {
        greetingText = 'नमस्कार, मैं अप्पा, चलो करें गप्पा!';
      } else if (lang == 'mr') {
        greetingText = 'नमस्कार, मी आहे आप्पा, चला मारू गप्पा!';
      } else {
        greetingText = 'Hello, I am Appa, let\'s have a chat!';
      }
      
      await _voiceManager.speak(greetingText, lang);
      await _saveToMemory(command, greetingText);
      return;
    }

    debugPrint('[Voice Assistant] Processing command with AI...');
    _isProcessing = true;
    _isListening = false;
    notifyListeners();

    try {
      final summary = await _apiService.getVoiceSummary(command, lang: lang);
      
      if (summary.isNotEmpty) {
        // Switch states directly to prevent the UI from flickering back to the green button
        _isSpeaking = true; 
        _isProcessing = false;
        notifyListeners();

        await _voiceManager.speak(summary, lang);
        await _saveToMemory(command, summary);
      } else {
        _isProcessing = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error processing voice command: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }

  void stopListening() {
    debugPrint('[Voice Assistant] Mic manually stopped');
    _speech.cancel();
    _isListening = false;
    notifyListeners();
  }

  Future<void> stopSpeaking() async {
    debugPrint('[Voice Assistant] TTS manually stopped');
    await _voiceManager.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> _saveToMemory(String user, String ai) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existing = prefs.getString('daily_voice_memory');
      List<dynamic> history = [];
      if (existing != null) {
        history = jsonDecode(existing);
      }
      history.add({'user': user, 'ai': ai, 'timestamp': DateTime.now().toIso8601String()});
      await prefs.setString('daily_voice_memory', jsonEncode(history));
      debugPrint('[Voice Assistant] Saved interaction to local memory.');
    } catch (e) {
      debugPrint('[Voice Assistant] Error saving to memory: $e');
    }
  }

  Future<List<Map<String, String>>> getVoiceMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existing = prefs.getString('daily_voice_memory');
      if (existing == null) return [];
      final List<dynamic> history = jsonDecode(existing);
      return history.map((e) => {
        'user': e['user'].toString(),
        'ai': e['ai'].toString(),
      }).toList();
    } catch (e) {
      debugPrint('[Voice Assistant] Error reading memory: $e');
      return [];
    }
  }

  Future<void> clearVoiceMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('daily_voice_memory');
      debugPrint('[Voice Assistant] Local memory cleared.');
    } catch (e) {
      debugPrint('[Voice Assistant] Error clearing memory: $e');
    }
  }
}
