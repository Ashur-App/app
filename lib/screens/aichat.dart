

import 'package:ashur/secrets.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import '../upload_helper.dart';

class AIChatApp extends StatelessWidget {
  const AIChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AIChatScreen();
  }
}

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  _AIChatScreenState createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _messages = [];
  File? _selectedImage;
  final bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final storedMessages = prefs.getString('ashurai');

    if (storedMessages != null && storedMessages.isNotEmpty) {
      try {
        final decodedList = json.decode(storedMessages);
        print('Decoded list type: ${decodedList.runtimeType}');
        print('Decoded list content: $decodedList');

        if (decodedList is List<dynamic>) {
          setState(() {
            _messages = decodedList;
          });
          print('Messages: $_messages');
        } else {
          print('Error: Decoded data is not a List<dynamic>');
        }
      } catch (e) {
        print('Error decoding JSON: $e');
      }
    }
  }

  Future<void> _saveChats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final userMessages =
        _messages.where((msg) => msg['role'] != 'system').toList();
    prefs.setString('ashurai', json.encode(userMessages));
  }

  Future<void> _sendMessage(String message) async {
    if (message == "/clear") {
      _messages.clear();
      _messages = [];
      _saveChats();
      return;
    } else if (message == "/exp") {
      message =
          "Can you summarize our conversation with the last language used?";
      _selectedImage = null;
    } else if (message == "/help") {
      _selectedImage = null;
    }
    String? imageUrl;
    if (_selectedImage != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      final bytes = await _selectedImage!.readAsBytes();
      final fileName = 'aichat_${DateTime.now().millisecondsSinceEpoch}_${user.uid}.png';
      imageUrl = await UploadHelper.uploadBytes(context, bytes, filename: fileName);
    }

    setState(() {
      if (imageUrl == null) {
        _messages.add({'role': 'user', 'content': message});
      } else {
        _messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': message},
            {
              'type': 'image_url',
              'image_url': {'url': imageUrl}
            }
          ]
        });
      }
    });
    _controller.clear();
    _selectedImage = null;
    _saveChats();

    final response = await fetch();
    if (response.statusCode == 200) {
      if (kDebugMode) {
        print(response.headers);
      }
      final responseData = response.data;
      final reply = responseData['choices'][0]['message']['content'] ?? '';
      setState(() {
        _messages.add({'role': 'assistant', 'content': reply});
      });
      _saveChats();
    } else {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '... حدث خطأ! رقم الخطأ: ${response.statusCode}'
        });
      });
      print(response);
      _saveChats();
    }
  }

  

  Future<Response> fetch() async {
    const apiKey = ashuraiApiKey;
    const url = ashuraiApiUrl;
    final messages = (jsonDecode(
            '[{"role":"system","content":"You are a helpful assistant named Ashur AI (اشور AI), created by Ashur Team that its main language is Arabic (Iraq) and doesnt understand images yet, and you are NOT ChatGPT nor GPT, you are a completely different AI trained and programmed by the Ashur Team. Link to the Ashur Website is https://ashur.now.sh"}]'
        ) as List<dynamic>).cast<Map<String, dynamic>>();

    messages.addAll(_messages.whereType<Map<String, dynamic>>());
    final requestBody = {
      'messages': messages,
      'model': 'gpt-4.1',
    };

    try {
      final response = await Dio().post(url,
          data: jsonEncode(requestBody),
          options: Options(
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $apiKey',
            },
            contentType: 'application/json; charset=utf-8',
            responseType: ResponseType.json,
            followRedirects: true,
          ));

      return response;
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'AI أشور',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 64,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'AI مرحباً بك في أشور',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'اسألني أي شيء وسأحاول مساعدتك',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['role'] == 'user';
                      final content = message['content'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: colorScheme.onPrimary,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outline.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (content is String) ...[
                                      MarkdownBody(
                                        data: content,
                                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                          p: TextStyle(
                                            color: isUser
                                                ? colorScheme.onPrimary
                                                : colorScheme.onSurface,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ] else if (content is List) ...[
                                      for (var item in content)
                                        if (item['type'] == 'text')
                                          MarkdownBody(
                                            data: item['text'],
                                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                              p: TextStyle(
                                                color: isUser
                                                    ? colorScheme.onPrimary
                                                    : colorScheme.onSurface,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (isUser) ...[
                              SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: colorScheme.onSecondary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.image,
                    color: colorScheme.primary,
                  ),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (pickedFile != null) {
                      final imageBytes = await pickedFile.readAsBytes();
                      final editedImage = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageEditor(
                            image: imageBytes,
                          ),
                        ),
                      );
                      if (editedImage != null && editedImage is Uint8List) {
                        setState(() {
                          _selectedImage = File(pickedFile.path);
                        });
                      }
                    }
                  },
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك هنا...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _sendMessage(text);
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      color: colorScheme.onPrimary,
                    ),
                    onPressed: () {
                      if (_controller.text.trim().isNotEmpty) {
                        _sendMessage(_controller.text);
                      }
                    },
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
