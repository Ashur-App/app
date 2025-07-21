import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'reel_video_player.dart';
import 'reel_comments.dart';
import '../user_badges.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:file_saver/file_saver.dart';
import '../storage.dart';
import 'profile_analytics.dart';


String _encodeUidForPath(String? uid) {
  if (uid == null) return '';
  return uid.replaceAll('.', '_dot_').replaceAll('@', '_at_').replaceAll('#', '_hash_').replaceAll('\$', '_dollar_').replaceAll('[', '_lbracket_').replaceAll(']', '_rbracket_').replaceAll('/', '_slash_');
}

class _ReelControllerState {
  VideoPlayerController? controller;
  bool isLoading = false;
  bool hasError = false;
  int retryCount = 0;
}

class ReelsScreen extends StatefulWidget {
  final String? initialReelId;
  final void Function(String userId)? onProfileTap;
  final String? onlyUserId;
  final bool filterByPrivacy;
  const ReelsScreen({super.key, this.initialReelId, this.onProfileTap, this.onlyUserId, this.filterByPrivacy = false});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late PageController _pageController;
  List<Map<String, dynamic>> _reels = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, dynamic> _userCache = {};
  final Map<String, _ReelControllerState> _controllerStates = {};
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  Future<void> _loadReels() async {
    try {
      setState(() {
        _isLoading = true;
      });
      print('Loading reels from Firebase...');
      print('Testing Firebase connection...');
      DataSnapshot testSnapshot = await FirebaseDatabase.instance.ref().get();
      print('Root snapshot exists:  [38;5;2m${testSnapshot.exists} [0m');
      DataSnapshot snapshot = await FirebaseDatabase.instance
          .ref()
          .child('reels')
          .get();
      print('Reels snapshot exists: ${snapshot.exists}');
      print('Reels snapshot value: ${snapshot.value}');
      print('Reels snapshot children count: ${snapshot.children.length}');
      if (snapshot.value != null) {
        List<Map<String, dynamic>> reels = [];
        (snapshot.value as Map<Object?, Object?>).forEach((key, value) {
          print('Processing reel key: $key');
          print('Reel value: $value');
          Map<String, dynamic> reelData = Map<String, dynamic>.from(value as Map<Object?, Object?>);
          reelData['id'] = key;
          reels.add(reelData);
        });
        print('Total reels found: ${reels.length}');
        if (widget.filterByPrivacy) {
          final currentUser = FirebaseAuth.instance.currentUser;
          List<Map<String, dynamic>> filtered = [];
          for (final reel in reels) {
            final userId = reel['uid'];
            final userData = await _getUserData(userId);
            if (await _canViewUserContent(currentUser, userId, userData)) {
              filtered.add(reel);
            }
          }
          reels = filtered;
        }
        reels = _sortReelsByEngagement(reels);
        setState(() {
          _reels = reels;
          _isLoading = false;
        });
        if (_reels.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onPageChanged(0);
          });
        }
        print('Reels loaded successfully: ${_reels.length}');
        _initializeControllers(0, 2);
      } else {
        print('No reels data found');
        setState(() {
          _reels = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading reels: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeControllers(int startIndex, int count) async {
    for (int i = startIndex; i < startIndex + count && i < _reels.length; i++) {
      var reel = _reels[i];
      String? videoUrl = reel['vid'];
      
      if (videoUrl != null && videoUrl.isNotEmpty && !_controllers.containsKey(reel['id'])) {
        try {
          var controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
          await controller.initialize();
          _controllers[reel['id']] = controller;
        } catch (e) {
          print('Error initializing video controller: $e');
        }
      }
    }
  }

  Future<void> _robustInitializeControllers(List<Map<String, dynamic>> reels, int centerIndex) async {
    final indices = [centerIndex - 1, centerIndex, centerIndex + 1];
    for (int i = 0; i < reels.length; i++) {
      var reel = reels[i];
      final id = reel['id'];
      if (!indices.contains(i)) {
        if (_controllerStates[id]?.controller != null) {
          _controllerStates[id]?.controller?.dispose();
        }
        _controllerStates.remove(id);
        continue;
      }
      if (_controllerStates[id]?.controller != null && _controllerStates[id]!.hasError == false) continue;
      _controllerStates[id] = _controllerStates[id] ?? _ReelControllerState();
      _controllerStates[id]!.isLoading = true;
      _controllerStates[id]!.hasError = false;
      _controllerStates[id]!.retryCount = _controllerStates[id]!.retryCount;
      String? videoUrl = reel['vid'];
      if (videoUrl != null && videoUrl.isNotEmpty) {
        try {
          var controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
          await controller.initialize();
          _controllerStates[id]!.controller = controller;
          _controllerStates[id]!.isLoading = false;
          _controllerStates[id]!.hasError = false;
        } catch (e) {
          _controllerStates[id]!.isLoading = false;
          _controllerStates[id]!.hasError = true;
          _controllerStates[id]!.retryCount++;
          if (_controllerStates[id]!.retryCount <= _maxRetries) {
            await Future.delayed(Duration(milliseconds: 500));
            await _robustInitializeControllers([reel], 0);
          }
        }
      }
    }
    setState(() {});
  }

  void _onPageChanged(int index) async {
    setState(() {
      _currentIndex = index;
    });
    for (var state in _controllerStates.values) {
      state.controller?.pause();
    }
    final filteredReels = widget.onlyUserId != null
        ? _reels.where((reel) => reel['uid'] == widget.onlyUserId).toList()
        : _reels;
    await _robustInitializeControllers(filteredReels, _currentIndex);
    if (_currentIndex < filteredReels.length) {
      var currentReel = filteredReels[_currentIndex];
      var state = _controllerStates[currentReel['id']];
      if (state?.controller != null) {
        state!.controller!.play();
        state.controller!.setLooping(true);
      }
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      DatabaseEvent event = await FirebaseDatabase.instance
          .ref('users')
          .child(_encodeUidForPath(userId))
          .once();

      if (event.snapshot.exists) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(event.snapshot.value as Map<Object?, Object?>);
        _userCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      DateTime postTime;
      
      if (timestamp is int) {
        postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is String) {
        postTime = DateTime.parse(timestamp);
      } else {
        return timestamp.toString();
      }
      
      Duration difference = DateTime.now().difference(postTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } catch (e) {
      print('Error formatting timestamp: $e');
      return timestamp.toString();
    }
  }

  Future<void> _updateReelLikeStatus(Map<String, dynamic> reel, String action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      HapticFeedback.lightImpact();
      String uid = user.uid;
      String? reelId = reel['id'];
      if (reelId == null) return;
      final userActions = Map<String, dynamic>.from(reel['userActions'] ?? {});
      final userAction = userActions[uid];
      if (userAction == null || userAction != action) {
        userActions[uid] = action;
        DatabaseReference reelRef = FirebaseDatabase.instance.ref('reels').child(reelId);
        await reelRef.update({
          'userActions': userActions,
        });
        setState(() {
          final idx = _reels.indexWhere((r) => r['id'] == reelId);
          if (idx != -1) {
            _reels[idx]['userActions'] = Map<String, dynamic>.from(userActions);
          }
        });
        if (action == 'like') await incrementChallengeProgress('إعجاب ريل');
      }
    }
  }

  bool _isReelLiked(Map<String, dynamic> reel) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      final userActions = Map<String, dynamic>.from(reel['userActions'] ?? {});
      final userAction = userActions[uid];
      return userAction == 'like';
    }
    return false;
  }

  Future<void> _updateReelShareCount(Map<String, dynamic> reel) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      HapticFeedback.mediumImpact();
      String? reelId = reel['id'];
      
      if (reelId == null) return;
      
      Map<String, dynamic> reelData = reel;
      final currentShares = reelData['shares'] ?? 0;
      
      DatabaseReference reelRef = FirebaseDatabase.instance.ref('reels').child(reelId);
      
      await reelRef.update({
        'shares': currentShares + 1,
      });
      await incrementChallengeProgress('مشاركة ريل');
    }
  }

  List<Map<String, dynamic>> _sortReelsByEngagement(List<Map<String, dynamic>> reels) {
    final now = DateTime.now();
    List<String> followedUsers = [];
    Map<String, int> followerCounts = {};
    _userCache.forEach((uid, userData) {
      if (userData != null && userData['followers'] != null) {
        if (userData['followers'] is List) {
          followerCounts[uid] = (userData['followers'] as List).length;
        } else if (userData['followers'] is Map) {
          followerCounts[uid] = (userData['followers'] as Map).length;
        }
      } else {
        followerCounts[uid] = 0;
      }
    });
    List<int> counts = followerCounts.values.toList()..sort((a, b) => b.compareTo(a));
    int threshold = counts.isNotEmpty ? counts[(counts.length * 0.1).floor().clamp(0, counts.length - 1)] : 0;
    Set<String> topUsers = followerCounts.entries
      .where((e) => e.value >= threshold && threshold > 0)
      .map((e) => e.key)
      .toSet();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _userCache.containsKey(user.uid)) {
      final userData = _userCache[user.uid];
      if (userData != null && userData['following'] != null) {
        if (userData['following'] is List) {
          followedUsers = List<String>.from(userData['following']);
        } else if (userData['following'] is Map) {
          followedUsers = (userData['following'] as Map).keys.map((e) => e.toString()).toList();
        }
      }
    }
    List<Map<String, dynamic>> scoredReels = reels.map((reel) {
      final userActions = Map<String, dynamic>.from(reel['userActions'] ?? {});
      final likes = userActions.values.where((v) => v == 'like').length;
      int comments = 0;
      if (reel['comments'] != null) {
        if (reel['comments'] is List) {
          comments = (reel['comments'] as List).length;
        } else if (reel['comments'] is Map) {
          comments = (reel['comments'] as Map).length;
        }
      }
      int shares = reel['shares'] ?? 0;
      String userId = reel['uid'] ?? '';
      DateTime reelTime;
      try {
        if (reel['timestamp'] is int) {
          reelTime = DateTime.fromMillisecondsSinceEpoch(reel['timestamp']);
        } else {
          reelTime = DateTime.parse(reel['timestamp'] ?? '');
        }
      } catch (_) {
        reelTime = now;
      }
      final hours = now.difference(reelTime).inHours.clamp(1, 72);
      double engagement = likes * 1.0 + comments * 2.5 + shares * 4.0;
      double decay = 1 / (1 + hours * 0.3);
      double recencyBoost = hours < 1 ? 2.0 : (hours < 6 ? 1.5 : (hours < 24 ? 1.2 : 1.0));
      double followBoost = followedUsers.contains(userId) ? 1.5 : 1.0;
      double topUserBoost = topUsers.contains(userId) ? 1.5 : 1.0;
      double score = engagement * decay * recencyBoost * followBoost * topUserBoost;
      if (hours > 48 && engagement < 2) score *= 0.5;
      if (hours < 1) score += 1000;
      return {
        ...reel,
        '_engagementScore': score,
      };
    }).toList();
    scoredReels.sort((a, b) => (b['_engagementScore'] as double).compareTo(a['_engagementScore'] as double));
    return scoredReels;
  }

  Future<void> _saveFile(String url, String fileName) async {
    try {
      String ext = fileName.split('.').last.toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'mp4') {
        final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
        final bytes = response.data;
        Directory? dir;
        if (ext == 'mp4') {
          dir = await getExternalStorageDirectory();
          if (dir != null) {
            dir = Directory('/storage/emulated/0/DCIM');
          }
        } else {
          dir = await getExternalStorageDirectory();
          if (dir != null) {
            dir = Directory('/storage/emulated/0/Pictures');
          }
        }
        if (dir == null) throw Exception('لم يتم العثور على مجلد التخزين');
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        const platform = MethodChannel('ashur.media_scan');
        try {
          await platform.invokeMethod('scanFile', {'path': file.path});
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الملف في المعرض')),
        );
      } else if (ext == 'aac') {
        final response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
        final bytes = response.data;
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          mimeType: MimeType.aac,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ الصوت')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('نوع الملف غير مدعوم')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ الملف: $e')),
      );
    }
  }

  Future<bool> _canViewUserContent(User? currentUser, String userId, Map<String, dynamic>? userData) async {
    if (currentUser == null) return false;
    if (currentUser.uid == userId) return true;
    if (userData == null) {
      DatabaseEvent event = await FirebaseDatabase.instance.ref('users').child(_encodeUidForPath(userId)).once();
      if (!event.snapshot.exists) return false;
      userData = Map<String, dynamic>.from(event.snapshot.value as Map<Object?, Object?>);
    }
    if (userData['private'] != true) return true;
    final followers = userData['followers'];
    if (followers is List && followers.contains(currentUser.uid)) return true;
    if (followers is Map && followers.containsKey(currentUser.uid)) return true;
    return false;
  }

  Future<void> _incrementReelView(String reelId) async {
    final ref = FirebaseDatabase.instance.ref('reels').child(reelId);
    final snap = await ref.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      int views = (data['views'] ?? 0) as int;
      await ref.update({'views': views + 1});
    }
  }
  Future<void> _addWatchTime(String reelId, int ms) async {
    final ref = FirebaseDatabase.instance.ref('reels').child(reelId);
    final snap = await ref.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      int watchTime = (data['watchTime'] ?? 0) as int;
      await ref.update({'watchTime': watchTime + ms});
    }
  }
  int _lastWatchStart = 0;
  @override
  Widget build(BuildContext context) {
    print('Building ReelsScreen - isLoading: $_isLoading, reels count: ${_reels.length}');
    final colorScheme = Theme.of(context).colorScheme;
    final filteredReels = widget.onlyUserId != null
        ? _reels.where((reel) => reel['uid'] == widget.onlyUserId).toList()
        : _reels;

    if (!_isLoading && filteredReels.isNotEmpty) {
      _initializeControllers(0, 2);
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    if (filteredReels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 64,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              SizedBox(height: 16),
              Text(
                'لا توجد ريلز',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Debug: Check console for loading details',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentReel = filteredReels.isNotEmpty && _currentIndex < filteredReels.length
        ? filteredReels[_currentIndex]
        : null;
    final currentController = currentReel != null ? _controllerStates[currentReel['id']]?.controller : null;
    if (currentReel != null) {
      if (_lastWatchStart == 0) {
        _lastWatchStart = DateTime.now().millisecondsSinceEpoch;
        _incrementReelView(currentReel['id']);
      }
      currentController?.addListener(() {
        if (currentController.value.position >= currentController.value.duration) {
          if (_lastWatchStart > 0) {
            final now = DateTime.now().millisecondsSinceEpoch;
            _addWatchTime(currentReel['id'], now - _lastWatchStart);
            _lastWatchStart = 0;
          }
        }
      });
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) {
              if (_lastWatchStart > 0 && currentReel != null) {
                final now = DateTime.now().millisecondsSinceEpoch;
                _addWatchTime(currentReel['id'], now - _lastWatchStart);
              }
              _lastWatchStart = DateTime.now().millisecondsSinceEpoch;
              _onPageChanged(i);
            },
            itemCount: filteredReels.length,
            itemBuilder: (context, index) {
              var reel = filteredReels[index];
              final state = _controllerStates[reel['id']];
              if (state == null || state.isLoading) {
                return Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (state.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 12),
                      Text('فشل تحميل الفيديو', style: TextStyle(color: Colors.white)),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _robustInitializeControllers([reel], 0),
                        child: Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
              }
              return _buildReelView(reel, index, controller: state.controller);
            },
          ),
          if (currentController != null && currentController.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: currentController,
                builder: (context, value, child) {
                  final duration = value.duration.inMilliseconds > 0 ? value.duration.inMilliseconds : 1;
                  final position = value.position.inMilliseconds.clamp(0, duration).toDouble();
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: _MinimalThumb(),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: colorScheme.onSurface.withOpacity(0.12),
                      trackShape: RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      min: 0.0,
                      max: duration.toDouble(),
                      value: position,
                      onChanged: (value) {
                        currentController.seekTo(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReelView(Map<String, dynamic> reel, int index, {VideoPlayerController? controller}) {
    final hasController = controller != null && controller.value.isInitialized;
    final userActions = Map<String, dynamic>.from(reel['userActions'] ?? {});
    final likes = userActions.values.where((v) => v == 'like').length;
    final isLiked = _isReelLiked(reel);
    if (!hasController) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: () {
              if (!isLiked) _updateReelLikeStatus(reel, 'like');
            },
            child: ReelVideoPlayer(
              videoUrl: reel['vid'],
              controller: controller,
              isActive: index == _currentIndex,
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              _buildActionButton(
                icon: _isReelLiked(reel) ? Icons.favorite : Icons.favorite_border,
                color: _isReelLiked(reel) ? Colors.red : Colors.white,
                onTap: () => _updateReelLikeStatus(reel, _isReelLiked(reel) ? 'dislike' : 'like'),
              ),
              SizedBox(height: 16),
              Text(
                '$likes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ReelsCommentsScreen(postId: reel['id'])));
                },
              ),
              SizedBox(height: 24),
              _buildActionButton(
                icon: Icons.share,
                onTap: () {
                  _updateReelShareCount(reel);
                  Share.share('Check out this reel on Ashur: ${reel['desc']}\n${reel['vid']}');
                },
              ),
              SizedBox(height: 16),
              Text(
                '${reel['shares'] ?? 0}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildActionButton(
                icon: Icons.download_rounded,
                color: Colors.white,
                onTap: () {
                  _saveFile(reel['vid'], 'ashur_reel_${reel['id'] ?? DateTime.now().millisecondsSinceEpoch}.mp4');
                },
              ),
              SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final isOwner = currentUser != null && reel['uid'] == currentUser.uid;
                  if (isOwner) {
                    return _buildActionButton(
                      icon: Icons.analytics,
                      color: Colors.amber,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileAnalyticsPage()));
                      },
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 80,
          bottom: 16,
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _getUserData(reel['uid']),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const SizedBox.shrink();
              }
              
              var userData = userSnapshot.data!;
              String username = userData['username'] ?? 'Unknown';
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.onProfileTap != null) {
                        widget.onProfileTap!(reel['uid']);
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: userData['pic']?.isNotEmpty == true
                              ? NetworkImage(userData['pic'])
                              : AssetImage('images/ashur.png') as ImageProvider,
                          radius: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '@$username',
                                    style: TextStyle(
                                      color: userData['profileTheme'] != null && userData['profileTheme'].toString().isNotEmpty ? Color(int.parse(userData['profileTheme'].toString())) : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  UserBadges(userData: userData, iconSize: 16),
                                ],
                              ),
                              Text(
                                _formatTimestamp(reel['timestamp']),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reel['desc']?.isNotEmpty == true) ...[
                    SizedBox(height: 12),
                    Text(
                      reel['desc'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    Color? color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color ?? Colors.white,
          size: 24,
        ),
      ),
    );
  }
} 

class _MinimalThumb extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(8, 8);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    if (activationAnimation.value > 0.0) {
      final paint = Paint()
        ..color = sliderTheme.thumbColor ?? Colors.white
        ..style = PaintingStyle.fill;
      context.canvas.drawCircle(center, 5, paint);
    }
  }
} 