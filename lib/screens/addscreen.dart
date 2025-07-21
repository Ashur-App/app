

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:ashur/storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import '../upload_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  _AddScreenState createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> with TickerProviderStateMixin {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _groupIdController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  io.File? _selectedImage;
  bool _isUploading = false;
  bool _isImageSelected = false;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  io.File? _selectedVideo;
  bool _isVideoSelected = false;
  io.File? _selectedAudio;
  bool _isAudioSelected = false;
  final List<String> _groupInvites = [];
  String _postType = 'text';
  final List<String> _postTypes = ['text', 'image', 'video', 'voice', 'group'];
  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _recorder = FlutterSoundRecorder();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder!.openRecorder();
    await Permission.microphone.request();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      HapticFeedback.lightImpact();
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
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
          if (shouldSend == true) {
            final tempDir = await io.Directory.systemTemp.createTemp('edited_image');
            final tempFile = io.File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await tempFile.writeAsBytes(editedImage);
            setState(() {
              _selectedImage = tempFile;
              _isImageSelected = true;
            });
            _pulseController.repeat(reverse: true);
            HapticFeedback.mediumImpact();
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في اختيار الصورة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<String?> _uploadImage(io.File image) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
    return await UploadHelper.uploadFile(context, image, filename: fileName);
  }

  Future<void> _pickVideo() async {
    try {
      HapticFeedback.lightImpact();
      final pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(minutes: 5),
      );
      if (pickedFile != null) {
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('معاينة الفيديو'),
            content: AspectRatio(
              aspectRatio: 16/9,
              child: VideoPlayerWidget(file: io.File(pickedFile.path)),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('إرسال')),
            ],
          ),
        );
        if (shouldSend == true) {
          setState(() {
            _selectedVideo = io.File(pickedFile.path);
            _isVideoSelected = true;
          });
          _pulseController.repeat(reverse: true);
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في اختيار الفيديو: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<String?> _uploadVideo(io.File video) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(video.path)}';
    return await UploadHelper.uploadFile(context, video, filename: fileName);
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      final pathStr = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder!.startRecorder(toFile: pathStr);
      setState(() => _isRecording = true);
    } catch (e) {}
  }

  Future<void> _stopRecording() async {
    try {
      String? audioPath = await _recorder!.stopRecorder();
      setState(() => _isRecording = false);
      if (audioPath != null) {
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('معاينة الصوت'),
            content: AudioPlayerWidget(file: io.File(audioPath)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('إرسال')),
            ],
          ),
        );
        if (shouldSend == true) {
          setState(() {
            _selectedAudio = io.File(audioPath);
            _isAudioSelected = true;
          });
        }
      }
    } catch (e) {}
  }

  Future<String?> _uploadAudio(io.File audio) async {
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(audio.path)}';
    return await UploadHelper.uploadFile(context, audio, filename: fileName);
  }

  void _addGroupInvite(String groupId) {
    final id = groupId.trim().startsWith('group://') ? groupId.trim().substring(8) : groupId.trim();
    if (id.isNotEmpty && !_groupInvites.contains(id)) {
      setState(() {
        _groupInvites.add(id);
      });
      _groupIdController.clear();
    }
  }

  void _removeGroupInvite(String groupId) {
    final id = groupId.startsWith('group://') ? groupId.substring(8) : groupId;
    setState(() {
      _groupInvites.remove(id);
    });
  }

  Future<void> _createPost() async {
    final desc = _descController.text.trim();
    if (_postType == 'text' && desc.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إضافة نص للمنشور'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_postType == 'group' && _groupInvites.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إدخال معرف مجموعة واحد على الأقل'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    List<String> groupInvites = List<String>.from(_groupInvites);
    if (_postType == 'image' && _selectedImage == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار صورة أولاً'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_postType == 'video' && _selectedVideo == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار فيديو أولاً'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_postType == 'voice' && _selectedAudio == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى تسجيل صوت أولاً'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() {
      _isUploading = true;
    });
    try {
      String? imageUrl;
      String? videoUrl;
      String? audioUrl;
      if (_postType == 'image' && _selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }
      if (_postType == 'video' && _selectedVideo != null) {
        videoUrl = await _uploadVideo(_selectedVideo!);
      }
      if (_postType == 'voice' && _selectedAudio != null) {
        audioUrl = await _uploadAudio(_selectedAudio!);
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final now = DateTime.now();
        final newPostRef = FirebaseDatabase.instance.ref('posts').push();
        final postId = newPostRef.key;
        await newPostRef.set({
          'id': postId,
          'type': _postType,
          'desc': desc,
          'pic': imageUrl ?? '',
          'videoUrl': videoUrl ?? '',
          'audioUrl': audioUrl ?? '',
          'groupInvites': groupInvites,
          'userEmail': user.uid,
          'timestamp': now.toIso8601String(),
          'shares': 0,
          'userActions': {},
        });
        await incrementChallengeProgress('نشر منشور');
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نشر المنشور بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _descController.clear();
        setState(() {
          _selectedImage = null;
          _isImageSelected = false;
          _selectedVideo = null;
          _isVideoSelected = false;
          _selectedAudio = null;
          _isAudioSelected = false;
          _groupInvites.clear();
        });
        _pulseController.stop();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء المنشور: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text('إنشاء منشور جديد', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _postTypes.map((type) {
                    final selected = _postType == type;
                    IconData icon;
                    String label;
                    switch (type) {
                      case 'text': icon = Icons.text_fields; label = 'نص'; break;
                      case 'image': icon = Icons.image; label = 'صورة'; break;
                      case 'video': icon = Icons.videocam; label = 'فيديو'; break;
                      case 'voice': icon = Icons.mic; label = 'صوت'; break;
                      case 'group': icon = Icons.group_add; label = 'مجموعة'; break;
                      default: icon = Icons.text_fields; label = 'نص';
                    }
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _postType = type),
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.2),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(icon, color: selected ? colorScheme.onPrimary : colorScheme.primary, size: 24),
                              SizedBox(height: 4),
                              Text(label, style: TextStyle(color: selected ? colorScheme.onPrimary : colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 24),
                if (_postType == 'text')
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                      boxShadow: [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.05), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _descController,
                      enabled: !_isUploading,
                      textDirection: TextDirection.rtl,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: 'اكتب نص المنشور...',
                        labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                        counterStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
                      ),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 16, height: 1.4),
                    ),
                  ),
                if (_postType == 'image')
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isUploading ? null : _pickImage,
                      child: SizedBox(
                        height: 200,
                        child: _selectedImage != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(_selectedImage!, width: double.infinity, height: 200, fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() { _selectedImage = null; _isImageSelected = false; }),
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black.withOpacity(0.5),
                                        child: Icon(Icons.close, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined, size: 48, color: colorScheme.primary),
                                    SizedBox(height: 12),
                                    Text('انقر لإضافة صورة', style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                if (_postType == 'video')
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isUploading ? null : _pickVideo,
                      child: SizedBox(
                        height: 200,
                        child: _selectedVideo != null
                            ? Stack(
                                children: [
                                  Center(child: Icon(Icons.videocam, size: 64, color: colorScheme.primary)),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => setState(() { _selectedVideo = null; _isVideoSelected = false; }),
                                      child: CircleAvatar(
                                        backgroundColor: Colors.black.withOpacity(0.5),
                                        child: Icon(Icons.close, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.videocam, size: 48, color: colorScheme.primary),
                                    SizedBox(height: 12),
                                    Text('انقر لإضافة فيديو', style: TextStyle(color: colorScheme.primary, fontSize: 16, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                if (_postType == 'voice')
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Container(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          if (!_isRecording && !_isAudioSelected)
                            ElevatedButton.icon(
                              onPressed: _startRecording,
                              icon: Icon(Icons.mic),
                              label: Text('تسجيل صوت'),
                            ),
                          if (_isRecording)
                            ElevatedButton.icon(
                              onPressed: _stopRecording,
                              icon: Icon(Icons.stop),
                              label: Text('إيقاف التسجيل'),
                            ),
                          if (_isAudioSelected)
                            Row(
                              children: [
                                Icon(Icons.audiotrack, color: colorScheme.primary),
                                SizedBox(width: 8),
                                Text('تم تسجيل صوت'),
                                Spacer(),
                                IconButton(
                                  icon: Icon(Icons.close, color: colorScheme.error),
                                  onPressed: () => setState(() { _selectedAudio = null; _isAudioSelected = false; }),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_postType == 'group')
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _groupIdController,
                                  decoration: InputDecoration(labelText: 'أدخل معرف المجموعة'),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) _addGroupInvite(val);
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isUploading ? null : () {
                                  final val = _groupIdController.text;
                                  if (val.trim().isNotEmpty) _addGroupInvite(val);
                                },
                                child: Text('إضافة'),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: _groupInvites.map((id) => Chip(label: Text(id), onDeleted: () => _removeGroupInvite(id))).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: 24),
                if (_postType != 'text')
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                      boxShadow: [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.05), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: TextField(
                      controller: _descController,
                      enabled: !_isUploading,
                      textDirection: TextDirection.rtl,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: 'اكتب وصف المنشور...',
                        labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                        counterStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
                      ),
                      style: TextStyle(color: colorScheme.onSurface, fontSize: 16, height: 1.4),
                    ),
                  ),
                SizedBox(height: 24),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                    ),
                    boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isUploading ? null : _createPost,
                      child: Center(
                        child: _isUploading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary)),
                                  SizedBox(width: 12),
                                  Text('جاري النشر...', style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send, color: colorScheme.onPrimary, size: 20),
                                  SizedBox(width: 8),
                                  Text('نشر المنشور', style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: colorScheme.primary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('نصيحة: أضف وصفاً جذاباً لزيادة التفاعل مع منشورك', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final io.File file;
  const VideoPlayerWidget({super.key, required this.file});
  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}
class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) => setState(() {}));
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : Center(child: CircularProgressIndicator());
  }
}
class AudioPlayerWidget extends StatefulWidget {
  final io.File file;
  const AudioPlayerWidget({super.key, required this.file});
  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}
class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(widget.file.path));
    }
    setState(() => _isPlaying = !_isPlaying);
  }
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _togglePlay,
        ),
        Text(_isPlaying ? 'جاري التشغيل...' : 'اضغط للتشغيل'),
      ],
    );
  }
}
