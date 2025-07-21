

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:ashur/storage.dart';
import 'package:video_player/video_player.dart';
import '../upload_helper.dart';

class AddReelScreen extends StatefulWidget {
  const AddReelScreen({super.key});
  @override
  _AddReelScreenState createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> with TickerProviderStateMixin {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  io.File? _selectedVideo;
  bool _isUploading = false;
  bool _isVideoSelected = false;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
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
  }
  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _captionController.dispose();
    super.dispose();
  }
  Future<void> _pickVideo() async {
    try {
      HapticFeedback.lightImpact();
      final pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: Duration(seconds: 60),
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
  Future<void> _createReel() async {
    if (_selectedVideo == null) {
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
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إضافة وصف للريل'),
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
      String? videoUrl = await _uploadVideo(_selectedVideo!);
      if (videoUrl == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }
      bool playable = false;
      try {
        final testController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await testController.initialize();
        playable = true;
        await testController.dispose();
      } catch (e) {
        playable = false;
      }
      if (!playable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحقق من الفيديو بعد الرفع. يرجى المحاولة بفيديو آخر.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newReelRef = FirebaseDatabase.instance.ref('reels').push();
        await newReelRef.set({
          'desc': caption,
          'vid': videoUrl,
          'uid': user.uid,
          'username': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'timestamp': ServerValue.timestamp,
          'id': newReelRef.key,
        });
        await incrementChallengeProgress('نشر ريل');
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نشر الريل بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _captionController.clear();
        setState(() {
          _selectedVideo = null;
          _isVideoSelected = false;
        });
        _pulseController.stop();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء الريل: $e'),
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
          child: Text('إنشاء ريل جديد', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
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
                SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isVideoSelected ? _pulseAnimation.value : 1.0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickVideo,
                        child: Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isVideoSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
                              width: _isVideoSelected ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withOpacity(0.1),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _selectedVideo != null
                              ? Center(child: Icon(Icons.play_circle_outline, size: 64, color: Colors.white))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.video_library_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.6)),
                                    SizedBox(height: 16),
                                    Text('انقر لإضافة ريل', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6), fontSize: 18, fontWeight: FontWeight.w500)),
                                    SizedBox(height: 8),
                                    Text('اختر فيديو من معرض الفيديوهات', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 14)),
                                    SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: Text('الحد الأقصى: 60 ثانية', style: TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: colorScheme.shadow.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: TextField(
                    controller: _captionController,
                    enabled: !_isUploading,
                    textDirection: TextDirection.rtl,
                    maxLines: 4,
                    maxLength: 300,
                    decoration: InputDecoration(
                      labelText: 'اكتب وصف الريل...',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                      counterStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
                    ),
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 16, height: 1.4),
                  ),
                ),
                SizedBox(height: 32),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)]),
                    boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isUploading ? null : _createReel,
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
                                  Icon(Icons.play_arrow, color: colorScheme.onPrimary, size: 20),
                                  SizedBox(width: 8),
                                  Text('نشر الريل', style: TextStyle(color: colorScheme.onPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: colorScheme.primaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.primary.withOpacity(0.2))),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('الريل هو فيديو قصير يمكن مشاركته مع أصدقائك', style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8), fontSize: 14)),
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
