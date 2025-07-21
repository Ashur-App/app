import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:ashur/storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../user_badges.dart';
import '../upload_helper.dart';
import '../secrets.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import '../bot_webhook.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String currentUserUid;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.currentUserUid,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  bool _isMember = false;
  bool _isJoining = false;
  String _groupName = '';
  String _groupDescription = '';
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isSending = false;
  bool _isUploading = false;
  AudioPlayer? _audioPlayer;
  String? _currentlyPlayingAudioUrl;
  bool _isPlaying = false;
  Map<String, dynamic>? _replyToMessage;
  String? _selectedGift;
  List<Map<String, dynamic>> _giftItems = [];
  bool _loadingGifts = false;
  Map<String, dynamic> _groupMembers = {};
  final ValueNotifier<List<Map<String, dynamic>>> _mentionSuggestions = ValueNotifier([]);
  final ValueNotifier<bool> _showMentionDropdown = ValueNotifier(false);
  String _mentionQuery = '';
  int _mentionStartIdx = -1;
  final FocusNode _inputFocusNode = FocusNode();
  final LayerLink _mentionDropdownLink = LayerLink();
  OverlayEntry? _mentionOverlayEntry;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _audioPlayer = AudioPlayer();
    if (widget.currentUserUid == ashuraiUserUid) {
      _isMember = true;
    } else {
      _initRecorder();
      _checkMembership();
    }
    _fetchGroupInfo();
    _loadGiftItems();
    _markMessagesAsSeen(widget.groupId);
    _fetchGroupMembers();
    _controller.addListener(_handleMentionInput);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleMentionInput);
    _controller.dispose();
    _inputFocusNode.dispose();
    _removeMentionOverlay();
    super.dispose();
  }

  Future<void> _fetchGroupMembers() async {
  final groupRef = FirebaseDatabase.instance.ref('groups/${widget.groupId}');
  final snapshot = await groupRef.get();
  if (snapshot.exists) {
    final groupData = snapshot.value as Map<dynamic, dynamic>;
    final members = groupData['members'] as List<dynamic>? ?? [];
    Map<String, dynamic> memberMap = {};
    for (final uid in members) {
      final userRef = FirebaseDatabase.instance.ref('users/$uid');
      final userSnap = await userRef.get();
      if (userSnap.exists) {
        final userData = userSnap.value as Map<dynamic, dynamic>;
        memberMap[uid] = userData;
      }
    }
    setState(() {
      _groupMembers = memberMap;
    });
  }
  }

  void _showMentionOverlay() {
    print('DEBUG: _showMentionOverlay called');
    _removeMentionOverlay();
    const double dropdownHeight = 200;
    _mentionOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.of(_scaffoldKey.currentContext!).viewInsets.bottom + 86,
        child: Material(
          elevation: 24,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: dropdownHeight,
            ),
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _mentionSuggestions,
              builder: (context, suggestions, _) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, idx) {
                    final user = suggestions[idx];
                    return ListTile(
                      leading: user['pic'] != null && (user['pic'] as String).isNotEmpty
                          ? CircleAvatar(backgroundImage: NetworkImage(user['pic']))
                          : CircleAvatar(child: Icon(Icons.person)),
                      title: Text('@${user['username']}'),
                      onTap: () {
                        _insertMention(user['username']);
                        _removeMentionOverlay();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(_scaffoldKey.currentContext!).insert(_mentionOverlayEntry!);
  }

  void _removeMentionOverlay() {
    _mentionOverlayEntry?.remove();
    _mentionOverlayEntry = null;
    _showMentionDropdown.value = false;
  }

  void _handleMentionInput() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid) {
      _showMentionDropdown.value = false;
      return;
    }
    final cursorPos = selection.baseOffset;
    if (cursorPos <= 0) {
      _showMentionDropdown.value = false;
      return;
    }
    final beforeCursor = text.substring(0, cursorPos);
    final mentionMatch = RegExp(r'@([a-zA-Z0-9_\-]+)$').firstMatch(beforeCursor);
    if (!beforeCursor.contains('@')) {
      _showMentionDropdown.value = false;
      return;
    }
    if (mentionMatch != null) {
      final query = mentionMatch.group(1) ?? '';
      print('_groupMembers: \n$_groupMembers');
      print('query: $query');
      final suggestions = _groupMembers.entries
          .where((e) => ((e.value['username'] ?? '').toString().trim().toLowerCase()).contains(query.trim().toLowerCase()))
          .map((e) => {'uid': e.key, 'username': e.value['username'], 'pic': e.value['pic']})
          .toList();
      print('suggestions: $suggestions');
      _showMentionDropdown.value = true;
      _mentionSuggestions.value = suggestions;
      _mentionQuery = query;
      _mentionStartIdx = mentionMatch.start;
      _showMentionOverlay();
    } else {
      _showMentionDropdown.value = false;
    }
  }

  void _insertMention(String username) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;
    if (_mentionStartIdx >= 0 && cursorPos >= _mentionStartIdx) {
      final before = text.substring(0, _mentionStartIdx);
      final after = text.substring(cursorPos);
      final newText = '$before@$username $after';
      final newCursor = ('$before@$username ').length;
      setState(() {
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(offset: newCursor);
      });
      _showMentionDropdown.value = false;
      _removeMentionOverlay();
      FocusScope.of(context).requestFocus(_inputFocusNode);
    }
  }

  Future<void> _initRecorder() async {
    if (!kIsWeb) {
      await _recorder!.openRecorder();
      await Permission.microphone.request();
    }
  }

  Future<void> _checkMembership() async {
    if (widget.currentUserUid == ashuraiUserUid) {
      setState(() {
        _isMember = true;
      });
      return;
    }
    final groupRef = FirebaseDatabase.instance.ref('groups/${widget.groupId}');
    final snapshot = await groupRef.get();
    if (snapshot.exists) {
      final groupData = snapshot.value as Map<dynamic, dynamic>;
      final members = groupData['members'] as List<dynamic>? ?? [];
      setState(() {
        _isMember = members.contains(widget.currentUserUid);
      });
    }
  }

  Future<void> _fetchGroupInfo() async {
    final groupRef = FirebaseDatabase.instance.ref('groups/${widget.groupId}');
    final snapshot = await groupRef.get();
    if (snapshot.exists) {
      final groupData = snapshot.value as Map<dynamic, dynamic>;
      setState(() {
        _groupName = groupData['name'] ?? 'اسم المجموعة';
        _groupDescription = groupData['description'] ?? 'لا يوجد وصف';
      });
    }
  }

  Future<void> _joinGroup() async {
    setState(() {
      _isJoining = true;
    });

    try {
      final groupRef = FirebaseDatabase.instance.ref('groups/${widget.groupId}');
      final snapshot = await groupRef.get();
      if (snapshot.exists) {
        final groupData = snapshot.value as Map<dynamic, dynamic>;
        final members = List<dynamic>.from(groupData['members'] as List<dynamic>? ?? []);
        if (!members.contains(widget.currentUserUid)) {
          members.add(widget.currentUserUid);
          await groupRef.update({'members': members});
          setState(() {
            _isMember = true;
          });
          await triggerBotWebhooks(
            target: widget.groupId,
            senderUid: widget.currentUserUid,
            message: '',
            isGroup: true,
            action: 'group:join',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في الانضمام: $e')),
        );
      }
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  Future<List<String>> _extractMentionedUids(String text) async {
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_\-]+)');
    final matches = mentionRegex.allMatches(text);
    final usernames = matches.map((m) => m.group(1)).whereType<String>().toSet();
    List<String> uids = [];
    for (final username in usernames) {
      final userRef = FirebaseDatabase.instance.ref('users');
      final snap = await userRef.orderByChild('username').equalTo(username).limitToFirst(1).get();
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final uid = data.keys.first;
        uids.add(uid);
      }
    }
    return uids;
  }

  Future<void> _sendMessage(String text) async {
    if ((widget.currentUserUid != ashuraiUserUid && !_isMember) || text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      final mentions = await _extractMentionedUids(text);
      final messageData = {
        'text': text.trim(),
        'audioUrl': '',
        'imageUrl': '',
        'sender': widget.currentUserUid,
        'timestamp': ServerValue.timestamp,
        'replyTo': _replyToMessage,
        'gift': _selectedGift,
        if (mentions.isNotEmpty) 'mentions': mentions,
      };
      await FirebaseDatabase.instance
          .ref('groups/${widget.groupId}/messages')
          .push()
          .set(messageData);
      _controller.clear();
      setState(() {
        _replyToMessage = null;
        _selectedGift = null;
      });
      await triggerBotWebhooks(
        target: widget.groupId,
        senderUid: widget.currentUserUid,
        message: text.trim(),
        isGroup: true,
        action: _replyToMessage != null ? 'message:reply' : 'message:send',
      );
      if (text.toLowerCase().contains('@ashurai')) {
        _sendAshuraiAI(text);
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendAshuraiAI(String userPrompt) async {
    final messagesRef = FirebaseDatabase.instance.ref('groups/${widget.groupId}/messages');
    final snapshot = await messagesRef.orderByChild('timestamp').get();
    List<Map<String, dynamic>> contextMessages = [];
    if (snapshot.exists && snapshot.value != null) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((key, value) {
        final msg = Map<String, dynamic>.from(value as Map);
        contextMessages.add(msg);
      });
      contextMessages.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
    }

    final senderUsername = await _fetchUsernameFromUid(widget.currentUserUid);
    final groupName = _groupName;
    final groupDescription = _groupDescription;
    Map<String, dynamic>? userMsg;
    for (var i = contextMessages.length - 1; i >= 0; i--) {
      if (contextMessages[i]['sender'] == widget.currentUserUid &&
          (contextMessages[i]['text'] ?? '').toLowerCase().contains('@ashurai')) {
        userMsg = contextMessages[i];
        break;
      }
    }
    final replyTo = userMsg != null && userMsg['replyTo'] != null ? userMsg['replyTo'] : null;
    List<Map<String, dynamic>> chatHistory = [
      {
        'role': 'system',
        'content':
            'You are a helpful assistant named Ashur AI (أشور AI), created by Ashur Team. '
            'This group is called "$groupName" and its description is "$groupDescription". '
            'The user who triggered you is @$senderUsername. '
            'Your main language is Arabic (Iraq) and you do not understand images yet. '
            'You are NOT ChatGPT nor GPT, you are a completely different AI trained and programmed by the Ashur Team. '
            'Link to the Ashur Website is https://ashur.now.sh',
      },
    ];
    for (final msg in contextMessages) {
      String content = msg['text'] ?? '';
      if (msg['imageUrl'] != null && (msg['imageUrl'] as String).isNotEmpty) {
        content = '${content.isNotEmpty ? '$content ' : ''}[IMAGE]';
      }
      if (msg['gift'] != null) {
        content = '${content.isNotEmpty ? '$content ' : ''}[GIFT]';
      }
      if (msg['audioUrl'] != null && (msg['audioUrl'] as String).isNotEmpty) {
        content = '${content.isNotEmpty ? '$content ' : ''}[VOICE]';
      }
      if (msg['sender'] == ashuraiUserUid) {
        chatHistory.add({'role': 'assistant', 'content': content});
      } else {
        chatHistory.add({'role': 'user', 'content': content});
      }
    }
    chatHistory.add({'role': 'user', 'content': userPrompt});
    final thinkingRef = FirebaseDatabase.instance
        .ref('groups/${widget.groupId}/messages')
        .push();
    await thinkingRef.set({
      'text': '...',
      'audioUrl': '',
      'imageUrl': '',
      'sender': ashuraiUserUid,
      'timestamp': ServerValue.timestamp,
      'aiThinking': true,
      if (userMsg != null) 'replyTo': {
        'key': userMsg['key'],
        'sender': userMsg['sender'],
        'text': userMsg['text'],
      },
    });
    final thinkingKey = thinkingRef.key;
    try {
      final response = await Dio().post(
        ashuraiApiUrl,
        data: jsonEncode({
          'messages': chatHistory,
          'model': 'gpt-4.1',
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $ashuraiApiKey',
          },
          contentType: 'application/json; charset=utf-8',
          responseType: ResponseType.json,
          followRedirects: true,
        ),
      );
      final reply = response.data['choices'][0]['message']['content'] ?? '';
      await FirebaseDatabase.instance
          .ref('groups/${widget.groupId}/messages/$thinkingKey')
          .update({
        'text': reply,
        'aiThinking': null,
      });
    } catch (e) {
      await FirebaseDatabase.instance
          .ref('groups/${widget.groupId}/messages/$thinkingKey')
          .update({
        'text': '... حدث خطأ في استجابة AI',
        'aiThinking': null,
      });
    }
  }

  Future<void> _handleGroupInvite(String groupId) async {
    try {
      final groupRef = FirebaseDatabase.instance.ref('groups/$groupId');
      final snapshot = await groupRef.get();
      
      if (snapshot.exists) {
        final groupData = snapshot.value as Map<dynamic, dynamic>;
        final members = List<dynamic>.from(groupData['members'] as List<dynamic>? ?? []);
        if (!members.contains(widget.currentUserUid)) {
          members.add(widget.currentUserUid);
          await groupRef.update({'members': members});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم الانضمام إلى المجموعة بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('أنت بالفعل عضو في هذه المجموعة'),
              backgroundColor: Colors.orange,
            ),
          );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('المجموعة غير موجودة'),
            backgroundColor: Colors.red,
          ),
        );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الانضمام إلى المجموعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
      }
    }
  }

  Future<String> _fetchUsernameFromUid(String uid) async {
    final userRef = FirebaseDatabase.instance.ref('users/$uid');
    final snapshot = await userRef.get();
    if (snapshot.exists) {
      final userData = snapshot.value as Map<dynamic, dynamic>;
      return userData['username'] ?? 'Unknown';
    }
    return 'Unknown';
  }

  Future<void> _playAudio(String audioUrl) async {
    if (_currentlyPlayingAudioUrl == audioUrl && _isPlaying) {
      
      await _audioPlayer?.stop();
      setState(() {
        _isPlaying = false;
        _currentlyPlayingAudioUrl = null;
      });
      return;
    }

    
    if (_isPlaying) {
      await _audioPlayer?.stop();
    }

    try {
      setState(() {
        _isPlaying = true;
        _currentlyPlayingAudioUrl = audioUrl;
      });

      await _audioPlayer?.play(UrlSource(audioUrl));
      
      _audioPlayer?.onPlayerComplete.listen((_) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingAudioUrl = null;
        });
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error playing audio: $e');
      }
      setState(() {
        _isPlaying = false;
        _currentlyPlayingAudioUrl = null;
      });
    }
  }

  Widget _buildVoiceMessageWidget(String audioUrl, bool isMe) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCurrentlyPlaying = _currentlyPlayingAudioUrl == audioUrl && _isPlaying;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe 
            ? colorScheme.primary.withValues(alpha: 0.1)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentlyPlaying 
              ? colorScheme.primary 
              : colorScheme.outline.withValues(alpha: 0.2),
          width: isCurrentlyPlaying ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isCurrentlyPlaying 
                  ? colorScheme.primary 
                  : colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
                color: isCurrentlyPlaying 
                    ? colorScheme.onPrimary 
                    : colorScheme.primary,
                size: 20,
              ),
              onPressed: () => _playAudio(audioUrl),
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رسالة صوتية',
                style: TextStyle(
                  color: isMe 
                      ? colorScheme.onPrimary 
                      : colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.mic,
                    size: 12,
                    color: isMe 
                        ? colorScheme.onPrimary.withValues(alpha: 0.7)
                        : colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  SizedBox(width: 4),
                  Text(
                    isCurrentlyPlaying ? 'جاري التشغيل...' : 'اضغط للاستماع',
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe 
                          ? colorScheme.onPrimary.withValues(alpha: 0.7)
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClickableText(String text, bool isMe) {
    final colorScheme = Theme.of(context).colorScheme;
    final urlRegex = RegExp(r'https?://[^\s]+');
    final groupRegex = RegExp(r'group://[^\s]+');
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_\-]+)');
    final hasUrls = urlRegex.hasMatch(text) || groupRegex.hasMatch(text);
    final hasMentions = mentionRegex.hasMatch(text);
    if (!hasUrls && !hasMentions) {
      return MarkdownBody(
        data: text,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: TextStyle(
            color: isMe
                ? colorScheme.onPrimary
                : colorScheme.onSurface,
          ),
        ),
      );
    }
    
    List<Widget> widgets = [];
    String remainingText = text;
    List<_MatchSpan> spans = [];
    urlRegex.allMatches(text).forEach((m) => spans.add(_MatchSpan(m.start, m.end, 'url', m.group(0)!)));
    groupRegex.allMatches(text).forEach((m) => spans.add(_MatchSpan(m.start, m.end, 'group', m.group(0)!)));
    mentionRegex.allMatches(text).forEach((m) => spans.add(_MatchSpan(m.start, m.end, 'mention', m.group(0)!)));
    spans.sort((a, b) => a.start.compareTo(b.start));
    int lastIndex = 0;
    for (final span in spans) {
      if (span.start > lastIndex) {
        widgets.add(MarkdownBody(
          data: remainingText.substring(lastIndex, span.start),
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(
              color: isMe
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
            ),
          ),
        ));
      }
      if (span.type == 'group') {
        final groupId = span.text.replaceAll('group://', '');
        widgets.add(_buildGroupInviteWidget(groupId, isMe));
      } else if (span.type == 'url') {
        widgets.add(
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(span.text);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: MarkdownBody(
              data: span.text,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  color: isMe
                      ? colorScheme.onPrimary.withValues(alpha: 0.8)
                      : colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        );
      } else if (span.type == 'mention') {
        final username = span.text.substring(1);
        widgets.add(
          GestureDetector(
            onTap: () async {
              final user = _groupMembers.values.firstWhere(
                (u) => u['username'] == username,
                orElse: () => null,
              );
              if (user != null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        if (user['pic'] != null && (user['pic'] as String).isNotEmpty)
                          CircleAvatar(backgroundImage: NetworkImage(user['pic']), radius: 22)
                        else
                          CircleAvatar(child: Icon(Icons.person)),
                        SizedBox(width: 12),
                        Text('@$username'),
                      ],
                    ),
                    content: Text(user['bio'] ?? 'لا يوجد نبذة'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('إغلاق'),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Column(children:[Text(
              span.text,
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ), SizedBox(width: 3)]),
          ),
        );
      }
      lastIndex = span.end;
    }
    if (lastIndex < remainingText.length) {
      widgets.add(MarkdownBody(
        data: remainingText.substring(lastIndex),
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: TextStyle(
            color: isMe
                ? colorScheme.onPrimary
                : colorScheme.onSurface,
          ),
        ),
      ));
    }
    return Wrap(
      children: widgets,
    );
  }

  Widget _buildGroupInviteWidget(String groupId, bool isMe) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance.ref('groups/$groupId').once(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe 
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe 
                  ? colorScheme.errorContainer.withValues(alpha: 0.3)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: colorScheme.error,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'مجموعة غير موجودة',
                    style: TextStyle(
                      color: isMe ? colorScheme.onPrimary : colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        final groupData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final groupName = groupData['name'] ?? 'مجموعة غير معروفة';
        final groupPic = groupData['pic'] ?? '';
        final members = groupData['members'] ?? [];
        final memberCount = members.length ?? 0;
        
        return GestureDetector(
          onTap: () => _handleGroupInvite(groupId),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe 
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: groupPic.isNotEmpty
                        ? Image.network(
                            groupPic,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.groups,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: colorScheme.primaryContainer,
                            child: Icon(
                              Icons.groups,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: TextStyle(
                          color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '$memberCount عضو',
                        style: TextStyle(
                          color: isMe 
                              ? colorScheme.onPrimary.withValues(alpha: 0.8)
                              : colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'انضم',
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _groupName,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('groups/${widget.groupId}').onValue,
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
                return IconButton(
                  icon: Icon(Icons.info_outline, color: colorScheme.onSurface),
                  onPressed: () {},
                );
              }

              final groupData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
              final isOwner = groupData['owner'] == widget.currentUserUid;

              return PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
                onSelected: (value) async {
                  if (value == 'info') {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        title: Row(
                          children: [
                            if (groupData['pic'] != null && (groupData['pic'] as String).isNotEmpty)
                              CircleAvatar(
                                backgroundImage: NetworkImage(groupData['pic']),
                                radius: 28,
                              )
                            else
                              CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                radius: 28,
                                child: Icon(Icons.groups, color: colorScheme.primary, size: 32),
                              ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupData['name'] ?? 'غير محدد',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '@${groupData['id'] ?? ''}',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    groupData['description']?.isNotEmpty == true ? groupData['description'] : 'لا يوجد وصف',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.people, color: colorScheme.secondary, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'عدد الأعضاء: ',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${(groupData['members'] as List<dynamic>? ?? []).length}',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, color: colorScheme.tertiary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'تاريخ الإنشاء: ',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  groupData['created_at'] ?? 'غير محدد',
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  } else if (value == 'invite') {
                    final inviteLink = 'group://${widget.groupId}';
                    await Clipboard.setData(ClipboardData(text: inviteLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم نسخ رابط الدعوة'),
                        backgroundColor: colorScheme.primary,
                      ),
                    );
                  } else if (value == 'edit' && isOwner) {
                    TextEditingController groupNameController = TextEditingController(text: groupData['name'] ?? '');
                    TextEditingController groupDescriptionController = TextEditingController(text: groupData['description'] ?? '');
                    io.File? newGroupPic;
                    bool isUploadingPic = false;
                    showDialog(
                      context: context,
                      builder: (context) => StatefulBuilder(
                        builder: (context, setState) => AlertDialog(
                          backgroundColor: colorScheme.surface,
                          title: Text(
                            'تعديل المجموعة',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: isUploadingPic
                                    ? null
                                    : () async {
                                        final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
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
                                            final shouldSend = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: Text('معاينة الصورة'),
                                                content: Image.memory(editedImage, fit: BoxFit.cover),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
                                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('إرسال')),
                                                ],
                                              ),
                                            );
                                            if (shouldSend != true) return;
                                            final tempDir = await io.Directory.systemTemp.createTemp('edited_image');
                                            final tempFile = io.File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                            await tempFile.writeAsBytes(editedImage);
                                            setState(() {
                                              newGroupPic = tempFile;
                                            });
                                          }
                                        }
                                      },
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3), width: 2),
                                  ),
                                  child: newGroupPic != null
                                      ? ClipOval(child: Image.file(newGroupPic!, width: 80, height: 80, fit: BoxFit.cover))
                                      : (groupData['pic']?.isNotEmpty == true
                                          ? ClipOval(child: Image.network(groupData['pic'], width: 80, height: 80, fit: BoxFit.cover))
                                          : Icon(Icons.group, size: 40, color: colorScheme.primary)),
                                ),
                              ),
                              SizedBox(height: 16),
                              TextField(
                                controller: groupNameController,
                                decoration: InputDecoration(
                                  labelText: 'اسم المجموعة',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              SizedBox(height: 16),
                              TextField(
                                controller: groupDescriptionController,
                                decoration: InputDecoration(
                                  labelText: 'وصف المجموعة',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                String? newPicUrl;
                                if (newGroupPic != null) {
                                  setState(() => isUploadingPic = true);
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user == null) throw Exception('User not logged in');
                                  final bytes = await newGroupPic!.readAsBytes();
                                  final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(newGroupPic!.path)}';
                                  final uploaded = await StorageHelper.upload(user.uid, bytes, filename: fileName);
                                  newPicUrl = '$ashurStorageUrl?fileId=${uploaded.fileId}';
                                  setState(() => isUploadingPic = false);
                                }
                                await FirebaseDatabase.instance
                                    .ref('groups/${widget.groupId}')
                                    .update({
                                  'name': groupNameController.text,
                                  'description': groupDescriptionController.text,
                                  if (newPicUrl != null) 'pic': newPicUrl,
                                });
                                Navigator.of(context).pop();
                                _fetchGroupInfo();
                              },
                              child: Text('حفظ'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 8),
                        Text('معلومات المجموعة'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'invite',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('مشاركة رابط الدعوة'),
                      ],
                    ),
                  ),
                  if (isOwner)
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('تعديل المجموعة'),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: _isMember
          ? Column(
              children: [
                Expanded(
                  child: StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref('groups/${widget.groupId}/messages')
                        .orderByChild('timestamp')
                        .onValue,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: colorScheme.error,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'حدث خطأ في تحميل الرسائل',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: colorScheme.primary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'جاري تحميل الرسائل...',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      List<Map<String, dynamic>> messages = [];
                      Map<String, dynamic> messageKeys = {};
                      if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                        data.forEach((key, value) {
                          final msg = Map<String, dynamic>.from(value as Map);
                          msg['key'] = key;
                          messages.add(msg);
                          messageKeys[key] = msg;
                        });
                        messages.sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
                      }

                      final pinnedMessages = messages.where((m) => m['pinned'] == true).toList();
                      final normalMessages = messages.where((m) => m['pinned'] != true).toList();
                      final allMessages = [...pinnedMessages, ...normalMessages];

                      if (allMessages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'لا توجد رسائل بعد',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'ابدأ المحادثة الآن',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (pinnedMessages.isNotEmpty) {
                        final pinned = pinnedMessages.first;
                        return Column(
                          children: [
                            Container(
                              color: colorScheme.surfaceContainerHighest,
                              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.push_pin, color: colorScheme.primary),
                                  SizedBox(width: 8),
                                  Expanded(child: _buildPinnedMessageWidget(pinned)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: normalMessages.length,
                                itemBuilder: (context, index) {
                                  final message = normalMessages[index];
                                  final isMe = message['sender'] == widget.currentUserUid;
                                  final messageKey = message['key'];
                                  final reactions = message['reactions'] ?? {};
                                  final isDeleted = message['deleted'] == true;
                                  final isEdited = message['edited'] == true;
                                  final isPinned = message['pinned'] == true;
                                  final seenBy = (message['seenBy'] as List?) ?? [];

                                  return GestureDetector(
                                    onLongPressStart: (details) async {
                                      final selected = await showMenu<String>(
                                        context: context,
                                        position: RelativeRect.fromLTRB(
                                          details.globalPosition.dx,
                                          details.globalPosition.dy,
                                          details.globalPosition.dx + 1,
                                          details.globalPosition.dy + 1,
                                        ),
                                        items: [
                                          PopupMenuItem(value: 'react', child: Text('تفاعل')),
                                          PopupMenuItem(value: 'reply', child: Text('رد')),
                                          if (isMe && !isDeleted) PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                          if (isMe && !isDeleted) PopupMenuItem(value: 'delete', child: Text('حذف')),
                                          if (isMe && !isDeleted && !isPinned) PopupMenuItem(value: 'pin', child: Text('تثبيت')),
                                          if (isMe && !isDeleted && isPinned) PopupMenuItem(value: 'unpin', child: Text('إلغاء التثبيت')),
                                        ],
                                      );
                                      if (selected == 'react') {
                                        final emoji = await showMenu<String>(
                                          context: context,
                                          position: RelativeRect.fromLTRB(
                                            details.globalPosition.dx,
                                            details.globalPosition.dy + 40,
                                            details.globalPosition.dx + 1,
                                            details.globalPosition.dy + 41,
                                          ),
                                          items: [
                                            PopupMenuItem(value: '👍', child: Text('👍')),
                                            PopupMenuItem(value: '❤️', child: Text('❤️')),
                                            PopupMenuItem(value: '😂', child: Text('😂')),
                                            PopupMenuItem(value: '🔥', child: Text('🔥')),
                                            PopupMenuItem(value: '😮', child: Text('😮')),
                                            PopupMenuItem(value: '🙏', child: Text('🙏')),
                                          ],
                                        );
                                        if (emoji != null) {
                                          await _addReaction(messageKey, emoji);
                                        }
                                      } else if (selected == 'reply') {
                                        setState(() {
                                          _replyToMessage = {
                                            'key': messageKey,
                                            'sender': message['sender'],
                                            'text': message['text'],
                                          };
                                        });
                                      } else if (selected == 'edit') {
                                        final controller = TextEditingController(text: message['text']);
                                        final result = await showDialog<String>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('تعديل الرسالة'),
                                            content: TextField(controller: controller),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
                                              TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('حفظ')),
                                            ],
                                          ),
                                        );
                                        if (result != null && result.trim().isNotEmpty) {
                                          await _editMessage(messageKey, result.trim());
                                        }
                                      } else if (selected == 'delete') {
                                        await _deleteMessage(messageKey);
                                      } else if (selected == 'pin') {
                                        await _pinMessage(messageKey);
                                      } else if (selected == 'unpin') {
                                        await _unpinMessage(messageKey);
                                      }
                                    },
                                    child: Row(
                                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      children: [
                                        if (!isMe) ...[
                                          FutureBuilder<String>(
                                            future: _fetchUsernameFromUid(message['sender']),
                                            builder: (context, usernameSnapshot) {
                                              return Container(
                                                margin: EdgeInsets.only(right: 8),
                                                child: Column(
                                                  children: [
                                                    FutureBuilder<String?>(
                                                      future: _fetchUserPic(message['sender']),
                                                      builder: (context, picSnapshot) {
                                                        final pic = picSnapshot.data;
                                                        return CircleAvatar(
                                                          radius: 16,
                                                          backgroundColor: colorScheme.primary,
                                                          backgroundImage: (pic != null && pic.isNotEmpty)
                                                              ? NetworkImage(pic)
                                                              : null,
                                                          child: (pic == null || pic.isEmpty)
                                                              ? Icon(
                                                                  Icons.person,
                                                                  color: colorScheme.onPrimary,
                                                                  size: 20,
                                                                )
                                                              : null,
                                                        );
                                                      },
                                                    ),
                                                    if (usernameSnapshot.hasData) ...[
                                                      SizedBox(height: 4),
                                                      Text(
                                                        '@${usernameSnapshot.data}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: message['profileTheme']?.isNotEmpty == true
                                                              ? Color(int.parse(message['profileTheme']))
                                                              : colorScheme.onSurface.withValues(alpha: 0.6),
                                                        ),
                                                      ),
                                                      SizedBox(width: 4),
                                                      UserBadges(userData: Map<String, dynamic>.from(message), iconSize: 14),
                                                    ],
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isMe
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
                                                if (!isDeleted && message['replyTo'] != null) ...[
                                                  Container(
                                                    margin: EdgeInsets.only(bottom: 6, right: 2),
                                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.primaryContainer.withValues(alpha: 0.18),
                                                      border: Border(
                                                        right: BorderSide(color: colorScheme.primary, width: 4),
                                                      ),
                                                      borderRadius: BorderRadius.circular(7),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(Icons.reply, size: 14, color: colorScheme.primary),
                                                        SizedBox(width: 6),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              FutureBuilder<String>(
                                                                future: _fetchUsernameFromUid(message['replyTo']['sender'] ?? ''),
                                                                builder: (context, snapshot) {
                                                                  final username = snapshot.data ?? '';
                                                                  return Text(
                                                                    '@$username',
                                                                    style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                                                  );
                                                                },
                                                              ),
                                                              SizedBox(height: 2),
                                                              Text(
                                                                message['replyTo']['text'] ?? '',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                if (isPinned)
                                                  Row(
                                                    children: [
                                                      Icon(Icons.push_pin, size: 16, color: colorScheme.primary),
                                                      SizedBox(width: 4),
                                                      Text('مثبت', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                                                    ],
                                                  ),
                                                if (isDeleted)
                                                  Text('تم حذف الرسالة', style: TextStyle(color: colorScheme.error, fontStyle: FontStyle.italic)),
                                                if (!isDeleted && message['text']?.isNotEmpty == true)
                                                  _buildClickableText(message['text'], isMe),
                                                if (!isDeleted && message['imageUrl']?.isNotEmpty == true) ...[
                                                  if (message['text']?.isNotEmpty == true) SizedBox(height: 8),
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      message['imageUrl'],
                                                      width: 200,
                                                      height: 150,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Container(
                                                          width: 200,
                                                          height: 150,
                                                          decoration: BoxDecoration(
                                                            color: colorScheme.surfaceContainerHighest,
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Icon(
                                                            Icons.error_outline,
                                                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                                if (!isDeleted && message['audioUrl']?.isNotEmpty == true) ...[
                                                  if (message['text']?.isNotEmpty == true || message['imageUrl']?.isNotEmpty == true) 
                                                    SizedBox(height: 8),
                                                  _buildVoiceMessageWidget(message['audioUrl'], isMe),
                                                ],
                                                if (!isDeleted && reactions.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 8.0),
                                                    child: Wrap(
                                                      spacing: 8,
                                                      children: [
                                                        ..._groupReactionsByEmoji(reactions).entries.map((entry) => FutureBuilder<List<String>>(
                                                          future: Future.wait(entry.value.map((uid) => _fetchUsernameFromUid(uid)).toList()),
                                                          builder: (context, snapshot) {
                                                            final usernames = snapshot.data ?? [];
                                                            return GestureDetector(
                                                              onTap: () async {
                                                                final user = FirebaseAuth.instance.currentUser;
                                                                if (user != null && entry.value.contains(user.uid)) {
                                                                  await _removeReaction(messageKey);
                                                                } else {
                                                                  await _addReaction(messageKey, entry.key);
                                                                }
                                                              },
                                                              child: Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                decoration: BoxDecoration(
                                                                  color: colorScheme.primaryContainer,
                                                                  borderRadius: BorderRadius.circular(16),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Text(entry.key, style: TextStyle(fontSize: 16)),
                                                                    SizedBox(width: 4),
                                                                    if (usernames.isNotEmpty)
                                                                      Text('(${usernames.map((u) => '@$u').join(', ')})', style: TextStyle(fontSize: 12)),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        )),
                                                      ],
                                                    ),
                                                  ),
                                                if (!isDeleted && isEdited)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4.0),
                                                    child: Text('تم التعديل', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                                                  ),
                                                if (!isDeleted && message['gift'] != null) ...[
                                                  FutureBuilder<DatabaseEvent>(
                                                    future: FirebaseDatabase.instance.ref('streaks_store/items/${message['gift']}').once(),
                                                    builder: (context, snap) {
                                                      if (!snap.hasData || snap.data!.snapshot.value == null) {
                                                        return Container(
                                                          padding: EdgeInsets.all(16),
                                                          decoration: BoxDecoration(
                                                            color: colorScheme.primaryContainer.withOpacity(0.2),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.card_giftcard, color: colorScheme.primary, size: 28),
                                                              SizedBox(width: 12),
                                                              Text('هدية', style: TextStyle(fontWeight: FontWeight.bold)),
                                                            ],
                                                          ),
                                                        );
                                                      }
                                                      final item = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
                                                      return Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Card(
                                                            color: colorScheme.primaryContainer.withOpacity(0.18),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                            child: Padding(
                                                              padding: const EdgeInsets.all(14),
                                                              child: Row(
                                                                children: [
                                                                  Icon(_iconFromString(item['icon'], item['type']), color: colorScheme.primary, size: 32),
                                                                  SizedBox(width: 12),
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(item['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
                                                                        SizedBox(height: 4),
                                                                        Text(item['desc'] ?? '', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  Chip(
                                                                    label: Row(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      children: [
                                                                        Icon(Icons.bolt, color: Colors.amber, size: 16),
                                                                        SizedBox(width: 2),
                                                                        Text('${item['cost'] ?? 0}', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                                                      ],
                                                                    ),
                                                                    backgroundColor: Colors.amber.withOpacity(0.1),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          if ((message['giftClaimed'] != true) && message['sender'] != widget.currentUserUid)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 8.0),
                                                              child: OutlinedButton.icon(
                                                                style: OutlinedButton.styleFrom(
                                                                  foregroundColor: colorScheme.primary,
                                                                  side: BorderSide(color: colorScheme.primary),
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                                ),
                                                                icon: Icon(Icons.card_giftcard, size: 18),
                                                                label: Text('استلام الهدية', style: TextStyle(fontWeight: FontWeight.bold)),
                                                                onPressed: _isSending ? null : () async {
                                                                  await _claimGift(message['key'], item);
                                                                },
                                                              ),
                                                            ),
                                                          if (message['giftClaimed'] == true)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 8.0),
                                                              child: Row(
                                                                children: [
                                                                  Icon(Icons.card_giftcard, color: Colors.green, size: 20),
                                                                  SizedBox(width: 8),
                                                                  Text('تم استلام الهدية', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                                                  if (message['giftClaimedBy'] != null && (message['giftClaimedBy'] as String).isNotEmpty) ...[
                                                                    SizedBox(width: 8),
                                                                    FutureBuilder<String>(
                                                                      future: _fetchUsernameFromUid(message['giftClaimedBy']),
                                                                      builder: (context, snapshot) {
                                                                        final username = snapshot.data;
                                                                        if (username == null) return SizedBox.shrink();
                                                                        return Text('(@$username)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                                                                      },
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                ],
                                                if (isMe && seenBy.isNotEmpty)
                                                  FutureBuilder<List<String>>(
                                                    future: Future.wait(seenBy.map((uid) => _fetchUsernameFromUid(uid)).toList()),
                                                    builder: (context, snapshot) {
                                                      if (!snapshot.hasData) return SizedBox.shrink();
                                                      final usernames = snapshot.data!;
                                                      return Padding(
                                                        padding: const EdgeInsets.only(top: 2.0),
                                                        child: Text(
                                                          'تمت القراءة بواسطة: ${usernames.map((u) => '@$u').join(', ')}',
                                                          style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isMe) ...[
                                          SizedBox(width: 8),
                                          Column(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: colorScheme.secondary,
                                                child: Icon(
                                                  Icons.person,
                                                  color: colorScheme.onSecondary,
                                                  size: 20,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'أنت',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: allMessages.length,
                          itemBuilder: (context, index) {
                            final message = allMessages[index];
                            final isMe = message['sender'] == widget.currentUserUid;
                            final messageKey = message['key'];
                            final reactions = message['reactions'] ?? {};
                            final isDeleted = message['deleted'] == true;
                            final isEdited = message['edited'] == true;
                            final isPinned = message['pinned'] == true;
                            final seenBy = (message['seenBy'] as List?) ?? [];

                            return GestureDetector(
                              onLongPressStart: (details) async {
                                final selected = await showMenu<String>(
                                  context: context,
                                  position: RelativeRect.fromLTRB(
                                    details.globalPosition.dx,
                                    details.globalPosition.dy,
                                    details.globalPosition.dx + 1,
                                    details.globalPosition.dy + 1,
                                  ),
                                  items: [
                                    PopupMenuItem(value: 'react', child: Text('تفاعل')),
                                    PopupMenuItem(value: 'reply', child: Text('رد')),
                                    if (isMe && !isDeleted) PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                    if (isMe && !isDeleted) PopupMenuItem(value: 'delete', child: Text('حذف')),
                                    if (isMe && !isDeleted && !isPinned) PopupMenuItem(value: 'pin', child: Text('تثبيت')),
                                    if (isMe && !isDeleted && isPinned) PopupMenuItem(value: 'unpin', child: Text('إلغاء التثبيت')),
                                  ],
                                );
                                if (selected == 'react') {
                                  final emoji = await showMenu<String>(
                                    context: context,
                                    position: RelativeRect.fromLTRB(
                                      details.globalPosition.dx,
                                      details.globalPosition.dy + 40,
                                      details.globalPosition.dx + 1,
                                      details.globalPosition.dy + 41,
                                    ),
                                    items: [
                                      PopupMenuItem(value: '👍', child: Text('👍')),
                                      PopupMenuItem(value: '❤️', child: Text('❤️')),
                                      PopupMenuItem(value: '😂', child: Text('😂')),
                                      PopupMenuItem(value: '🔥', child: Text('🔥')),
                                      PopupMenuItem(value: '😮', child: Text('😮')),
                                      PopupMenuItem(value: '🙏', child: Text('🙏')),
                                    ],
                                  );
                                  if (emoji != null) {
                                    await _addReaction(messageKey, emoji);
                                  }
                                } else if (selected == 'reply') {
                                  setState(() {
                                    _replyToMessage = {
                                      'key': messageKey,
                                      'sender': message['sender'],
                                      'text': message['text'],
                                    };
                                  });
                                } else if (selected == 'edit') {
                                  final controller = TextEditingController(text: message['text']);
                                  final result = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('تعديل الرسالة'),
                                      content: TextField(controller: controller),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
                                        TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('حفظ')),
                                      ],
                                    ),
                                  );
                                  if (result != null && result.trim().isNotEmpty) {
                                    await _editMessage(messageKey, result.trim());
                                  }
                                } else if (selected == 'delete') {
                                  await _deleteMessage(messageKey);
                                } else if (selected == 'pin') {
                                  await _pinMessage(messageKey);
                                } else if (selected == 'unpin') {
                                  await _unpinMessage(messageKey);
                                }
                              },
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    FutureBuilder<String>(
                                      future: _fetchUsernameFromUid(message['sender']),
                                      builder: (context, usernameSnapshot) {
                                        return Container(
                                          margin: EdgeInsets.only(right: 8),
                                          child: Column(
                                            children: [
                                              FutureBuilder<String?>(
                                                future: _fetchUserPic(message['sender']),
                                                builder: (context, picSnapshot) {
                                                  final pic = picSnapshot.data;
                                                  return CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: colorScheme.primary,
                                                    backgroundImage: (pic != null && pic.isNotEmpty)
                                                        ? NetworkImage(pic)
                                                        : null,
                                                    child: (pic == null || pic.isEmpty)
                                                        ? Icon(
                                                            Icons.person,
                                                            color: colorScheme.onPrimary,
                                                            size: 20,
                                                          )
                                                        : null,
                                                  );
                                                },
                                              ),
                                              if (usernameSnapshot.hasData) ...[
                                                SizedBox(height: 4),
                                                Text(
                                                  '@${usernameSnapshot.data}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: message['profileTheme']?.isNotEmpty == true
                                                        ? Color(int.parse(message['profileTheme']))
                                                        : colorScheme.onSurface.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                UserBadges(userData: message, iconSize: 14),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isMe
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
                                          if (!isDeleted && message['replyTo'] != null) ...[
                                            Container(
                                              margin: EdgeInsets.only(bottom: 6, right: 2),
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primaryContainer.withValues(alpha: 0.18),
                                                border: Border(
                                                  right: BorderSide(color: colorScheme.primary, width: 4),
                                                ),
                                                borderRadius: BorderRadius.circular(7),
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(Icons.reply, size: 14, color: colorScheme.primary),
                                                  SizedBox(width: 6),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        FutureBuilder<String>(
                                                          future: _fetchUsernameFromUid(message['replyTo']['sender'] ?? ''),
                                                          builder: (context, snapshot) {
                                                            final username = snapshot.data ?? '';
                                                            return Text(
                                                              '@$username',
                                                              style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                                            );
                                                          },
                                                        ),
                                                        SizedBox(height: 2),
                                                        Text(
                                                          message['replyTo']['text'] ?? '',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if (isPinned)
                                            Row(
                                              children: [
                                                Icon(Icons.push_pin, size: 16, color: colorScheme.primary),
                                                SizedBox(width: 4),
                                                Text('مثبت', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                                              ],
                                            ),
                                          if (isDeleted)
                                            Text('تم حذف الرسالة', style: TextStyle(color: colorScheme.error, fontStyle: FontStyle.italic)),
                                          if (!isDeleted && message['text']?.isNotEmpty == true)
                                            _buildClickableText(message['text'], isMe),
                                          if (!isDeleted && message['imageUrl']?.isNotEmpty == true) ...[
                                            if (message['text']?.isNotEmpty == true) SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                message['imageUrl'],
                                                width: 200,
                                                height: 150,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 200,
                                                    height: 150,
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.surfaceContainerHighest,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.error_outline,
                                                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                          if (!isDeleted && message['audioUrl']?.isNotEmpty == true) ...[
                                            if (message['text']?.isNotEmpty == true || message['imageUrl']?.isNotEmpty == true) 
                                              SizedBox(height: 8),
                                            _buildVoiceMessageWidget(message['audioUrl'], isMe),
                                          ],
                                          if (!isDeleted && reactions.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Wrap(
                                                spacing: 8,
                                                children: [
                                                  ..._groupReactionsByEmoji(reactions).entries.map((entry) => FutureBuilder<List<String>>(
                                                    future: Future.wait(entry.value.map((uid) => _fetchUsernameFromUid(uid)).toList()),
                                                    builder: (context, snapshot) {
                                                      final usernames = snapshot.data ?? [];
                                                      return GestureDetector(
                                                        onTap: () async {
                                                          final user = FirebaseAuth.instance.currentUser;
                                                          if (user != null && entry.value.contains(user.uid)) {
                                                            await _removeReaction(messageKey);
                                                          } else {
                                                            await _addReaction(messageKey, entry.key);
                                                          }
                                                        },
                                                        child: Container(
                                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: colorScheme.primaryContainer,
                                                            borderRadius: BorderRadius.circular(16),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(entry.key, style: TextStyle(fontSize: 16)),
                                                              SizedBox(width: 4),
                                                              if (usernames.isNotEmpty)
                                                                Text('(${usernames.map((u) => '@$u').join(', ')})', style: TextStyle(fontSize: 12)),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  )),
                                                ],
                                              ),
                                            ),
                                          if (!isDeleted && isEdited)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text('تم التعديل', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                                            ),
                                          if (!isDeleted && message['gift'] != null) ...[
                                            FutureBuilder<DatabaseEvent>(
                                              future: FirebaseDatabase.instance.ref('streaks_store/items/${message['gift']}').once(),
                                              builder: (context, snap) {
                                                if (!snap.hasData || snap.data!.snapshot.value == null) {
                                                  return Container(
                                                    padding: EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.primaryContainer.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.card_giftcard, color: colorScheme.primary, size: 28),
                                                        SizedBox(width: 12),
                                                        Text('هدية', style: TextStyle(fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  );
                                                }
                                                final item = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Card(
                                                      color: colorScheme.primaryContainer.withOpacity(0.18),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(14),
                                                        child: Row(
                                                          children: [
                                                            Icon(_iconFromString(item['icon'], item['type']), color: colorScheme.primary, size: 32),
                                                            SizedBox(width: 12),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(item['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
                                                                  SizedBox(height: 4),
                                                                  Text(item['desc'] ?? '', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                                                ],
                                                              ),
                                                            ),
                                                            Chip(
                                                              label: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(Icons.bolt, color: Colors.amber, size: 16),
                                                                  SizedBox(width: 2),
                                                                  Text('${item['cost'] ?? 0}', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                                                ],
                                                              ),
                                                              backgroundColor: Colors.amber.withOpacity(0.1),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if ((message['giftClaimed'] != true) && message['sender'] != widget.currentUserUid)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 8.0),
                                                        child: OutlinedButton.icon(
                                                          style: OutlinedButton.styleFrom(
                                                            foregroundColor: colorScheme.primary,
                                                            side: BorderSide(color: colorScheme.primary),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                          ),
                                                          icon: Icon(Icons.card_giftcard, size: 18),
                                                          label: Text('استلام الهدية', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          onPressed: _isSending ? null : () async {
                                                            await _claimGift(message['key'], item);
                                                          },
                                                        ),
                                                      ),
                                                    if (message['giftClaimed'] == true)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 8.0),
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.card_giftcard, color: Colors.green, size: 20),
                                                            SizedBox(width: 8),
                                                            Text('تم استلام الهدية', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                                            if (message['giftClaimedBy'] != null && (message['giftClaimedBy'] as String).isNotEmpty) ...[
                                                              SizedBox(width: 8),
                                                              FutureBuilder<String>(
                                                                future: _fetchUsernameFromUid(message['giftClaimedBy']),
                                                                builder: (context, snapshot) {
                                                                  final username = snapshot.data;
                                                                  if (username == null) return SizedBox.shrink();
                                                                  return Text('(@$username)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                                                                },
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    if (isMe && seenBy.isNotEmpty)
                                                      FutureBuilder<List<String>>(
                                                        future: Future.wait(seenBy.map((uid) => _fetchUsernameFromUid(uid)).toList()),
                                                        builder: (context, snapshot) {
                                                          if (!snapshot.hasData) return SizedBox.shrink();
                                                          final usernames = snapshot.data!;
                                                          return Padding(
                                                            padding: const EdgeInsets.only(top: 2.0),
                                                            child: Text(
                                                              'تمت القراءة بواسطة: ${usernames.map((u) => '@$u').join(', ')}',
                                                              style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isMe) ...[
                                    SizedBox(width: 8),
                                    Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: colorScheme.secondary,
                                          child: Icon(
                                            Icons.person,
                                            color: colorScheme.onSecondary,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'أنت',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      }
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
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_replyToMessage != null)
                            Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        FutureBuilder<String>(
                                          future: _fetchUsernameFromUid(_replyToMessage!['sender'] ?? ''),
                                          builder: (context, snapshot) {
                                            final username = snapshot.data ?? '';
                                            return Row(
                                              children: [
                                                Icon(Icons.reply, size: 14, color: colorScheme.primary),
                                                SizedBox(width: 4),
                                                Text(
                                                  'رد على: @$username',
                                                  style: TextStyle(fontSize: 12, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          _replyToMessage!['text'] ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                    onPressed: () => setState(() => _replyToMessage = null),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.image,
                                  color: colorScheme.primary,
                                ),
                                onPressed: _isUploading ? null : () async {
                                  final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
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
                                      final shouldSend = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text('معاينة الصورة'),
                                          content: Image.memory(editedImage, fit: BoxFit.cover),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
                                            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('إرسال')),
                                          ],
                                        ),
                                      );
                                      if (shouldSend != true) return;
                                      final tempDir = await io.Directory.systemTemp.createTemp('edited_image');
                                      final tempFile = io.File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
                                      await tempFile.writeAsBytes(editedImage);
                                      Uint8List bytes = await tempFile.readAsBytes();
                                      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
                                      final uploaded = await StorageHelper.upload(FirebaseAuth.instance.currentUser!.uid, bytes, filename: fileName);
                                      final imageUrl = '$ashurStorageUrl?fileId=${uploaded.fileId}';
                                      await FirebaseDatabase.instance
                                          .ref('groups/${widget.groupId}/messages')
                                          .push()
                                          .set({
                                        'text': '',
                                        'imageUrl': imageUrl,
                                        'audioUrl': '',
                                        'sender': widget.currentUserUid,
                                        'timestamp': ServerValue.timestamp,
                                      });
                                      await tempFile.delete();
                                      await tempDir.delete();
                                      await triggerBotWebhooks(
                                        target: widget.groupId,
                                        senderUid: widget.currentUserUid,
                                        message: imageUrl,
                                        isGroup: true,
                                        action: 'message:image',
                                      );
                                    }
                                  }
                                },
                              ),
                              if (!kIsWeb) IconButton(
                                icon: Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: _isRecording ? Colors.red : colorScheme.primary,
                                ),
                                onPressed: _isRecording ? _stopRecording : _startRecording,
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
                                  child: CompositedTransformTarget(
                                    link: _mentionDropdownLink,
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _inputFocusNode,
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
                                  onPressed: _isSending
                                      ? null
                                      : () {
                                          if (_controller.text.trim().isNotEmpty) {
                                            _sendMessage(_controller.text);
                                          }
                                        },
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.card_giftcard,
                                  color: colorScheme.secondary,
                                ),
                                tooltip: 'إرسال هدية',
                                onPressed: _isSending ? null : _showGiftPicker,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 64,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'أنت لست عضواً في هذه المجموعة',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'انضم للمجموعة للبدء في المحادثة',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isJoining ? null : _joinGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isJoining
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                            ),
                          )
                        : Text(
                            'انضم للمجموعة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<String> _uploadGroupImage(io.File file) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final url = await UploadHelper.uploadFile(context, file, filename: fileName);
    if (url == null) throw Exception('Upload failed');
    return url;
  }

  Future<String> _uploadGroupAudio(io.File file) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final url = await UploadHelper.uploadFile(context, file, filename: fileName);
    if (url == null) throw Exception('Upload failed');
    return url;
  }

  Future<String> _getTempAudioPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
  }

  Future<void> _startRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تسجيل الصوت غير متاح على الويب')),
      );
      return;
    }
    try {
      final path = await _getTempAudioPath();
      await _recorder!.startRecorder(toFile: path);
      setState(() => _isRecording = true);
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (kIsWeb) return;
    try {
      String? audioPath = await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      if (audioPath != null) {
        final shouldSend = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => VoicePreviewDialog(audioPath: audioPath),
        );
        if (shouldSend == 'send') {
          await _sendAudio(audioPath);
        } else if (shouldSend == 're-record') {
          await _startRecording();
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _sendAudio(String audioPath) async {
    setState(() => _isUploading = true);
    try {
      io.File audioFile = io.File(audioPath);
      String audioUrl = await _uploadGroupAudio(audioFile);
      await FirebaseDatabase.instance
          .ref('groups/${widget.groupId}/messages')
          .push()
          .set({
        'text': '',
        'imageUrl': '',
        'audioUrl': audioUrl,
        'sender': widget.currentUserUid,
        'timestamp': ServerValue.timestamp,
      });
      await triggerBotWebhooks(
        target: widget.groupId,
        senderUid: widget.currentUserUid,
        message: audioUrl,
        isGroup: true,
        action: 'message:voice',
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Map<String, List<String>> _groupReactionsByEmoji(Map reactions) {
    final Map<String, List<String>> grouped = {};
    reactions.forEach((emoji, value) {
      if (value is String) {
        grouped.putIfAbsent(emoji, () => []).add(value);
      } else if (value is List) {
        grouped.putIfAbsent(emoji, () => []).addAll(value.whereType<String>());
      }
    });
    return grouped;
  }

  Future<void> _addReaction(String messageKey, String emoji) async {
    final ref = FirebaseDatabase.instance.ref('groups/${widget.groupId}/messages/$messageKey/reactions/$emoji');
    await ref.set(FirebaseAuth.instance.currentUser!.uid);
    await triggerBotWebhooks(
      target: widget.groupId,
      senderUid: widget.currentUserUid,
      message: emoji,
      isGroup: true,
      action: 'reaction:add',
    );
  }

  Future<void> _removeReaction(String messageKey) async {
    final ref = FirebaseDatabase.instance.ref('groups/${widget.groupId}/messages/$messageKey/reactions');
    await ref.remove();
    await triggerBotWebhooks(
      target: widget.groupId,
      senderUid: widget.currentUserUid,
      message: '',
      isGroup: true,
      action: 'reaction:remove',
    );
  }

  Future<void> _editMessage(String messageKey, String newText) async {
    final ref = FirebaseDatabase.instance.ref('groups/${widget.groupId}/messages/$messageKey');
    await ref.update({'text': newText, 'edited': true});
    await triggerBotWebhooks(
      target: widget.groupId,
      senderUid: widget.currentUserUid,
      message: newText,
      isGroup: true,
      action: 'message:edit',
    );
  }

  Future<void> _deleteMessage(String messageKey) async {
    final ref = FirebaseDatabase.instance.ref('groups/${widget.groupId}/messages/$messageKey');
    final snap = await ref.get();
    String deletedText = '';
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      deletedText = data['text'] ?? '';
    }
    await ref.update({'deleted': true});
    await triggerBotWebhooks(
      target: widget.groupId,
      senderUid: widget.currentUserUid,
      message: deletedText,
      isGroup: true,
      action: 'message:delete',
    );
  }

  Future<void> _pinMessage(String messageKey) async {
    final ref = FirebaseDatabase.instance.ref('groups/${widget.groupId}/messages/$messageKey/pinned');
    await ref.set(true);
    await triggerBotWebhooks(
      target: widget.groupId,
      senderUid: widget.currentUserUid,
      message: messageKey,
      isGroup: true,
      action: 'message:pin',
    );
  }

  Future<void> _unpinMessage(String messageKey) async {
    final ref = FirebaseDatabase.instance.ref('groups/${widget.groupId}/messages/$messageKey/pinned');
    await ref.remove();
    await triggerBotWebhooks(
      target: widget.groupId,
      senderUid: widget.currentUserUid,
      message: messageKey,
      isGroup: true,
      action: 'message:unpin',
    );
  }

  Widget _buildPinnedMessageWidget(Map message) {
    final colorScheme = Theme.of(context).colorScheme;
    final isMe = message['sender'] == widget.currentUserUid;
    final reactions = message['reactions'] ?? {};
    final isDeleted = message['deleted'] == true;
    final isEdited = message['edited'] == true;
    final isPinned = message['pinned'] == true;
    final seenBy = (message['seenBy'] as List?) ?? [];

    return GestureDetector(
      onLongPressStart: (details) async {
        final selected = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx + 1,
            details.globalPosition.dy + 1,
          ),
          items: [
            PopupMenuItem(value: 'react', child: Text('تفاعل')),
            if (isMe && !isDeleted) PopupMenuItem(value: 'edit', child: Text('تعديل')),
            if (isMe && !isDeleted) PopupMenuItem(value: 'delete', child: Text('حذف')),
            if (isMe && !isDeleted && isPinned) PopupMenuItem(value: 'unpin', child: Text('إلغاء التثبيت')),
          ],
        );
        if (selected == 'react') {
          final emoji = await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(
              details.globalPosition.dx,
              details.globalPosition.dy + 40,
              details.globalPosition.dx + 1,
              details.globalPosition.dy + 41,
            ),
            items: [
              PopupMenuItem(value: '👍', child: Text('👍')),
              PopupMenuItem(value: '❤️', child: Text('❤️')),
              PopupMenuItem(value: '😂', child: Text('😂')),
              PopupMenuItem(value: '🔥', child: Text('🔥')),
              PopupMenuItem(value: '😮', child: Text('😮')),
              PopupMenuItem(value: '🙏', child: Text('🙏')),
            ],
          );
          if (emoji != null) {
            await _addReaction(message['key'], emoji);
          }
        } else if (selected == 'edit') {
          final controller = TextEditingController(text: message['text']);
          final result = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('تعديل الرسالة'),
              content: TextField(controller: controller),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
                TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text('حفظ')),
              ],
            ),
          );
          if (result != null && result.trim().isNotEmpty) {
            await _editMessage(message['key'], result.trim());
          }
        } else if (selected == 'delete') {
          await _deleteMessage(message['key']);
        } else if (selected == 'unpin') {
          await _unpinMessage(message['key']);
        }
      },
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            FutureBuilder<String>(
              future: _fetchUsernameFromUid(message['sender']),
              builder: (context, usernameSnapshot) {
                return Container(
                  margin: EdgeInsets.only(right: 8),
                  child: Column(
                    children: [
                      FutureBuilder<String?>(
                        future: _fetchUserPic(message['sender']),
                        builder: (context, picSnapshot) {
                          final pic = picSnapshot.data;
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primary,
                            backgroundImage: (pic != null && pic.isNotEmpty)
                                ? NetworkImage(pic)
                                : null,
                            child: (pic == null || pic.isEmpty)
                                ? Icon(
                                    Icons.person,
                                    color: colorScheme.onPrimary,
                                    size: 20,
                                  )
                                : null,
                          );
                        },
                      ),
                      if (usernameSnapshot.hasData) ...[
                        SizedBox(height: 4),
                        Text(
                          '@${usernameSnapshot.data}',
                          style: TextStyle(
                            fontSize: 10,
                            color: message['profileTheme']?.isNotEmpty == true
                                ? Color(int.parse(message['profileTheme']))
                                : colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        SizedBox(width: 4),
                        UserBadges(userData: Map<String, dynamic>.from(message), iconSize: 14),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe
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
                  if (!isDeleted && message['replyTo'] != null) ...[
                    Container(
                      margin: EdgeInsets.only(bottom: 6, right: 2),
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.18),
                        border: Border(
                          right: BorderSide(color: colorScheme.primary, width: 4),
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.reply, size: 14, color: colorScheme.primary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder<String>(
                                  future: _fetchUsernameFromUid(message['replyTo']['sender'] ?? ''),
                                  builder: (context, snapshot) {
                                    final username = snapshot.data ?? '';
                                    return Text(
                                      '@$username',
                                      style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                    );
                                  },
                                ),
                                SizedBox(height: 2),
                                Text(
                                  message['replyTo']['text'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isPinned)
                    Row(
                      children: [
                        Icon(Icons.push_pin, size: 16, color: colorScheme.primary),
                        SizedBox(width: 4),
                        Text('مثبت', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                      ],
                    ),
                  if (isDeleted)
                    Text('تم حذف الرسالة', style: TextStyle(color: colorScheme.error, fontStyle: FontStyle.italic)),
                  if (!isDeleted && message['text']?.isNotEmpty == true)
                    _buildClickableText(message['text'], isMe),
                  if (!isDeleted && message['imageUrl']?.isNotEmpty == true) ...[
                    if (message['text']?.isNotEmpty == true) SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message['imageUrl'],
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 150,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.error_outline,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (!isDeleted && message['audioUrl']?.isNotEmpty == true) ...[
                    if (message['text']?.isNotEmpty == true || message['imageUrl']?.isNotEmpty == true) 
                      SizedBox(height: 8),
                    _buildVoiceMessageWidget(message['audioUrl'], isMe),
                  ],
                  if (!isDeleted && reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          ..._groupReactionsByEmoji(reactions).entries.map((entry) => FutureBuilder<List<String>>(
                            future: Future.wait(entry.value.map((uid) => _fetchUsernameFromUid(uid)).toList()),
                            builder: (context, snapshot) {
                              final usernames = snapshot.data ?? [];
                              return GestureDetector(
                                onTap: () async {
                                  final user = FirebaseAuth.instance.currentUser;
                                  if (user != null && entry.value.contains(user.uid)) {
                                    await _removeReaction(message['key']);
                                  } else {
                                    await _addReaction(message['key'], entry.key);
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(entry.key, style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 4),
                                      if (usernames.isNotEmpty)
                                        Text('(${usernames.map((u) => '@$u').join(', ')})', style: TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )),
                        ],
                      ),
                    ),
                  if (!isDeleted && isEdited)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('تم التعديل', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                    ),
                  if (!isDeleted && message['gift'] != null) ...[
                    FutureBuilder<DatabaseEvent>(
                      future: FirebaseDatabase.instance.ref('streaks_store/items/${message['gift']}').once(),
                      builder: (context, snap) {
                        if (!snap.hasData || snap.data!.snapshot.value == null) {
                          return Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.card_giftcard, color: colorScheme.primary, size: 28),
                                SizedBox(width: 12),
                                Text('هدية', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }
                        final item = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              color: colorScheme.primaryContainer.withOpacity(0.18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(_iconFromString(item['icon'], item['type']), color: colorScheme.primary, size: 32),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
                                          SizedBox(height: 4),
                                          Text(item['desc'] ?? '', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.bolt, color: Colors.amber, size: 16),
                                          SizedBox(width: 2),
                                          Text('${item['cost'] ?? 0}', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      backgroundColor: Colors.amber.withOpacity(0.1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if ((message['giftClaimed'] != true) && message['sender'] != widget.currentUserUid)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colorScheme.primary,
                                    side: BorderSide(color: colorScheme.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  icon: Icon(Icons.card_giftcard, size: 18),
                                  label: Text('استلام الهدية', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: _isSending ? null : () async {
                                    await _claimGift(message['key'], item);
                                  },
                                ),
                              ),
                            if (message['giftClaimed'] == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.card_giftcard, color: Colors.green, size: 20),
                                    SizedBox(width: 8),
                                    Text('تم استلام الهدية', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    if (message['giftClaimedBy'] != null && (message['giftClaimedBy'] as String).isNotEmpty) ...[
                                      SizedBox(width: 8),
                                      FutureBuilder<String>(
                                        future: _fetchUsernameFromUid(message['giftClaimedBy']),
                                        builder: (context, snapshot) {
                                          final username = snapshot.data;
                                          if (username == null) return SizedBox.shrink();
                                          return Text('(@$username)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            if (isMe && seenBy.isNotEmpty)
                              FutureBuilder<List<String>>(
                                future: Future.wait(seenBy.map((uid) => _fetchUsernameFromUid(uid)).toList()),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return SizedBox.shrink();
                                  final usernames = snapshot.data!;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text(
                                      'تمت القراءة بواسطة: ${usernames.map((u) => '@$u').join(', ')}',
                                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 8),
            Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.secondary,
                  child: Icon(
                    Icons.person,
                    color: colorScheme.onSecondary,
                    size: 20,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'أنت',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadGiftItems() async {
    setState(() { _loadingGifts = true; });
    final ref = FirebaseDatabase.instance.ref('streaks_store/items');
    final snap = await ref.get();
    List<Map<String, dynamic>> items = [];
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      data.forEach((key, value) {
        final item = Map<String, dynamic>.from(value as Map);
        item['id'] = key;
        items.add(item);
      });
    }
    setState(() {
      _giftItems = items;
      _loadingGifts = false;
    });
  }

  Future<void> _showGiftPicker() async {
    await _loadGiftItems();
    if (_giftItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا توجد هدايا متاحة حالياً')));
      return;
    }
    final colorScheme = Theme.of(context).colorScheme;
    Map<String, dynamic>? selectedGift;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('اختر هدية لإرسالها'),
          content: SizedBox(
            width: 350,
            height: 400,
            child: _loadingGifts
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _giftItems.length,
                    itemBuilder: (context, idx) {
                      final item = _giftItems[idx];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: Icon(_iconFromString(item['icon'], item['type']), color: colorScheme.primary, size: 32),
                          title: Text(item['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item['desc'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, color: Colors.amber, size: 16),
                                SizedBox(width: 2),
                                Text('${item['cost'] ?? 0}', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            backgroundColor: Colors.amber.withOpacity(0.1),
                          ),
                          onTap: () {
                            selectedGift = item;
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
    if (selectedGift != null) {
      setState(() {
        _selectedGift = selectedGift!['id'];
      });
      _sendGiftMessage(selectedGift!);
    }
  }

  Future<void> _sendGiftMessage(Map<String, dynamic> giftItem) async {
    if (!_isMember) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    final spentRef = FirebaseDatabase.instance.ref('users/${user.uid}/spentStreaks');
    final snap = await userRef.child('streaks').get();
    int streaks = 0;
    if (snap.exists && snap.value != null) streaks = (snap.value as num).toInt();
    final cost = giftItem['cost'] ?? 0;
    if (streaks < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ليس لديك عدد كافٍ من الستريكس لإرسال هذه الهدية')),
      );
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await userRef.update({'streaks': streaks - cost});
    await spentRef.push().set({'item': giftItem['id'], 'cost': cost, 'ts': now, 'giftedTo': 'group:${widget.groupId}'});
    final messageData = {
      'text': '',
      'audioUrl': '',
      'imageUrl': '',
      'sender': widget.currentUserUid,
      'timestamp': ServerValue.timestamp,
      'replyTo': _replyToMessage,
      'gift': giftItem['id'],
      'giftClaimed': false,
      'giftClaimedBy': null,
    };
    setState(() => _isSending = true);
    try {
      await FirebaseDatabase.instance
          .ref('groups/${widget.groupId}/messages')
          .push()
          .set(messageData);
      setState(() {
        _replyToMessage = null;
        _selectedGift = null;
      });
      await triggerBotWebhooks(
        target: widget.groupId,
        senderUid: widget.currentUserUid,
        message: giftItem['id']?.toString() ?? '',
        isGroup: true,
        action: 'message:gift',
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _claimGift(String messageKey, Map<String, dynamic> giftItem) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    final userKey = giftItem['userKey'] ?? giftItem['id'];
    final userValue = giftItem.containsKey('userValue') ? giftItem['userValue'] : true;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (giftItem['type'] == 'subscription') {
      final duration = (giftItem['durationDays'] ?? 30) as int;
      final expiry = now + duration * 24 * 60 * 60 * 1000;
      await userRef.update({userKey: expiry});
      if (giftItem['syncKey'] != null) {
        await userRef.update({giftItem['syncKey']: true});
      }
    } else {
      await userRef.update({userKey: userValue});
    }
    await FirebaseDatabase.instance
      .ref('groups/${widget.groupId}/messages/$messageKey')
      .update({'giftClaimed': true, 'giftClaimedBy': user.uid});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم استلام الهدية!'), backgroundColor: Colors.green),
    );
  }
}

Future<String?> _fetchUserPic(String uid) async {
  final userRef = FirebaseDatabase.instance.ref('users/$uid');
  final snapshot = await userRef.get();
  if (snapshot.exists) {
    final userData = snapshot.value as Map<dynamic, dynamic>;
    return userData['pic'] as String?;
  }
  return null;
}

const Map<String, IconData> _iconMap = {
  'verified': Icons.verified,
  'code': Icons.code,
  'star': Icons.star,
  'color': Icons.color_lens,
  'gift': Icons.card_giftcard,
  'bolt': Icons.bolt,
  'crown': Icons.emoji_events,
  'analytics': Icons.analytics,
};

IconData _iconFromString(String? icon, String? type) {
  if (icon != null && _iconMap.containsKey(icon)) {
    return _iconMap[icon]!;
  }
  if (type == 'flag') return Icons.verified;
  if (type == 'code') return Icons.code;
  return Icons.card_giftcard;
}

class VoicePreviewDialog extends StatefulWidget {
  final String audioPath;
  const VoicePreviewDialog({super.key, required this.audioPath});
  @override
  State<VoicePreviewDialog> createState() => _VoicePreviewDialogState();
}

class _VoicePreviewDialogState extends State<VoicePreviewDialog> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
    });
  }
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.audioPath));
      setState(() => _isPlaying = true);
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('معاينة الرسالة الصوتية'),
      content: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlay,
          ),
          Text(_isPlaying ? 'جاري التشغيل...' : 'اضغط للتشغيل'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 're-record'),
          child: Text('إعادة التسجيل'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'send'),
          child: Text('إرسال'),
        ),
      ],
    );
  }
}

Future<void> _markMessagesAsSeen(groupId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final ref = FirebaseDatabase.instance.ref('groups/$groupId/messages');
  final snap = await ref.get();
  if (snap.exists && snap.value != null) {
    final data = snap.value as Map<dynamic, dynamic>;
    for (final entry in data.entries) {
      final msg = Map<String, dynamic>.from(entry.value as Map);
      if (msg['sender'] != user.uid) {
        final seenBy = (msg['seenBy'] as List?) ?? [];
        if (!seenBy.contains(user.uid)) {
          await ref.child(entry.key).update({'seenBy': [...seenBy, user.uid]});
        }
      }
    }
  }
}

class _MatchSpan {
  final int start;
  final int end;
  final String type;
  final String text;
  _MatchSpan(this.start, this.end, this.type, this.text);
}