import 'package:ashur/secrets.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:ashur/storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../user_badges.dart';
import '../bot_webhook.dart';

String _encodeUidForPath(String? uid) {
  if (uid == null) return '';
  return uid.replaceAll('.', '_dot_').replaceAll('@', '_at_').replaceAll('#', '_hash_').replaceAll('\$', '_dollar_').replaceAll('[', '_lbracket_').replaceAll(']', '_rbracket_').replaceAll('/', '_slash_');
}

class ChatScreen extends StatelessWidget {
  final String targetUserEmail;
  final String currentUserEmail;

  const ChatScreen({
    super.key,
    required this.targetUserEmail,
    required this.currentUserEmail,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('users/${_encodeUidForPath(targetUserEmail)}')
                .onValue,
            builder: (context, snapshot) {
              Map<String, dynamic> userData = {};
              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                userData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
              }
              List blockedUsers = List.from(userData['blockedUsers'] ?? []);
              bool isBlocked = blockedUsers.contains(currentUserEmail);
              return AppBar(
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: userData['pic']?.isNotEmpty == true
                          ? NetworkImage(userData['pic'])
                          : AssetImage('images/ashur.png') as ImageProvider,
                      radius: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            userData['name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 18,
                              color: userData['profileTheme']?.isNotEmpty == true
                                  ? Color(int.parse(userData['profileTheme']))
                                  : colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(width: 6),
                          UserBadges(userData: userData, iconSize: 16),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'block') {
                          final ref = FirebaseDatabase.instance.ref('users/$currentUserEmail');
                          final snap = await ref.get();
                          final map = snap.value is Map ? Map<String, dynamic>.from(snap.value as Map) : <String, dynamic>{};
                          List blocked = List.from(map['blockedUsers'] ?? []);
                          if (!blocked.contains(targetUserEmail)) blocked.add(targetUserEmail);
                          await ref.update({'blockedUsers': blocked});
                          Navigator.of(context).pop();
                        } else if (value == 'unblock') {
                          final ref = FirebaseDatabase.instance.ref('users/$currentUserEmail');
                          final snap = await ref.get();
                          final map = snap.value is Map ? Map<String, dynamic>.from(snap.value as Map) : <String, dynamic>{};
                          List blocked = List.from(map['blockedUsers'] ?? []);
                          blocked.remove(targetUserEmail);
                          await ref.update({'blockedUsers': blocked});
                          Navigator.of(context).pop();
                        } else if (value == 'report') {
                          await FirebaseDatabase.instance.ref('reports').push().set({'reported': targetUserEmail, 'by': currentUserEmail, 'timestamp': DateTime.now().millisecondsSinceEpoch});
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الإبلاغ عن المستخدم')));
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: 'block', child: Text('حظر')),
                        PopupMenuItem(value: 'unblock', child: Text('إلغاء الحظر')),
                        PopupMenuItem(value: 'report', child: Text('إبلاغ')),
                      ],
                    ),
                  ],
                ),
                backgroundColor: colorScheme.surface,
                elevation: 0,
                centerTitle: true,
              );
            },
          ),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/${_encodeUidForPath(currentUserEmail)}').onValue,
        builder: (context, snapshot) {
          List blocked = [];
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            blocked = List.from((snapshot.data!.snapshot.value as Map)['blockedUsers'] ?? []);
          }
          if (blocked.contains(targetUserEmail)) {
            return Center(child: Text('لقد قمت بحظر هذا المستخدم'));
          }
          return ChatBody(
            currentUserEmail: currentUserEmail,
            targetUserEmail: targetUserEmail,
          );
        },
      ),
    );
  }
}

class _ChatScreenContent extends StatelessWidget {
  final String targetUserEmail;
  final String currentUserEmail;
  const _ChatScreenContent({
    required this.targetUserEmail,
    required this.currentUserEmail,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('users/${_encodeUidForPath(targetUserEmail)}')
          .onValue,
      builder: (context, targetSnapshot) {
        Map<String, dynamic> targetUserData = {};
        if (targetSnapshot.hasData && targetSnapshot.data!.snapshot.value != null) {
          targetUserData = Map<String, dynamic>.from(targetSnapshot.data!.snapshot.value as Map);
        }
        List blockedUsers = List.from(targetUserData['blockedUsers'] ?? []);
        bool isBlocked = blockedUsers.contains(currentUserEmail);
        if (isBlocked) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            appBar: AppBar(
              backgroundColor: colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text('الدردشة'),
              centerTitle: true,
            ),
            body: Center(
              child: Text('لقد تم حظرك من قبل هذا المستخدم',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 18)),
            ),
          );
        }
        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: SafeArea(
              child: StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('users/${_encodeUidForPath(targetUserEmail)}')
                    .onValue,
                builder: (context, snapshot) {
                  Map<String, dynamic> userData = {};
                  if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                    userData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
                  }
                  List blockedUsers = List.from(userData['blockedUsers'] ?? []);
                  bool isBlocked = blockedUsers.contains(currentUserEmail);
                  return AppBar(
                    leading: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    title: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: userData['pic']?.isNotEmpty == true
                              ? NetworkImage(userData['pic'])
                              : AssetImage('images/ashur.png') as ImageProvider,
                          radius: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                userData['name'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 18,
                                  color: userData['profileTheme']?.isNotEmpty == true
                                      ? Color(int.parse(userData['profileTheme']))
                                      : colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(width: 6),
                              UserBadges(userData: userData, iconSize: 16),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'block') {
                              final ref = FirebaseDatabase.instance.ref('users/$currentUserEmail');
                              final snap = await ref.get();
                              final map = snap.value is Map ? Map<String, dynamic>.from(snap.value as Map) : <String, dynamic>{};
                              List blocked = List.from(map['blockedUsers'] ?? []);
                              if (!blocked.contains(targetUserEmail)) blocked.add(targetUserEmail);
                              await ref.update({'blockedUsers': blocked});
                              Navigator.of(context).pop();
                            } else if (value == 'unblock') {
                              final ref = FirebaseDatabase.instance.ref('users/$currentUserEmail');
                              final snap = await ref.get();
                              final map = snap.value is Map ? Map<String, dynamic>.from(snap.value as Map) : <String, dynamic>{};
                              List blocked = List.from(map['blockedUsers'] ?? []);
                              blocked.remove(targetUserEmail);
                              await ref.update({'blockedUsers': blocked});
                              Navigator.of(context).pop();
                            } else if (value == 'report') {
                              await FirebaseDatabase.instance.ref('reports').push().set({'reported': targetUserEmail, 'by': currentUserEmail, 'timestamp': DateTime.now().millisecondsSinceEpoch});
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الإبلاغ عن المستخدم')));
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'block', child: Text('حظر')),
                            PopupMenuItem(value: 'unblock', child: Text('إلغاء الحظر')),
                            PopupMenuItem(value: 'report', child: Text('إبلاغ')),
                          ],
                        ),
                      ],
                    ),
                    backgroundColor: colorScheme.surface,
                    elevation: 0,
                    centerTitle: true,
                  );
                },
              ),
            ),
          ),
          body: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('users/${_encodeUidForPath(currentUserEmail)}').onValue,
            builder: (context, snapshot) {
              List blocked = [];
              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                blocked = List.from((snapshot.data!.snapshot.value as Map)['blockedUsers'] ?? []);
              }
              if (blocked.contains(targetUserEmail)) {
                return Center(child: Text('لقد قمت بحظر هذا المستخدم'));
              }
              return ChatBody(
                currentUserEmail: currentUserEmail,
                targetUserEmail: targetUserEmail,
              );
            },
          ),
        );
      },
    );
  }
}

class ChatBody extends StatefulWidget {
  final String targetUserEmail;
  final String currentUserEmail;
  const ChatBody({
    super.key,
    required this.targetUserEmail,
    required this.currentUserEmail,
  });
  @override
  State<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<ChatBody> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isSending = false;
  bool _isUploading = false;
  AudioPlayer? _audioPlayer;
  String? _currentlyPlayingAudioUrl;
  bool _isPlaying = false;
  String? _selectedGift;
  List<Map<String, dynamic>> _giftItems = [];
  bool _loadingGifts = false;
  static const Map<String, IconData> _iconMap = {
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

  String get chatId {
    var emails = [widget.currentUserEmail, widget.targetUserEmail];
    emails.sort();
    return '${emails[0]}-${emails[1]}';
  }

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _audioPlayer = AudioPlayer();
    _initRecorder();
    _loadGiftItems();
    _markMessagesAsSeen();
  }

  Future<void> _markMessagesAsSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('chats/$chatId/messages');
    final snap = await ref.get();
    if (snap.exists && snap.value != null) {
      final data = snap.value as Map<dynamic, dynamic>;
      for (final entry in data.entries) {
        final msg = Map<String, dynamic>.from(entry.value as Map);
        if (msg['sender'] != user.email) {
          final seenBy = (msg['seenBy'] as List?) ?? [];
          if (!seenBy.contains(user.email)) {
            await ref.child(entry.key).update({'seenBy': [...seenBy, user.email]});
          }
        }
      }
    }
  }

  Future<void> _initRecorder() async {
    if (!kIsWeb) {
      await _recorder!.openRecorder();
      await Permission.microphone.request();
    }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _audioPlayer?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<String> _getUsernameFromUid(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid');
    final snap = await ref.get();
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      return data['username'] ?? uid;
    }
    return uid;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final replyTo = null;
    setState(() => _isSending = true);
    try {
      await FirebaseDatabase.instance.ref('chats/$chatId/messages').push().set({
        'text': text.trim(),
        'audioUrl': '',
        'imageUrl': '',
        'sender': widget.currentUserEmail,
        'timestamp': ServerValue.timestamp,
        'reactions': {},
        'edited': false,
        'editedAt': 0,
        'deleted': false,
        'deletedAt': 0,
        'pinned': false,
        'pinnedAt': 0,
        'replyTo': replyTo,
      });
      await incrementChallengeProgress('إرسال رسالة');
      _controller.clear();
      if (widget.currentUserEmail != widget.targetUserEmail) {
        final senderUsername = await _getUsernameFromUid(widget.currentUserEmail);
        await sendNotificationToUser(widget.targetUserEmail, title: '@$senderUsername', body: text.trim());
      }
      await triggerBotWebhooks(
        target: chatId,
        senderUid: widget.currentUserEmail,
        message: text.trim(),
        isGroup: false,
        action: 'message:send',
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _handleGroupInvite(String groupId) async {
    try {
      final groupRef = FirebaseDatabase.instance.ref('groups/$groupId');
      final snapshot = await groupRef.get();
      
      if (snapshot.exists) {
        final groupData = snapshot.value as Map<dynamic, dynamic>;
        final members = List<dynamic>.from(groupData['members'] as List<dynamic>? ?? []);
        
        if (!members.contains(widget.currentUserEmail)) {
          members.add(widget.currentUserEmail);
          await groupRef.update({'members': members});
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم الانضمام إلى المجموعة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('أنت بالفعل عضو في هذه المجموعة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('المجموعة غير موجودة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الانضمام إلى المجموعة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      io.File imageFile = io.File(pickedFile.path);
      Uint8List? editedImage;
      if (!kIsWeb) {
        final imageBytes = await imageFile.readAsBytes();
        editedImage = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageEditor(
              image: imageBytes,
            ),
          ),
        );
      } else {
        editedImage = await pickedFile.readAsBytes();
      }
      if (editedImage != null) {
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('معاينة الصورة'),
            content: Image.memory(editedImage!, fit: BoxFit.cover),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('إرسال')),
            ],
          ),
        );
        if (shouldSend == true) {
          final tempDir = await io.Directory.systemTemp.createTemp('edited_image');
          final tempFile = io.File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(editedImage);
          setState(() => _isUploading = true);
          try {
            String imageUrl;
            if (kIsWeb) {
              Uint8List bytes = await pickedFile.readAsBytes();
              String fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
              final uploaded = await StorageHelper.upload(FirebaseAuth.instance.currentUser!.uid, bytes, filename: fileName);
              imageUrl = '$ashurStorageUrl?fileId=${uploaded.fileId}';
            } else {
              final uploadedTemp = await StorageHelper.upload(FirebaseAuth.instance.currentUser!.uid, await tempFile.readAsBytes(), filename: '${DateTime.now().millisecondsSinceEpoch}_${Uuid().v4()}.jpg');
              imageUrl = '$ashurStorageUrl?fileId=${uploadedTemp.fileId}';
            }
            await FirebaseDatabase.instance.ref('chats/$chatId/messages').push().set({
              'text': '',
              'imageUrl': imageUrl,
              'audioUrl': '',
              'sender': widget.currentUserEmail,
              'timestamp': ServerValue.timestamp,
            });
            await triggerBotWebhooks(
              target: chatId,
              senderUid: widget.currentUserEmail,
              message: imageUrl,
              isGroup: false,
              action: 'message:image',
            );
          } finally {
            setState(() => _isUploading = false);
            await tempFile.delete();
            await tempDir.delete();
          }
        }
      }
    }
  }

  Future<String> _uploadFile(io.File file) async {
    final bytes = await file.readAsBytes();
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final uploaded = await StorageHelper.upload(user.uid, bytes, filename: fileName);
    final proxyUrl = '$ashurStorageUrl?fileId=${uploaded.fileId}';
    return proxyUrl;
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
      String audioUrl = await _uploadAudioFile(audioFile);
      await FirebaseDatabase.instance.ref('chats/$chatId/messages').push().set({
        'text': '',
        'imageUrl': '',
        'audioUrl': audioUrl,
        'sender': widget.currentUserEmail,
        'timestamp': ServerValue.timestamp,
      });
      if (widget.currentUserEmail != widget.targetUserEmail) {
        await sendNotificationToUser(widget.targetUserEmail, title: 'رسالة صوتية جديدة', body: 'لديك رسالة صوتية جديدة من الدردشة');
      }
      await triggerBotWebhooks(
        target: chatId,
        senderUid: widget.currentUserEmail,
        message: audioUrl,
        isGroup: false,
        action: 'message:voice',
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<String> _uploadAudioFile(io.File file) async {
    final bytes = await file.readAsBytes();
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    final uploaded = await StorageHelper.upload(user.uid, bytes, filename: fileName);
    final proxyUrl = '$ashurStorageUrl?fileId=${uploaded.fileId}';
    return proxyUrl;
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
      print('Error playing audio: $e');
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
    final hasUrls = urlRegex.hasMatch(text) || groupRegex.hasMatch(text);
    if (!hasUrls) {
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
    List<RegExpMatch> allMatches = [];
    allMatches.addAll(urlRegex.allMatches(text));
    allMatches.addAll(groupRegex.allMatches(text));
    allMatches.sort((a, b) => a.start.compareTo(b.start));
    int lastIndex = 0;
    for (final match in allMatches) {
      if (match.start > lastIndex) {
        widgets.add(MarkdownBody(
          data: remainingText.substring(lastIndex, match.start),
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: TextStyle(
              color: isMe
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
            ),
          ),
        ));
      }
      
      
      final linkText = match.group(0)!;  
      if (linkText.startsWith('group://')) {
        final groupId = linkText.replaceAll('group://', '');
        widgets.add(_buildGroupInviteWidget(groupId, isMe));
      } else {
        widgets.add(
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(linkText);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: MarkdownBody(
              data: linkText,
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
      }
      
      lastIndex = match.end;
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

  Future<void> _addReaction(String messageKey, String emoji) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('chats/$chatId/messages/$messageKey/reactions');
    await ref.update({user.uid: emoji});
    await triggerBotWebhooks(
      target: chatId,
      senderUid: widget.currentUserEmail,
      message: emoji,
      isGroup: false,
      action: 'reaction:add',
    );
  }
  Future<void> _removeReaction(String messageKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('chats/$chatId/messages/$messageKey/reactions/${user.uid}');
    await ref.remove();
    await triggerBotWebhooks(
      target: chatId,
      senderUid: widget.currentUserEmail,
      message: '',
      isGroup: false,
      action: 'reaction:remove',
    );
  }
  Future<void> _editMessage(String messageKey, String newText) async {
    final ref = FirebaseDatabase.instance.ref('chats/$chatId/messages/$messageKey');
    await ref.update({'text': newText, 'edited': true, 'editedAt': ServerValue.timestamp});
    await triggerBotWebhooks(
      target: chatId,
      senderUid: widget.currentUserEmail,
      message: newText,
      isGroup: false,
      action: 'message:edit',
    );
  }
  Future<void> _deleteMessage(String messageKey) async {
    final ref = FirebaseDatabase.instance.ref('chats/$chatId/messages/$messageKey');
    final snap = await ref.get();
    String deletedText = '';
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      deletedText = data['text'] ?? '';
    }
    await ref.update({'deleted': true, 'deletedAt': ServerValue.timestamp});
    await triggerBotWebhooks(
      target: chatId,
      senderUid: widget.currentUserEmail,
      message: deletedText,
      isGroup: false,
      action: 'message:delete',
    );
  }
  Future<void> _pinMessage(String messageKey) async {
    final ref = FirebaseDatabase.instance.ref('chats/$chatId/messages/$messageKey');
    await ref.update({'pinned': true, 'pinnedAt': ServerValue.timestamp});
    await triggerBotWebhooks(
      target: chatId,
      senderUid: widget.currentUserEmail,
      message: messageKey,
      isGroup: false,
      action: 'message:pin',
    );
  }
  Future<void> _unpinMessage(String messageKey) async {
    final ref = FirebaseDatabase.instance.ref('chats/$chatId/messages/$messageKey');
    await ref.update({'pinned': false, 'pinnedAt': 0});
    await triggerBotWebhooks(
      target: chatId,
      senderUid: widget.currentUserEmail,
      message: messageKey,
      isGroup: false,
      action: 'message:unpin',
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
      .ref('chats/$chatId/messages/$messageKey')
      .update({'giftClaimed': true, 'giftClaimedBy': user.uid});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم استلام الهدية!'), backgroundColor: Colors.green),
    );
  }

  Future<void> _sendGiftMessage(Map<String, dynamic> giftItem) async {
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
    await spentRef.push().set({'item': giftItem['id'], 'cost': cost, 'ts': now, 'giftedTo': 'dm:${widget.targetUserEmail}'});
    final messageData = {
      'text': '',
      'audioUrl': '',
      'imageUrl': '',
      'sender': widget.currentUserEmail,
      'timestamp': ServerValue.timestamp,
      'gift': giftItem['id'],
      'giftClaimed': false,
      'giftClaimedBy': null,
    };
    setState(() => _isSending = true);
    try {
      await FirebaseDatabase.instance
          .ref('chats/$chatId/messages')
          .push()
          .set(messageData);
      setState(() {
        _selectedGift = null;
      });
      await triggerBotWebhooks(
        target: chatId,
        senderUid: widget.currentUserEmail,
        message: giftItem['id']?.toString() ?? '',
        isGroup: false,
        action: 'message:gift',
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('chats/$chatId/messages')
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

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: allMessages.length,
                itemBuilder: (context, index) {
                  final message = allMessages[index];
                  final isMe = message['sender'] == widget.currentUserEmail;
                  final messageKey = message['key'];
                  final reactions = message['reactions'] ?? {};
                  final isDeleted = message['deleted'] == true;
                  final isEdited = message['edited'] == true;
                  final isPinned = message['pinned'] == true;

                  return GestureDetector(
                    onLongPress: () async {
                      final selected = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromLTRB(100, 100, 0, 0),
                        items: [
                          PopupMenuItem(value: 'react', child: Text('تفاعل')),
                          if (isMe && !isDeleted) PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          if (isMe && !isDeleted) PopupMenuItem(value: 'delete', child: Text('حذف')),
                          if (isMe && !isDeleted && !isPinned) PopupMenuItem(value: 'pin', child: Text('تثبيت')),
                          if (isMe && !isDeleted && isPinned) PopupMenuItem(value: 'unpin', child: Text('إلغاء التثبيت')),
                        ],
                      );
                      if (selected == 'react') {
                        final emoji = await showMenu<String>(
                          context: context,
                          position: RelativeRect.fromLTRB(100, 200, 0, 0),
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
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.primary,
                              child: Icon(
                                Icons.person,
                                color: colorScheme.onPrimary,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 8),
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
                                          ..._groupReactions(reactions).entries.map((entry) => GestureDetector(
                                            onTap: () async {
                                              final user = FirebaseAuth.instance.currentUser;
                                              if (user != null && reactions[user.uid] == entry.key) {
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
                                                  Text(entry.value.toString(), style: TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          )),
                                        ],
                                      ),
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
                                            if ((message['giftClaimed'] != true) && message['sender'] != widget.currentUserEmail)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: OutlinedButton.icon(
                                                  onPressed: _isSending ? null : () async {
                                                    await _claimGift(message['key'], item);
                                                  },
                                                  icon: Icon(Icons.card_giftcard, size: 18),
                                                  label: Text('استلام الهدية', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: colorScheme.primary,
                                                    side: BorderSide(color: colorScheme.primary),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  ),
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
                                                        future: _getUsernameFromUid(message['giftClaimedBy']),
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
                                  if (!isDeleted && isEdited)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text('تم التعديل', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: colorScheme.secondary,
                              child: Icon(
                                Icons.person,
                                color: colorScheme.onSecondary,
                                size: 20,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
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
                onPressed: _isUploading ? null : _sendImage,
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
        ),
      ],
    );
  }
}

Map<String, int> _groupReactions(Map reactions) {
  final Map<String, int> grouped = {};
  reactions.forEach((_, emoji) {
    grouped[emoji] = (grouped[emoji] ?? 0) + 1;
  });
  return grouped;
}

Future<void> sendNotificationToUser(String targetUid, {required String title, required String body}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final ref = FirebaseDatabase.instance.ref('notifications/$targetUid').push();
  await ref.set({
    'title': title,
    'body': body,
    'timestamp': now,
    'read': false,
  });
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
