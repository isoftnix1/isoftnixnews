import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Platform channel to control Android's AudioManager AEC mode.
/// This activates the phone's hardware echo-cancellation chip during TTS
/// so the barge-in microphone does not pick up the speaker output.
const _audioChannel = MethodChannel('com.isoftnix.updates/audio_mode');

class VoiceManager {
  static final VoiceManager _instance = VoiceManager._internal();
  static VoiceManager get instance => _instance;

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  
  // Handlers for UI synchronization
  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onCancel;

  VoiceManager._internal();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _setupTts();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[VoiceManager] Initialization failed: $e. Retrying...');
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await _setupTts();
        _isInitialized = true;
      } catch (e2) {
        debugPrint('[VoiceManager] Retry failed: $e2. Using safe defaults.');
      }
    }
  }

  Future<void> _setupTts() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.55);
    await _tts.setPitch(1.05);

    try {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
      );
    } catch (e) {
      debugPrint('[VoiceManager] Could not set iOS Audio Category: $e');
    }

    _tts.setStartHandler(() {
      onStart?.call();
    });

    _tts.setCompletionHandler(() {
      _audioChannel.invokeMethod('setModeNormal');
      debugPrint('[VoiceManager] TTS Completed - AEC Mode Disabled (Normal)');
      onComplete?.call();
    });

    _tts.setCancelHandler(() {
      _audioChannel.invokeMethod('setModeNormal');
      debugPrint('[VoiceManager] TTS Cancelled - AEC Mode Disabled (Normal)');
      onCancel?.call();
    });

    await _detectAndLogVoices();
  }

  Future<void> _detectAndLogVoices() async {
    debugPrint('==========================');
    debugPrint('VOICE INITIALIZED');
    debugPrint('==========================');
    debugPrint('Engine: flutter_tts');
    
    try {
      final voices = await _tts.getVoices;
      if (voices != null && voices is List) {
        debugPrint('Available Voices Count: ${voices.length}');
      }
    } catch (e) {
      debugPrint('Could not fetch voices list: $e');
    }
    
    debugPrint('Speech Rate: 0.42');
    debugPrint('Pitch: 1.05');
    debugPrint('Volume: 1.0');
    debugPrint('==========================');
  }

  Future<void> _selectBestVoice(String targetLocale) async {
    try {
      final voices = await _tts.getVoices;
      if (voices == null || voices is! List) {
        await _tts.setLanguage(targetLocale);
        return;
      }

      Map<String, String>? bestVoice;
      Map<String, String>? fallbackVoice;

      for (var v in voices) {
        if (v is Map) {
          final name = v['name']?.toString() ?? '';
          final locale = v['locale']?.toString() ?? '';
          
          if (locale.contains(targetLocale)) {
            fallbackVoice ??= {"name": name, "locale": locale};

            final lowerName = name.toLowerCase();
            final isFemale = lowerName.contains('female') || (!lowerName.contains('male') && !lowerName.contains('female'));
            final isMale = lowerName.contains('male') && !lowerName.contains('female');
            final isNetwork = lowerName.contains('network') || lowerName.contains('online');

            // For Marathi, prioritize Male voice
            if (targetLocale.contains('mr')) {
              if (isNetwork && isMale) {
                bestVoice = {"name": name, "locale": locale};
                break;
              } else if (isMale) {
                fallbackVoice = {"name": name, "locale": locale};
              }
            } 
            // For other languages, prioritize Female voice
            else {
              if (isNetwork && isFemale) {
                bestVoice = {"name": name, "locale": locale};
                break;
              } else if (isFemale) {
                fallbackVoice = {"name": name, "locale": locale};
              }
            }
          }
        } else if (v is String) {
          // iOS often returns strings directly
          if (v.contains(targetLocale)) {
             fallbackVoice = {"name": v, "locale": targetLocale};
          }
        }
      }

      if (bestVoice != null) {
        await _tts.setVoice(bestVoice);
        debugPrint('[VoiceManager] Selected Voice: ${bestVoice['name']} for $targetLocale');
      } else if (fallbackVoice != null) {
        await _tts.setVoice(fallbackVoice);
        debugPrint('[VoiceManager] Selected Voice: ${fallbackVoice['name']} for $targetLocale');
      } else {
        await _tts.setLanguage(targetLocale);
      }
    } catch (e) {
      debugPrint('[VoiceManager] Error selecting best voice: $e');
      await _tts.setLanguage(targetLocale);
    }
  }

  Future<void> _setLanguage(String lang) async {
    try {
      if (lang == 'hi') {
        await _selectBestVoice('hi-IN');
      } else if (lang == 'mr') {
        var isMrAvailable = await _tts.isLanguageAvailable('mr-IN');
        if (isMrAvailable is bool && isMrAvailable) {
          await _selectBestVoice('mr-IN');
        } else {
          await _selectBestVoice('hi-IN');
        }
      } else {
        await _selectBestVoice('en-IN');
      }
    } catch (e) {
      debugPrint('[VoiceManager] setLanguage error: $e');
    }
  }

  String _cleanTextForSpeech(String text) {
    if (text.isEmpty) return text;

    String clean = text;
    clean = clean.replaceAll(RegExp(r'[\*\#\`\>\•\-]'), '');
    clean = clean.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (match) {
      return match.group(1) ?? '';
    });
    clean = clean.replaceAll(RegExp(r'https?://[^\s]+'), '');
    
    clean = clean.replaceAll('°C', ' degrees Celsius');
    clean = clean.replaceAll('km/h', ' kilometers per hour');
    clean = clean.replaceAllMapped(RegExp(r'₹(\d+)'), (match) {
      return '${match.group(1)} rupees';
    });
    clean = clean.replaceAll('₹', 'rupees '); 
    
    clean = clean.replaceAll(' PM', ' in the afternoon');
    clean = clean.replaceAll(' AM', ' in the morning');
    clean = clean.replaceAll(' pm', ' in the afternoon');
    clean = clean.replaceAll(' am', ' in the morning');

    clean = clean.replaceAll(RegExp(r'\n+'), ' ');
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');

    return clean.trim();
  }

  Future<void> speak(String text, String lang) async {
    if (!_isInitialized) {
      await init();
    }

    await stop();

    final cleanText = _cleanTextForSpeech(text);
    if (cleanText.isEmpty) return;

    await _setLanguage(lang);
    
    try {
      // We removed the setModeInCommunication call here because on OnePlus/Android, 
      // putting the phone in "Call Mode" completely blocks the SpeechRecognizer 
      // from accessing the microphone (resulting in error_no_match).
    } catch (e) {
      debugPrint('[VoiceManager] AEC setModeInCommunication failed: $e');
    }
    
    try {
      await _tts.speak(cleanText);
    } catch (e) {
      debugPrint('[VoiceManager] Speak failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
      await _audioChannel.invokeMethod('setModeNormal');
      debugPrint('[VoiceManager] TTS Stopped - AEC Mode Disabled (Normal)');
    } catch (e) {
      debugPrint('[VoiceManager] Stop failed: $e');
    }
  }
}
