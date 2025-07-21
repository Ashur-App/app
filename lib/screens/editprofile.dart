

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:ashur/screens/streaks_store.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import '../upload_helper.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with TickerProviderStateMixin {
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  io.File? _selectedImage;
  bool _isLoading = false;
  final bool _isUploading = false;
  bool _isImageSelected = false;
  Map<String, dynamic>? _userData;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;
  Color? _selectedThemeColor;
  io.File? _selectedCoverImage;
  String? _coverImageUrl;
  final List<Color> _themeColors = [
    Colors.blue, Colors.purple, Colors.green, Colors.orange, Colors.red, Colors.teal, Colors.amber, Colors.pink, Colors.indigo, Colors.brown
  ];

  bool get _canEditProfileColor => _userData?['canEditProfileColor'] == true;
  bool get _canEditProfileBanner => _userData?['canEditProfileBanner'] == true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final snapshot = await userRef.get();
        
        if (snapshot.exists) {
          setState(() {
            _userData = Map<String, dynamic>.from(snapshot.value as Map<Object?, Object?>);
            _bioController.text = _userData!['bio'] ?? '';
            _nameController.text = _userData!['name'] ?? '';
            if (_userData!['profileTheme'] != null) {
              _selectedThemeColor = Color(int.parse(_userData!['profileTheme']));
            }
            if (_userData!['coverPhoto'] != null) {
              _coverImageUrl = _userData!['coverPhoto'];
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحميل البيانات: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      HapticFeedback.lightImpact();
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
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

  Future<void> _pickCoverImage() async {
    try {
      HapticFeedback.lightImpact();
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 400,
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
          final tempDir = await io.Directory.systemTemp.createTemp('edited_image');
          final tempFile = io.File('${tempDir.path}/edited_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(editedImage);
          setState(() {
            _selectedCoverImage = tempFile;
          });
          HapticFeedback.mediumImpact();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في اختيار صورة الغلاف: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<String?> _uploadCoverImage(io.File image) async {
    String fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
    return await UploadHelper.uploadFile(context, image, filename: fileName);
  }

  Future<bool> _isUsernameTaken(String username) async {
    final ref = FirebaseDatabase.instance.ref('users');
    final snapshot = await ref.get();
    if (snapshot.exists && snapshot.value != null) {
      final users = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in users.entries) {
        final userData = Map<String, dynamic>.from(entry.value as Map);
        if ((userData['username'] as String?)?.toLowerCase() == username.toLowerCase() && entry.key != FirebaseAuth.instance.currentUser?.uid) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى إدخال الاسم'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? imageUrl;
        if (_selectedImage != null) {
          imageUrl = await _uploadImage(_selectedImage!);
          if (imageUrl == null) {
            setState(() { _isLoading = false; });
            return;
          }
        }
        String? coverUrl;
        if (_selectedCoverImage != null) {
          coverUrl = await _uploadCoverImage(_selectedCoverImage!);
          if (coverUrl == null) {
            setState(() { _isLoading = false; });
            return;
          }
        }
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        await userRef.update({
          'name': name,
          'bio': _bioController.text.trim(),
          if (imageUrl != null) 'pic': imageUrl,
          if (coverUrl != null) 'coverPhoto': coverUrl,
          if (_selectedThemeColor != null) 'profileTheme': _selectedThemeColor!.value.toString(),
          'updated_at': DateTime.now().toUtc().toString(),
          if (_userData != null && _userData!.containsKey('verify')) 'verify': _userData!['verify'],
          if (_userData != null && _userData!.containsKey('mod')) 'mod': _userData!['mod'],
          if (_userData != null && _userData!.containsKey('contributor')) 'contributor': _userData!['contributor'],
          if (_userData != null && _userData!.containsKey('team')) 'team': _userData!['team'],
          if (_userData != null && _userData!.containsKey('achievements')) 'achievements': _userData!['achievements'],
          if (_userData != null && _userData!.containsKey('private')) 'private': _userData!['private'],
          if (_userData != null && _userData!.containsKey('blockedUsers')) 'blockedUsers': _userData!['blockedUsers'],
          if (_userData != null && _userData!.containsKey('dailyChallengeCompleted')) 'dailyChallengeCompleted': _userData!['dailyChallengeCompleted'],
          if (_userData != null && _userData!.containsKey('weeklyChallengeCompleted')) 'weeklyChallengeCompleted': _userData!['weeklyChallengeCompleted'],
        });
        if (coverUrl != null) _coverImageUrl = coverUrl;
        if (_selectedThemeColor != null) _userData!['profileTheme'] = _selectedThemeColor!.value.toString();
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ الملف الشخصي: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'تعديل الملف الشخصي',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20),
              
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
              child: Column(
                children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isImageSelected ? _pulseAnimation.value : 1.0,
                    child: GestureDetector(
                              onTap: _isLoading ? null : _pickImage,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(60),
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
                                            borderRadius: BorderRadius.circular(58),
                                            child: Image.file(
                                              _selectedImage!,
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (_isUploading)
                                            Container(
                                              width: 120,
                                              height: 120,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(58),
                                              ),
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  color: colorScheme.onPrimary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      )
                                    : _userData?['pic'] != null && _userData!['pic'].toString().isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(58),
                                            child: Image.network(
                                              _userData!['pic'],
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.person,
                                                  size: 60,
                                                  color: colorScheme.primary,
                                                );
                                              },
                                            ),
                                          )
                                        : Icon(
                                            Icons.person,
                                            size: 60,
                                            color: colorScheme.primary,
                                          ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 12),
                      Text(
                        'انقر لتغيير الصورة',
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 32),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: (_coverImageUrl != null || _selectedCoverImage != null)
                            ? DecorationImage(
                                image: _selectedCoverImage != null
                                    ? FileImage(_selectedCoverImage!)
                                    : NetworkImage(_coverImageUrl!) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: (_coverImageUrl == null && _selectedCoverImage == null)
                            ? (_selectedThemeColor ?? colorScheme.primary).withOpacity(0.15)
                            : null,
                      ),
                      child: (_coverImageUrl == null && _selectedCoverImage == null)
                          ? Center(
                              child: Icon(Icons.photo, size: 48, color: (_selectedThemeColor ?? colorScheme.primary)),
                            )
                          : null,
                    ),
                    if (_coverImageUrl != null || _selectedCoverImage != null)
                      Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (_selectedThemeColor ?? colorScheme.primary).withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _canEditProfileBanner
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedThemeColor ?? colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                            onPressed: _pickCoverImage,
                            icon: Icon(Icons.photo_library),
                            label: Text('تغيير صورة الغلاف'),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.secondary,
                              foregroundColor: colorScheme.onSecondary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => StreaksStore(showIntro: false)));
                            },
                            icon: Icon(Icons.lock),
                            label: Text('افتح من المتجر'),
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text('اختر لون الثيم', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedThemeColor ?? colorScheme.primary)),
              SizedBox(height: 10),
              _canEditProfileColor
                ? Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: _themeColors.map((color) => GestureDetector(
                      onTap: () {
                        setState(() { _selectedThemeColor = color; });
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedThemeColor == color ? Colors.black : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: _selectedThemeColor == color ? [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ] : [],
                        ),
                        child: _selectedThemeColor == color ? Icon(Icons.check, color: Colors.white) : null,
                      ),
                    )).toList(),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => StreaksStore(showIntro: false)));
                    },
                    icon: Icon(Icons.lock),
                    label: Text('افتح من المتجر'),
                  ),
              SizedBox(height: 28),
              
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
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
                    child: TextFormField(
                      controller: _nameController,
                      enabled: !_isLoading,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'الاسم',
                        labelStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال الاسم';
                        }
                        if (value.length < 2) {
                          return 'الاسم يجب أن يكون 2 أحرف على الأقل';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
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
                    child: TextFormField(
                      controller: _bioController,
                      enabled: !_isLoading,
                      textDirection: TextDirection.rtl,
                      maxLines: 4,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: 'نبذة شخصية (اختياري)',
                        labelStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                        prefixIcon: Icon(
                          Icons.edit_note,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
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
                ),
              ),
              
              SizedBox(height: 32),
              
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          _selectedThemeColor ?? colorScheme.primary,
                          (_selectedThemeColor ?? colorScheme.primary).withOpacity(0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_selectedThemeColor ?? colorScheme.primary).withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isLoading ? null : _saveProfile,
                        child: Center(
                          child: _isLoading
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
                                      'جاري الحفظ...',
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
                                      Icons.save,
                                      color: colorScheme.onPrimary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'حفظ التغييرات',
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
                ),
              ),
              
              SizedBox(height: 16),
              
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
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
                          'يمكنك تحديث معلوماتك الشخصية في أي وقت',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      );
  }
}
