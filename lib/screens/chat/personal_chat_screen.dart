import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/voice_visualizer.dart';
import '../../services/api_service.dart';
import '../../services/voice_assistant_service.dart';
import '../../providers/language_provider.dart';

class PersonalChatScreen extends StatefulWidget {
  const PersonalChatScreen({super.key});

  @override
  State<PersonalChatScreen> createState() => _PersonalChatScreenState();
}

class _PersonalChatScreenState extends State<PersonalChatScreen> {
  final _apiService = ApiService();
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _speechToText = SpeechToText();
  final _flutterTts = FlutterTts();

  List<dynamic> _messages = [];
  List<dynamic> _history = [];
  bool _isLoading = false;
  bool _isHistoryLoading = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _loadHistory().then((_) {
      _syncMemory();
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isHistoryLoading = true);
    try {
      final history = await _apiService.getChatHistory();
      setState(() {
        _history = history;
        _isHistoryLoading = false;
      });
    } catch (e) {
      setState(() => _isHistoryLoading = false);
    }
  }

  Future<void> _loadConversation(String conversationId) async {
    Navigator.pop(context); // close drawer
    setState(() {
      _isLoading = true;
      _activeConversationId = conversationId;
    });
    try {
      final messages = await _apiService.getChatMessages(conversationId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _newChat() {
    Navigator.pop(context); // close drawer
    setState(() {
      _activeConversationId = null;
      _messages = [];
    });
  }

  Future<void> _deleteHistory(String conversationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this conversation? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.deleteChatHistory(conversationId);
      setState(() {
        _history.removeWhere((item) => item['id'] == conversationId);
        if (_activeConversationId == conversationId) {
          _activeConversationId = null;
          _messages.clear();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chat: $e')),
        );
      }
    }
  }

  Future<void> _syncMemory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final lastSyncStr = prefs.getString('last_sync_date');

      // Only summarize if a new day has started!
      if (lastSyncStr == todayStr) {
        debugPrint('[Appa] Already synced today. Will summarize at the end of the day/tomorrow.');
        return; 
      }

      if (!mounted) return;
      final lang = context.read<LanguageProvider>().currentLanguage;
      final voiceAssistant = context.read<VoiceAssistantService>();
      final voiceHistory = await voiceAssistant.getVoiceMemory();
      
      // If there's no voice history, we should still trigger the backend to summarize yesterday's text chats!

      await _apiService.syncVoiceMemory(
        voiceHistory: voiceHistory,
        lang: lang,
        conversationId: _activeConversationId ?? '',
      );
      
      await voiceAssistant.clearVoiceMemory();
      await prefs.setString('last_sync_date', todayStr);
      debugPrint('[Appa] Automatic background sync completed for previous day.');
      
      // Reload history silently
      final history = await _apiService.getChatHistory();
      if (mounted) {
        setState(() {
          _history = history;
        });
        if (_activeConversationId != null) {
          final messages = await _apiService.getChatMessages(_activeConversationId!);
          setState(() {
            _messages = messages;
          });
        }
      }
    } catch (e) {
      debugPrint('[Appa] Automatic sync failed: $e');
    }
  }

  Future<void> _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.5);
    
    try {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        ],
      );
    } catch (e) {
      debugPrint('[Appa] Could not set iOS Audio Category: $e');
    }

    _flutterTts.setStartHandler(() {
      debugPrint('[Appa] TTS Started - Showing BLUE speaking animation');
      if (mounted) setState(() => _isSpeaking = true);
    });
    _flutterTts.setCompletionHandler(() {
      debugPrint('[Appa] TTS Finished - Hiding animation');
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setCancelHandler(() {
      debugPrint('[Appa] TTS Cancelled - Hiding animation');
      if (mounted) setState(() => _isSpeaking = false);
    });
    _flutterTts.setErrorHandler((msg) {
      debugPrint('[Appa] TTS Error - Hiding animation');
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isLoading) return; // Prevent duplicate API requests

    await _flutterTts.stop(); // Stop any ongoing TTS when sending a new message

    if (!mounted) return;
    final lang = context.read<LanguageProvider>().currentLanguage;
    final userMessage = text.trim();
    
    setState(() {
      _messages.add({
        'sender': 'user',
        'content': userMessage,
      });
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final isNewConversation = _activeConversationId == null;
      final response = await _apiService.sendChatMessage(
        message: userMessage,
        lang: lang,
        conversationId: _activeConversationId,
      );

      _activeConversationId = response['conversationId'];
      final aiMessage = response['message'];

      if (isNewConversation) {
        _loadHistory(); // Reload sidebar to show the new chat
      }

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });
      _scrollToBottom();
      
      // Speak the AI response
      if (lang == 'hi') {
        await _flutterTts.setLanguage('hi-IN');
      } else if (lang == 'mr') {
        var isMrAvailable = await _flutterTts.isLanguageAvailable('mr-IN');
        if (isMrAvailable is bool && isMrAvailable) {
          await _flutterTts.setLanguage('mr-IN');
        } else {
          await _flutterTts.setLanguage('hi-IN');
        }
      } else {
        await _flutterTts.setLanguage('en-US');
      }
      
      await _flutterTts.speak(aiMessage['content']);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  void _startListening() async {
    debugPrint('[Appa] Mic Tapped - Starting listener');
    bool wasSpeaking = _isSpeaking;
    if (_isSpeaking) {
       await _flutterTts.stop();
       setState(() => _isSpeaking = false);
    }
    await _speechToText.cancel();
    
    if (wasSpeaking) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!_speechToText.isAvailable) {
      debugPrint('[Appa] Speech to Text not available on this device');
      return;
    }
    if (_isLoading) {
      debugPrint('[Appa] Ignored Mic Tap - Already waiting for API response');
      return; // Don't listen if already waiting for a response
    }
    if (!mounted) return;
    final lang = context.read<LanguageProvider>().currentLanguage;
    String localeId = lang == 'hi' ? 'hi_IN' : lang == 'mr' ? 'mr_IN' : 'en_US';

    debugPrint('[Appa] Mic Started - Showing RED listening animation');
    setState(() => _isListening = true);
    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          _textController.text = result.recognizedWords;
          _sendMessage(result.recognizedWords);
        } else {
          _textController.text = result.recognizedWords;
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(seconds: 10),
        cancelOnError: true,
      ),
    );
  }

  void _stopListening() async {
    debugPrint('[Appa] Mic Stopped manually or timed out');
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Widget _buildMessage(dynamic message) {
    final isUser = message['sender'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).colorScheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Text(
          message['content'],
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appa'),
        elevation: 1,
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _newChat,
                  icon: const Icon(Icons.add),
                  label: const Text('New Chat'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: _isHistoryLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final conv = _history[index];
                          return ListTile(
                            leading: const Icon(Icons.chat_bubble_outline),
                            title: Text(conv['title'] ?? 'Chat', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                              onPressed: () => _deleteHistory(conv['id']),
                            ),
                            onTap: () => _loadConversation(conv['id']),
                            selected: _activeConversationId == conv['id'],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Ask me anything about farming or news!',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessage(_messages[index]);
                        },
                      ),
                
                if (_isListening || _isSpeaking)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          if (_isSpeaking) {
                            _flutterTts.stop();
                            setState(() => _isSpeaking = false);
                          } else if (_isListening) {
                            _stopListening();
                          } else {
                            _startListening();
                          }
                        },
                        child: VoiceVisualizer(
                          isListening: _isListening,
                          isSpeaking: _isSpeaking,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 50,
                  height: 30,
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      if (_isSpeaking) {
                        _flutterTts.stop();
                        setState(() => _isSpeaking = false);
                      } else if (_isListening) {
                        _stopListening();
                      } else {
                        _startListening();
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
