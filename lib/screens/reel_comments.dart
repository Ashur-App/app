

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../user_badges.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import '../upload_helper.dart';


String _encodeUidForPath(String? uid) {
  if (uid == null) return '';
  return uid.replaceAll('.', '_dot_').replaceAll('@', '_at_').replaceAll('#', '_hash_').replaceAll('\$', '_dollar_').replaceAll('[', '_lbracket_').replaceAll(']', '_rbracket_').replaceAll('/', '_slash_');
}

class ReelsCommentsScreen extends StatefulWidget {
  final String postId;
  const ReelsCommentsScreen({super.key, required this.postId});

  @override
  State<ReelsCommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<ReelsCommentsScreen> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  bool _isSending = false;
  bool _isUploading = false;
  late DatabaseReference _commentsRef;
  AudioPlayer? _audioPlayer;
  String? _currentlyPlayingAudioUrl;
  bool _isPlaying = false;
  String? _replyToCommentId;
  final TextEditingController _replyController = TextEditingController();
  final Map<String, String> _usernameCache = {};
  String? _replyToCommentUid;
  String? _replyToParentId;

  @override
  void initState() {
    super.initState();
    _commentsRef = FirebaseDatabase.instance.ref().child('reels_comments');
    _recorder = FlutterSoundRecorder();
    _initRecorder();
    _audioPlayer = AudioPlayer();
  }

  Future<void> _initRecorder() async {
    await _recorder!.openRecorder();
    await Permission.microphone.request();
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _controller.dispose();
    _audioPlayer?.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendComment(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _commentsRef.child(widget.postId).child('comments').push().set({
          'text': text.trim(),
          'audioUrl': '',
          'imageUrl': '',
          'userEmail': user.uid,
          'timestamp': ServerValue.timestamp,
        });
        _controller.clear();
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
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
        setState(() => _isUploading = true);
        try {
          User? user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            io.File tempFile = await _saveTempImage(editedImage);
            String imageUrl = await _uploadFile(tempFile);
            await _commentsRef.child(widget.postId).child('comments').push().set({
              'text': '',
              'imageUrl': imageUrl,
              'audioUrl': '',
              'userEmail': user.uid,
              'timestamp': ServerValue.timestamp,
            });
            await tempFile.delete();
          }
        } finally {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  Future<io.File> _saveTempImage(Uint8List bytes) async {
    final tempDir = await io.Directory.systemTemp.createTemp('edited_image');
    final tempFile = io.File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  Future<String> _uploadFile(io.File file) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final url = await UploadHelper.uploadFile(context, file, filename: fileName);
    if (url == null) throw Exception('Upload failed');
    return url;
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      final pathStr = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder!.startRecorder(toFile: pathStr);
      setState(() => _isRecording = true);
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      String? audioPath = await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      if (audioPath != null) {
        await _sendAudio(audioPath);
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _sendAudio(String audioPath) async {
    setState(() => _isUploading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        io.File audioFile = io.File(audioPath);
        String audioUrl = await _uploadAudioFile(audioFile);
        await _commentsRef.child(widget.postId).child('comments').push().set({
          'text': '',
          'imageUrl': '',
          'audioUrl': audioUrl,
          'userEmail': user.uid,
          'timestamp': ServerValue.timestamp,
        });
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<String> _uploadAudioFile(io.File file) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final url = await UploadHelper.uploadFile(context, file, filename: fileName);
    if (url == null) throw Exception('Upload failed');
    return url;
  }

  Future<void> _addComment({String? parentId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final text = _controller.text.trim();
      if (text.isNotEmpty) {
        setState(() { _isSending = true; });
        final newId = DateTime.now().millisecondsSinceEpoch.toString();
        final data = {
          'commentId': newId,
          'uid': user.uid,
          'text': text,
          'timestamp': ServerValue.timestamp,
          'likes': {},
          'replies': [],
          'imageUrl': '',
          'audioUrl': '',
        };
        if (parentId == null) {
          await _commentsRef.child(widget.postId).child('comments').child(newId).set(data);
          _controller.clear();
        } else {
          await _addReplyRecursive(_commentsRef, widget.postId, parentId, data);
          _controller.clear();
          setState(() { _replyToCommentId = null; _replyToCommentUid = null; _replyToParentId = null; });
        }
        setState(() { _isSending = false; });
      }
    }
  }

  Future<void> _toggleLike(String commentId, {String? parentId, int? replyIndex}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (parentId == null) {
      final snap = await _commentsRef.child(widget.postId).child('comments').child(commentId).get();
      if (snap.exists) {
        final comment = Map<String, dynamic>.from(snap.value as Map);
        final likes = Map<String, dynamic>.from(comment['likes'] ?? {});
        if (likes.containsKey(user.uid)) {
          likes.remove(user.uid);
        } else {
          likes[user.uid] = true;
        }
        await _commentsRef.child(widget.postId).child('comments').child(commentId).update({'likes': likes});
      }
    } else {
      final parentSnap = await _commentsRef.child(widget.postId).child('comments').child(parentId).get();
      if (parentSnap.exists) {
        final parent = Map<String, dynamic>.from(parentSnap.value as Map);
        final repliesRaw = parent['replies'] ?? [];
        final replies = repliesRaw is List
            ? repliesRaw.map((e) => Map<String, dynamic>.from(Map<String, dynamic>.from(e as Map))).toList()
            : <Map<String, dynamic>>[];
        if (replyIndex != null && replyIndex < replies.length) {
          final reply = Map<String, dynamic>.from(replies[replyIndex]);
          final likes = Map<String, dynamic>.from(reply['likes'] ?? {});
          if (likes.containsKey(user.uid)) {
            likes.remove(user.uid);
          } else {
            likes[user.uid] = true;
          }
          replies[replyIndex]['likes'] = likes;
          await _commentsRef.child(widget.postId).child('comments').child(parentId).update({'replies': replies});
        }
      }
    }
  }

  Future<Map<String, dynamic>> _getUserProfile(String uid) async {
    try {
      final snap = await FirebaseDatabase.instance.ref('users/$uid').get();
      if (snap.exists && snap.value != null && snap.value is Map) {
        final userData = Map<String, dynamic>.from(snap.value as Map);
        _usernameCache[uid] = userData['username'] ?? uid;
        _usernameCache['${uid}_pic'] = userData['pic'] ?? '';
        return userData;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات المستخدم: $e'), backgroundColor: Colors.red),
        );
      }
    }
    return {'username': uid, 'pic': ''};
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return 'منذ ${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return 'منذ ${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return 'منذ ${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildVoiceMessageWidget(String audioUrl) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCurrentlyPlaying = _currentlyPlayingAudioUrl == audioUrl && _isPlaying;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentlyPlaying 
              ? colorScheme.primary 
              : colorScheme.outline.withOpacity(0.2),
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
                  : colorScheme.primary.withOpacity(0.1),
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
                  color: colorScheme.onSurface,
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
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  SizedBox(width: 4),
                  Text(
                    isCurrentlyPlaying ? 'جاري التشغيل...' : 'اضغط للاستماع',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
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
      setState(() {
        _isPlaying = false;
        _currentlyPlayingAudioUrl = null;
      });
    }
  }

  Widget _buildReplies(List replies, String parentId) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: replies.length,
      itemBuilder: (context, i) {
        final reply = Map<String, dynamic>.from(replies[i]);
        final likes = Map<String, dynamic>.from(reply['likes'] ?? {});
        print('Rendering reply: $reply');
        if (reply['commentId'] == null || reply['commentId'].toString().isEmpty) {
          reply['commentId'] = 'reply_$i';
        }
        return FutureBuilder<Map<String, dynamic>>(
          future: _getUserProfile(reply['uid'] ?? ''),
          builder: (context, snap) {
            final userData = snap.data ?? {};
            final username = userData['username'] ?? reply['uid'];
            final profilePic = userData['pic'] ?? '';
            final profileTheme = userData['profileTheme'] != null && userData['profileTheme'].toString().isNotEmpty ? Color(int.tryParse(userData['profileTheme'].toString()) ?? 0) : colorScheme.primary;
            return Container(
              margin: const EdgeInsets.only(left: 32, top: 8, bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: profileTheme.withOpacity(0.1),
                    backgroundImage: (profilePic.isNotEmpty)
                        ? NetworkImage(profilePic)
                        : null,
                    child: (profilePic.isEmpty)
                        ? Text(
                            username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?',
                            style: TextStyle(
                              color: profileTheme,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('@$username', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: profileTheme)),
                            SizedBox(width: 6),
                            UserBadges(userData: userData, iconSize: 14),
                            SizedBox(width: 8),
                            Text(_formatTimestamp(reply['timestamp']), style: TextStyle(fontSize: 11, color: colorScheme.outline)),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(reply['text'] ?? '', style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
                        if (reply['imageUrl'] != null && reply['imageUrl'].toString().isNotEmpty) ...[
                          SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              reply['imageUrl'],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.error_outline,
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        if (reply['audioUrl'] != null && reply['audioUrl'].toString().isNotEmpty) ...[
                          SizedBox(height: 4),
                          _buildVoiceMessageWidget(reply['audioUrl']),
                        ],
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.favorite, color: likes.containsKey(FirebaseAuth.instance.currentUser?.uid) ? colorScheme.primary : colorScheme.outline, size: 18),
                              onPressed: () => _toggleLike(reply['commentId'], parentId: parentId, replyIndex: i),
                              visualDensity: VisualDensity.compact,
                            ),
                            Text('${likes.length}', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                            SizedBox(width: 8),
                            TextButton(
                              onPressed: () { setState(() { _replyToCommentId = parentId; }); },
                              style: TextButton.styleFrom(minimumSize: Size(0, 28), padding: EdgeInsets.symmetric(horizontal: 8)),
                              child: Text('رد', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThreadedComment(Map<String, dynamic> comment, {String? parentId, int? depth = 0, String? parentKey}) {
    final colorScheme = Theme.of(context).colorScheme;
    final likes = Map<String, dynamic>.from(comment['likes'] ?? {});
    final repliesRaw = comment['replies'] ?? [];
    final replies = repliesRaw is List
        ? repliesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final commentId = comment['commentId'] ?? parentKey ?? '';
    final uid = comment['uid'] ?? comment['userEmail'] ?? '';
    comment['commentId'] = commentId;
    for (int i = 0; i < replies.length; i++) {
      if (replies[i]['commentId'] == null || replies[i]['commentId'].toString().isEmpty) {
        replies[i]['commentId'] = 'reply_${commentId}_$i';
      }
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserProfile(uid),
      builder: (context, snap) {
        final userData = snap.data ?? {};
        final username = userData['username'] ?? uid;
        final profilePic = userData['pic'] ?? '';
        final profileTheme = userData['profileTheme'] != null && userData['profileTheme'].toString().isNotEmpty ? Color(int.tryParse(userData['profileTheme'].toString()) ?? 0) : colorScheme.onSurface;
        return Container(
          margin: EdgeInsets.only(bottom: 12, left: 24.0 * (depth ?? 0)),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: profileTheme.withOpacity(0.2),
                    backgroundImage: (profilePic.isNotEmpty)
                      ? NetworkImage(profilePic)
                      : null,
                    child: (profilePic.isEmpty)
                      ? Text(
                          (username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?'),
                          style: TextStyle(
                            color: profileTheme,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '@$username',
                          style: TextStyle(
                            color: profileTheme,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 4),
                        UserBadges(userData: userData, iconSize: 14),
                      ],
                    ),
                  ),
                  if ((commentId ?? '') != '') ...[
                    IconButton(
                      icon: Icon(Icons.favorite, color: likes.containsKey(FirebaseAuth.instance.currentUser?.uid) ? colorScheme.primary : colorScheme.outline, size: 20),
                      onPressed: () {
                        if (commentId != null) {
                          _toggleLikeRecursive(_commentsRef, widget.postId, commentId, parentId: parentId);
                        }
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    Text('${likes.length}', style: TextStyle(fontSize: 14, color: colorScheme.primary)),
                    TextButton(
                      onPressed: () {
                        if (commentId != null && uid != null) {
                          setState(() {
                            _replyToCommentId = commentId;
                            _replyToCommentUid = uid;
                            _replyToParentId = parentId;
                            _controller.clear();
                          });
                        }
                      },
                      style: TextButton.styleFrom(minimumSize: Size(0, 32), padding: EdgeInsets.symmetric(horizontal: 10)),
                      child: Text('رد', style: TextStyle(fontSize: 13, color: colorScheme.primary)),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: comment['text'] ?? '',
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (comment['imageUrl'] != null && comment['imageUrl'].toString().isNotEmpty) ...[
                    SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        comment['imageUrl'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.error_outline,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (comment['audioUrl'] != null && comment['audioUrl'].toString().isNotEmpty) ...[
                    SizedBox(width: 8),
                    _buildVoiceMessageWidget(comment['audioUrl']),
                  ],
                ],
              ),
              if (replies.isNotEmpty)
                ...replies.map((reply) => _buildThreadedComment(reply, parentId: commentId, depth: (depth ?? 0) + 1, parentKey: null)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'التعليقات',
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
            child: StreamBuilder<DatabaseEvent>(
              stream: _commentsRef
                  .child(widget.postId)
                  .child('comments')
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
                          'حدث خطأ في تحميل التعليقات',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
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
                          'جاري تحميل التعليقات...',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData ||
                    (snapshot.data!.snapshot.value == null)) {
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
                          'لا توجد تعليقات بعد',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'كن أول من يعلق على هذا المنشور',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final rawComments = snapshot.data!.snapshot.value as Map;
                final commentsMap = rawComments.map((key, value) => MapEntry(key.toString(), value));
                List<dynamic> commentsList = commentsMap.values.toList();

                commentsList.sort((a, b) {
                  final aTime = (a['timestamp'] is int) ? a['timestamp'] : int.tryParse(a['timestamp']?.toString() ?? '') ?? 0;
                  final bTime = (b['timestamp'] is int) ? b['timestamp'] : int.tryParse(b['timestamp']?.toString() ?? '') ?? 0;
                  return bTime.compareTo(aTime);
                });

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicWidth(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < commentsList.length; i++)
                            _buildThreadedComment(
                              Map<String, dynamic>.from(commentsList[i]),
                              parentId: null,
                              depth: 0,
                              parentKey: commentsMap.keys.toList()[i],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_replyToCommentId != null) ...[
            FutureBuilder<Map<String, dynamic>>(
              future: _getUserProfile(_replyToCommentUid ?? ''),
              builder: (context, snap) {
                final userData = snap.data ?? {};
                final replyToUsername = userData['username'] ?? '';
                final replyToPic = userData['pic'] ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.7),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: (userData['profileTheme'] != null && userData['profileTheme'].toString().isNotEmpty ? Color(int.tryParse(userData['profileTheme'].toString()) ?? 0) : colorScheme.primary).withOpacity(0.1),
                        backgroundImage: (replyToPic.isNotEmpty) ? NetworkImage(replyToPic) : null,
                        child: (replyToPic.isEmpty)
                            ? Text(
                                replyToUsername.isNotEmpty ? replyToUsername.substring(0, 1).toUpperCase() : '?',
                                style: TextStyle(
                                  color: userData['profileTheme'] != null && userData['profileTheme'].toString().isNotEmpty ? Color(int.tryParse(userData['profileTheme'].toString()) ?? 0) : colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الرد على @$replyToUsername',
                          style: TextStyle(color: userData['profileTheme'] != null && userData['profileTheme'].toString().isNotEmpty ? Color(int.tryParse(userData['profileTheme'].toString()) ?? 0) : colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: colorScheme.primary),
                        onPressed: () {
                          setState(() {
                            _replyToCommentId = null;
                            _replyToCommentUid = null;
                            _controller.clear();
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
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
                IconButton(
                  icon: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: _isRecording ? Colors.red : colorScheme.primary,
                  ),
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'اكتب تعليقك هنا...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: _isSending
                            ? Padding(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      maxLines: null,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      color: colorScheme.onPrimary,
                    ),
                    onPressed: _isSending ? null : () {
                      if (_replyToCommentId != null) {
                        _addComment(parentId: _replyToCommentId);
                        setState(() {
                          _replyToCommentId = null;
                          _replyToCommentUid = null;
                          _controller.clear();
                        });
                      } else {
                        _addComment();
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

Future<void> _addReplyRecursive(DatabaseReference commentsRef, String postId, String parentId, Map<String, dynamic> replyData) async {
  final commentsSnap = await commentsRef.child(postId).child('comments').get();
  if (!commentsSnap.exists) return;
  final commentsMap = Map<String, dynamic>.from(commentsSnap.value as Map);
  bool updated = false;
  for (final entry in commentsMap.entries) {
    final commentKey = entry.key;
    final comment = Map<String, dynamic>.from(entry.value as Map);
    if ((comment['commentId'] ?? commentKey) == parentId) {
      final repliesRaw = comment['replies'] ?? [];
      final replies = repliesRaw is List
          ? repliesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      replies.add(replyData);
      await commentsRef.child(postId).child('comments').child(commentKey).update({'replies': replies});
      updated = true;
      break;
    } else {
      final updatedReplies = await _addReplyRecursiveToReplies(commentsRef, comment['replies'] ?? [], parentId, replyData, postId, commentKey);
      if (updatedReplies != null) {
        await commentsRef.child(postId).child('comments').child(commentKey).update({'replies': updatedReplies});
        updated = true;
        break;
      }
    }
  }
}
Future<List?> _addReplyRecursiveToReplies(DatabaseReference commentsRef, List repliesRaw, String parentId, Map<String, dynamic> replyData, String postId, String commentKey) async {
  final replies = repliesRaw is List
      ? repliesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
  for (int i = 0; i < replies.length; i++) {
    final reply = replies[i];
    if ((reply['commentId'] ?? 'reply_$i') == parentId) {
      final subRepliesRaw = reply['replies'] ?? [];
      final subReplies = subRepliesRaw is List
          ? subRepliesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      subReplies.add(replyData);
      reply['replies'] = subReplies;
      replies[i] = reply;
      return replies;
    } else {
      final updatedSubReplies = await _addReplyRecursiveToReplies(commentsRef, reply['replies'] ?? [], parentId, replyData, postId, commentKey);
      if (updatedSubReplies != null) {
        reply['replies'] = updatedSubReplies;
        replies[i] = reply;
        return replies;
      }
    }
  }
  return null;
}

Future<void> _toggleLikeRecursive(DatabaseReference commentsRef, String postId, String commentId, {String? parentId}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final commentsSnap = await commentsRef.child(postId).child('comments').get();
  if (!commentsSnap.exists) return;
  final commentsMap = Map<String, dynamic>.from(commentsSnap.value as Map);
  for (final entry in commentsMap.entries) {
    final commentKey = entry.key;
    final comment = Map<String, dynamic>.from(entry.value as Map);
    if ((comment['commentId'] ?? commentKey) == commentId) {
      final likes = Map<String, dynamic>.from(comment['likes'] ?? {});
      if (likes.containsKey(user.uid)) {
        likes.remove(user.uid);
      } else {
        likes[user.uid] = true;
      }
      await commentsRef.child(postId).child('comments').child(commentKey).update({'likes': likes});
      return;
    } else {
      final updatedReplies = await _toggleLikeRecursiveInReplies(comment['replies'] ?? [], commentId, user.uid);
      if (updatedReplies != null) {
        await commentsRef.child(postId).child('comments').child(commentKey).update({'replies': updatedReplies});
        return;
      }
    }
  }
}
Future<List?> _toggleLikeRecursiveInReplies(List repliesRaw, String commentId, String uid) async {
  final replies = repliesRaw is List
      ? repliesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
  for (int i = 0; i < replies.length; i++) {
    final reply = replies[i];
    if ((reply['commentId'] ?? 'reply_$i') == commentId) {
      final likes = Map<String, dynamic>.from(reply['likes'] ?? {});
      if (likes.containsKey(uid)) {
        likes.remove(uid);
      } else {
        likes[uid] = true;
      }
      reply['likes'] = likes;
      replies[i] = reply;
      return replies;
    } else {
      final updatedSubReplies = await _toggleLikeRecursiveInReplies(reply['replies'] ?? [], commentId, uid);
      if (updatedSubReplies != null) {
        reply['replies'] = updatedSubReplies;
        replies[i] = reply;
        return replies;
      }
    }
  }
  return null;
}
