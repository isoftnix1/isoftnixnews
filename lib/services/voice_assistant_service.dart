import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';

class VoiceAssistantService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ApiService _apiService = ApiService();

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  String _lastWords = '';
  String _currentLang = 'en';

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isProcessing => _isProcessing;
  String get lastWords => _lastWords;

  VoiceAssistantService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  Future<void> startListening(String currentLang) async {
    _currentLang = currentLang;

    var permStatus = await Permission.microphone.status;
    if (!permStatus.isGranted) {
      permStatus = await Permission.microphone.request();
      if (!permStatus.isGranted) {
        debugPrint('Microphone permission denied by user.');
        return;
      }
    }

    bool available = await _speech.initialize(
      onStatus: (status) async {
        debugPrint('Speech Status: $status');
        if (status == 'notListening' || status == 'done') {
          _isListening = false;
          notifyListeners();
          
          if (_lastWords.isNotEmpty && !_isProcessing) {
            final words = _lastWords;
            _lastWords = ''; // Clear to prevent double processing
            await _processCommand(words, _currentLang);
          } else if (_lastWords.isEmpty && !_isProcessing) {
            // Android Emulator Fallback: If the emulator mic didn't pick up anything, send a dummy command to test backend
            debugPrint('Microphone picked up nothing. Sending dummy command for testing...');
            await _processCommand("Tell me today's news", _currentLang);
          }
        }
      },
      onError: (errorNotification) {
        debugPrint('Speech Error: $errorNotification');
        _isListening = false;
        notifyListeners();
      },
    );

    if (available) {
      _isListening = true;
      _lastWords = '';
      notifyListeners();

      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          notifyListeners();
        },
        localeId: currentLang == 'en' ? 'en_US' : (currentLang == 'hi' ? 'hi_IN' : 'mr_IN'),
      );
    }
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;
    notifyListeners();
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  Future<void> _processCommand(String command, String lang) async {
    if (command.trim().isEmpty) return;

    _isProcessing = true;
    notifyListeners();

    try {
      final summary = await _apiService.getVoiceSummary(command, lang: lang);
      
      _isProcessing = false;
      notifyListeners();

      if (summary.isNotEmpty) {
        _isSpeaking = true;
        notifyListeners();

        // Configure TTS language based on the requested language
        if (lang == 'hi') {
          await _tts.setLanguage('hi-IN');
        } else if (lang == 'mr') {
          var isMrAvailable = await _tts.isLanguageAvailable('mr-IN');
          if (isMrAvailable is bool && isMrAvailable) {
            await _tts.setLanguage('mr-IN');
          } else {
            await _tts.setLanguage('hi-IN'); // Fallback to Hindi engine for Devanagari text
          }
        } else {
          await _tts.setLanguage('en-IN');
        }

        await _tts.speak(summary);
      }
    } catch (e) {
      debugPrint('Error processing voice command: $e');
      _isProcessing = false;
      notifyListeners();
    }
  }
}
