

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ashur/storage.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import '../upload_helper.dart';

class AddStoryScreen extends StatefulWidget {
  const AddStoryScreen({super.key});

  @override
  _AddStoryScreenState createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> with TickerProviderStateMixin {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _pollQuestionController = TextEditingController();
  final TextEditingController _pollOption1Controller = TextEditingController();
  final TextEditingController _pollOption2Controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  bool _isImageSelected = false;
  bool _isPoll = false;
  String _storyType = 'normal';
  final TextEditingController _qaQuestionController = TextEditingController();
  final TextEditingController _countdownTitleController = TextEditingController();
  DateTime? _countdownTarget;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  bool _isNonExpirable = false;

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
    _pollQuestionController.dispose();
    _pollOption1Controller.dispose();
    _pollOption2Controller.dispose();
    _qaQuestionController.dispose();
    _countdownTitleController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (!kIsWeb) {
        HapticFeedback.lightImpact();
      }
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: kIsWeb ? 85 : 90, 
        maxWidth: kIsWeb ? 800 : 1080, 
        maxHeight: kIsWeb ? 1200 : 1920, 
      );
      if (pickedFile != null) {
        Uint8List? editedImage;
        if (!kIsWeb) {
          final imageBytes = await pickedFile.readAsBytes();
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
          setState(() {
            _selectedImage = pickedFile;
            _imageBytes = editedImage;
            _isImageSelected = true;
          });
          _pulseController.repeat(reverse: true);
          if (!kIsWeb) {
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

  Future<String?> _uploadImage(Uint8List imageBytes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    String fileName = '${DateTime.now().millisecondsSinceEpoch}_story.jpg';
    return await UploadHelper.uploadBytes(context, imageBytes, filename: fileName);
  }

  Future<void> _createStory() async {
    if (_selectedImage == null) {
      if (!kIsWeb) {
        HapticFeedback.heavyImpact();
      }
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
    setState(() { _isUploading = true; });
    try {
      String? imageUrl = await _uploadImage(_imageBytes!);
      if (imageUrl == null) {
        setState(() { _isUploading = false; });
        return;
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final newStory = {
          'image': imageUrl,
          'story_desc': _captionController.text.trim(),
          'timestamp': ServerValue.timestamp,
          'storyId': DateTime.now().millisecondsSinceEpoch.toString(),
          if (_isNonExpirable) 'expires': false,
        };
        if (_isPoll && _pollQuestionController.text.trim().isNotEmpty && _pollOption1Controller.text.trim().isNotEmpty && _pollOption2Controller.text.trim().isNotEmpty) {
          newStory['poll'] = {
            'question': _pollQuestionController.text.trim(),
            'options': [
              _pollOption1Controller.text.trim(),
              _pollOption2Controller.text.trim(),
            ],
            'votes': [0, 0],
          };
        }
        if (_storyType == 'qa' && _qaQuestionController.text.trim().isNotEmpty) {
          newStory['type'] = 'qa';
          newStory['qa_question'] = _qaQuestionController.text.trim();
        }
        if (_storyType == 'countdown' && _countdownTitleController.text.trim().isNotEmpty && _countdownTarget != null) {
          newStory['type'] = 'countdown';
          newStory['countdown_title'] = _countdownTitleController.text.trim();
          newStory['countdown_target'] = _countdownTarget!.millisecondsSinceEpoch;
        }
        final snapshot = await userRef.child('stories').get();
        List<Map<String, dynamic>> stories = [];
        if (snapshot.exists) {
          final storiesData = snapshot.value;
          if (storiesData is List) {
            stories = storiesData.map((story) => Map<String, dynamic>.from(story as Map)).toList();
          } else if (storiesData is Map) {
            final storiesMap = storiesData;
            stories = storiesMap.values.map((story) => Map<String, dynamic>.from(story as Map)).toList();
          }
        }
        stories.insert(0, newStory);
        if (stories.length > 10) {
          stories = stories.take(10).toList();
        }
        await userRef.update({ 'stories': stories });
        await incrementChallengeProgress('نشر قصة');
        if (!kIsWeb) { HapticFeedback.mediumImpact(); }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نشر القصة بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _captionController.clear();
        _pollQuestionController.clear();
        _pollOption1Controller.clear();
        _pollOption2Controller.clear();
        _qaQuestionController.clear();
        _countdownTitleController.clear();
        _countdownTarget = null;
        setState(() {
          _selectedImage = null;
          _imageBytes = null;
          _isImageSelected = false;
          _isPoll = false;
          _storyType = 'normal';
        });
        _pulseController.stop();
      }
    } catch (e) {
      if (!kIsWeb) { HapticFeedback.heavyImpact(); }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء القصة: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() { _isUploading = false; });
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
          child: Text('إضافة قصة جديدة', style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); },
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
                      scale: _isImageSelected ? _pulseAnimation.value : 1.0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : () async {
                          await _pickImage();
                        },
                        child: Container(
                          height: 300,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isImageSelected 
                                  ? colorScheme.primary 
                                  : colorScheme.outline.withValues(alpha: 0.3),
                              width: _isImageSelected ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _selectedImage != null
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: Image.memory(
                                        _imageBytes!,
                                        width: double.infinity,
                                        height: 300,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    if (_isUploading)
                                      Container(
                                        width: double.infinity,
                                        height: 300,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(
                                                color: colorScheme.onPrimary,
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                'جاري رفع القصة...',
                                                style: TextStyle(
                                                  color: colorScheme.onPrimary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 64,
                                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'انقر لإضافة قصة',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (kIsWeb) ...[
                                      SizedBox(height: 8),
                                      Text(
                                        'أو اسحب الصورة هنا',
                                        style: TextStyle(
                                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
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
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _captionController,
                    enabled: !_isUploading,
                    textDirection: TextDirection.rtl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: 'أضف وصف للقصة (اختياري)...',
                      labelStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                      counterStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
                
                SizedBox(height: 32),
                
                Row(
                  children: [
                    Checkbox(
                      value: _isPoll,
                      onChanged: (v) => setState(() => _isPoll = v ?? false),
                    ),
                    Text('إضافة تصويت/سؤال'),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: _isNonExpirable,
                      onChanged: (v) => setState(() => _isNonExpirable = v ?? false),
                    ),
                    Text('قصة دائمة (لا تنتهي بعد 24 ساعة)'),
                  ],
                ),
                if (_isPoll) ...[
                  TextField(
                    controller: _pollQuestionController,
                    decoration: InputDecoration(labelText: 'السؤال أو التصويت'),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _pollOption1Controller,
                    decoration: InputDecoration(labelText: 'الخيار الأول'),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _pollOption2Controller,
                    decoration: InputDecoration(labelText: 'الخيار الثاني'),
                  ),
                  SizedBox(height: 16),
                ],
                
                Row(
                  children: [
                    Radio<String>(value: 'normal', groupValue: _storyType, onChanged: (v) => setState(() => _storyType = v!)),
                    Text('عادي'),
                    Radio<String>(value: 'qa', groupValue: _storyType, onChanged: (v) => setState(() => _storyType = v!)),
                    Text('سؤال وجواب'),
                    Radio<String>(value: 'countdown', groupValue: _storyType, onChanged: (v) => setState(() => _storyType = v!)),
                    Text('عد تنازلي'),
                  ],
                ),
                if (_storyType == 'qa') ...[
                  TextField(
                    controller: _qaQuestionController,
                    decoration: InputDecoration(labelText: 'اكتب سؤالك هنا'),
                  ),
                  SizedBox(height: 16),
                ],
                if (_storyType == 'countdown') ...[
                  TextField(
                    controller: _countdownTitleController,
                    decoration: InputDecoration(labelText: 'عنوان العد التنازلي'),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(Duration(hours: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (picked != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _countdownTarget = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                          });
                        }
                      }
                    },
                    child: Text(_countdownTarget == null ? 'اختر وقت النهاية' : 'وقت النهاية: ${_countdownTarget!.toLocal()}'),
                  ),
                  SizedBox(height: 16),
                ],
                
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isUploading ? null : _createStory,
                      child: Center(
                        child: _isUploading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'جاري النشر...',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_stories,
                                    color: colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'نشر القصة',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isNonExpirable ? 'هذه القصة ستكون دائمة ولن تختفي تلقائياً' : 'القصص تختفي بعد 24 ساعة من النشر',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
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
