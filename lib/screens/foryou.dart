import 'package:ashur/screens/aichat.dart';
import 'package:ashur/screens/groupchat.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'chatscreen.dart';
import 'editprofile.dart';
import 'addscreen.dart';
import 'addreel.dart';
import 'addstory.dart';
import 'story.dart';
import 'comments.dart';
import 'newgroup.dart';
import 'package:firebase_database/firebase_database.dart';
import 'games.dart';
import 'package:flutter/services.dart';
import 'reels_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../user_badges.dart';
import 'reel_video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'streaks_store.dart';
import 'package:file_saver/file_saver.dart';
import '../storage.dart';
import 'settings.dart';
import 'notification_center.dart';

String _encodeUidForPath(String? uid) {
  if (uid == null) return '';
  return uid.replaceAll('.', '_dot_').replaceAll('@', '_at_').replaceAll('#', '_hash_').replaceAll('\$', '_dollar_').replaceAll('[', '_lbracket_').replaceAll(']', '_rbracket_').replaceAll('/', '_slash_');
}

class foryouscreen extends StatefulWidget {
  final String? type;
  final String? id;
  final bool showBottomBar;
  const foryouscreen({super.key, this.type, this.id, this.showBottomBar = true});

  @override
  State<foryouscreen> createState() => _foryouscreenState();
}

class _foryouscreenState extends State<foryouscreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _tabController2;
  late TabController _chatTabController;
  late TabController _mainFeedTabController;
  int selectedPageIndex = 0;
  late String searchQuery = '';
  late String userPicc = '';
  String? selectedEmail;
  String? currentUsername;
  String? username;
  late PageController _reelsPageController;
  late String userUID;
  final Map<String, dynamic> _userCache = {};
  List<Map<String, dynamic>> _cachedPosts = [];
  bool _isLoadingPosts = false;
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _streakCount = 0;
  bool _isLoadingStreak = false;
  String? userProfilePic;

  Future<String> _getCurrentUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
    final snap = await ref.get();
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      return data['username'] ?? user.displayName ?? user.email?.split('@')[0] ?? 'مستخدم';
    }
    return user.displayName ?? user.email?.split('@')[0] ?? 'مستخدم';
  }

  Future<int> calculateStreakForUser(String uid) async {
    int postsCount = 0;
    int reelsCount = 0;
    int followersCount = 0;
    int likesCount = 0;
    int commentsCount = 0;
    int sharesCount = 0;
    int chatsCount = 0;
    DataSnapshot postsSnapshot = await FirebaseDatabase.instance.ref('posts').get();
    if (postsSnapshot.exists && postsSnapshot.value != null) {
      (postsSnapshot.value as Map<Object?, Object?>).forEach((key, value) {
        final post = Map<String, dynamic>.from(value as Map<Object?, Object?>);
        if (post['userEmail'] == uid) {
          postsCount++;
          likesCount += ((post['likes'] ?? 0) as num).toInt();
          sharesCount += ((post['shares'] ?? 0) as num).toInt();
          if (post['comments'] != null) {
            if (post['comments'] is List) {
              commentsCount += (post['comments'] as List).length;
            } else if (post['comments'] is Map) {
              commentsCount += (post['comments'] as Map).length;
            }
          }
        }
      });
    }
    DataSnapshot reelsSnapshot = await FirebaseDatabase.instance.ref('reels').get();
    if (reelsSnapshot.exists && reelsSnapshot.value != null) {
      (reelsSnapshot.value as Map<Object?, Object?>).forEach((key, value) {
        final reel = Map<String, dynamic>.from(value as Map<Object?, Object?>);
        if (reel['uid'] == uid) {
          reelsCount++;
          likesCount += ((reel['likes'] ?? 0) as num).toInt();
          sharesCount += ((reel['shares'] ?? 0) as num).toInt();
          if (reel['comments'] != null) {
            if (reel['comments'] is List) {
              commentsCount += (reel['comments'] as List).length;
            } else if (reel['comments'] is Map) {
              commentsCount += (reel['comments'] as Map).length;
            }
          }
        }
      });
    }
    DataSnapshot userSnapshot = await FirebaseDatabase.instance.ref('users/$uid').get();
    int spent = 0;
    if (userSnapshot.exists && userSnapshot.value != null) {
      final userData = Map<String, dynamic>.from(userSnapshot.value as Map<Object?, Object?>);
      if (userData['followers'] != null) {
        if (userData['followers'] is List) {
          followersCount = (userData['followers'] as List).length;
        } else if (userData['followers'] is Map) {
          followersCount = (userData['followers'] as Map).length;
        } else if (userData['followers'] is int) {
          followersCount = userData['followers'];
        }
      }
      chatsCount = 0;
      userData.forEach((key, value) {
        if (key != 'followers' && key != 'username' && key != 'id' && key != 'pic' && key != 'bio' && key != 'email' && key != 'name' && key != 'verify' && key != 'stories' && key != 'story' && key != 'mod' && key != 'contributor' && key != 'team') {
          chatsCount++;
        }
      });
      if (userData['spentStreaks'] != null) {
        final val = userData['spentStreaks'];
        if (val is num) {
          spent = val.toInt();
        } else if (val is Map) {
          for (final entry in val.values) {
            if (entry is Map && entry['cost'] is num) {
              spent += (entry['cost'] as num).toInt();
            }
          }
        }
      }
    }
    int streak = (postsCount * 1) + (reelsCount * 2) + (followersCount * 1) + (likesCount * 0.5).round() + (commentsCount * 1) + (sharesCount * 1) + (chatsCount * 1);
    return streak - spent;
  }

  Future<void> _calculateStreak() async {
    setState(() {
      _isLoadingStreak = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _streakCount = 0;
        _isLoadingStreak = false;
      });
      return;
    }
    String uid = user.uid;
    int postsCount = 0;
    int reelsCount = 0;
    int followersCount = 0;
    int likesCount = 0;
    int commentsCount = 0;
    int sharesCount = 0;
    int chatsCount = 0;
    DataSnapshot postsSnapshot = await FirebaseDatabase.instance.ref('posts').get();
    if (postsSnapshot.exists && postsSnapshot.value != null) {
      (postsSnapshot.value as Map<Object?, Object?>).forEach((key, value) {
        final post = Map<String, dynamic>.from(value as Map<Object?, Object?>);
        if (post['userEmail'] == uid) {
          postsCount++;
          likesCount += ((post['likes'] ?? 0) as num).toInt();
          sharesCount += ((post['shares'] ?? 0) as num).toInt();
          if (post['comments'] != null) {
            if (post['comments'] is List) {
              commentsCount += (post['comments'] as List).length;
            } else if (post['comments'] is Map) {
              commentsCount += (post['comments'] as Map).length;
            }
          }
        }
      });
    }
    DataSnapshot reelsSnapshot = await FirebaseDatabase.instance.ref('reels').get();
    if (reelsSnapshot.exists && reelsSnapshot.value != null) {
      (reelsSnapshot.value as Map<Object?, Object?>).forEach((key, value) {
        final reel = Map<String, dynamic>.from(value as Map<Object?, Object?>);
        if (reel['uid'] == uid) {
          reelsCount++;
          likesCount += ((reel['likes'] ?? 0) as num).toInt();
          sharesCount += ((reel['shares'] ?? 0) as num).toInt();
          if (reel['comments'] != null) {
            if (reel['comments'] is List) {
              commentsCount += (reel['comments'] as List).length;
            } else if (reel['comments'] is Map) {
              commentsCount += (reel['comments'] as Map).length;
            }
          }
        }
      });
    }
    DataSnapshot userSnapshot = await FirebaseDatabase.instance.ref('users/$uid').get();
    int spent = 0;
    if (userSnapshot.exists && userSnapshot.value != null) {
      final userData = Map<String, dynamic>.from(userSnapshot.value as Map<Object?, Object?>);
      if (userData['followers'] != null) {
        if (userData['followers'] is List) {
          followersCount = (userData['followers'] as List).length;
        } else if (userData['followers'] is Map) {
          followersCount = (userData['followers'] as Map).length;
        } else if (userData['followers'] is int) {
          followersCount = userData['followers'];
        }
      }
      chatsCount = 0;
      userData.forEach((key, value) {
        if (key != 'followers' && key != 'username' && key != 'id' && key != 'pic' && key != 'bio' && key != 'email' && key != 'name' && key != 'verify' && key != 'stories' && key != 'story' && key != 'mod' && key != 'contributor' && key != 'team') {
          chatsCount++;
        }
      });
      if (userData['spentStreaks'] != null) {
        final val = userData['spentStreaks'];
        if (val is num) {
          spent = val.toInt();
        } else if (val is Map) {
          for (final entry in val.values) {
            if (entry is Map && entry['cost'] is num) {
              spent += (entry['cost'] as num).toInt();
            }
          }
        }
      }
    }
    int streak = (postsCount * 1) + (reelsCount * 2) + (followersCount * 1) + (likesCount * 0.5).round() + (commentsCount * 1) + (sharesCount * 1) + (chatsCount * 1);
    setState(() {
      _streakCount = streak - spent;
      _isLoadingStreak = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController2 = TabController(length: 6, vsync: this);
    _chatTabController = TabController(length: 2, vsync: this);
    _mainFeedTabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _getUserUID();
    _getCurrentUsername();
    _reelsPageController = PageController();
    _loadPosts();
    _animationController.forward();
    _calculateStreak();
    _fetchUserProfilePic();
    if (widget.id != null) {
      selectedEmail = widget.id;
      selectedPageIndex = 4;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(4);
        _tabController2.animateTo(4);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.type == 'reel') {
        _tabController.animateTo(2);
        _tabController2.animateTo(2);
        _scrollToReelWithId();
      }
    });
  }

  Future<void> _fetchUserProfilePic() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
      final snap = await ref.get();
      if (snap.exists && snap.value != null) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          userProfilePic = data['pic'];
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tabController2.dispose();
    _chatTabController.dispose();
    _mainFeedTabController.dispose();
    _reelsPageController.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getUserUID() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        userUID = user.uid;
      });
    }
  }

  void _scrollToReelWithId() {}

  Future<void> _loadPosts() async {
    if (_isLoadingPosts) return;
    setState(() {
      _isLoadingPosts = true;
    });
    try {
      DataSnapshot snapshot = await FirebaseDatabase.instance
          .ref()
          .child('posts')
          .get();
      
      if (snapshot.value != null) {
        List<Map<String, dynamic>> posts = [];
        (snapshot.value as Map<Object?, Object?>).forEach((key, value) {
          posts.add(Map<String, dynamic>.from(value as Map<Object?, Object?>));
        });
        posts = _sortPostsByEngagement(posts);
        setState(() {
          _cachedPosts = posts;
          _isLoadingPosts = false;
        });
      } else {
        setState(() {
          _cachedPosts = [];
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  List<Map<String, dynamic>> _sortPostsByEngagement(List<Map<String, dynamic>> posts) {
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
    if (_userCache.containsKey(userUID)) {
      final userData = _userCache[userUID];
      if (userData != null && userData['following'] != null) {
        if (userData['following'] is List) {
          followedUsers = List<String>.from(userData['following']);
        } else if (userData['following'] is Map) {
          followedUsers = (userData['following'] as Map).keys.map((e) => e.toString()).toList();
        }
      }
    }
    List<Map<String, dynamic>> scoredPosts = posts.map((post) {
      int likes = ((post['likes'] ?? 0) as num).toInt();
      int comments = 0;
      if (post['comments'] != null) {
        if (post['comments'] is List) {
          comments = (post['comments'] as List).length;
        } else if (post['comments'] is Map) {
          comments = (post['comments'] as Map).length;
        }
      }
      int shares = ((post['shares'] ?? 0) as num).toInt();
      String userId = post['userEmail'] ?? '';
      DateTime postTime;
      try {
        postTime = DateTime.parse(post['timestamp'] ?? '');
      } catch (_) {
        postTime = now;
      }
      final hours = now.difference(postTime).inHours.clamp(1, 72);
      double engagement = likes * 1.0 + comments * 2.5 + shares * 4.0;
      double decay = 1 / (1 + hours * 0.3);
      double recencyBoost = hours < 1 ? 2.0 : (hours < 6 ? 1.5 : (hours < 24 ? 1.2 : 1.0));
      double followBoost = followedUsers.contains(userId) ? 1.5 : 1.0;
      double topUserBoost = topUsers.contains(userId) ? 1.5 : 1.0;
      double selfBoost = (userUID == userId) ? 5.0 : 1.0;
      double score = engagement * decay * recencyBoost * followBoost * topUserBoost * selfBoost;
      if (hours > 48 && engagement < 2) score *= 0.5;
      if (hours < 1) score += 1000;
      return {
        ...post,
        '_engagementScore': score,
      };
    }).toList();
    scoredPosts.sort((a, b) => (b['_engagementScore'] as double).compareTo(a['_engagementScore'] as double));
    return scoredPosts;
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
      if (event.snapshot.exists && event.snapshot.value != null) {
        final value = event.snapshot.value;
        if (value is Map) {
          Map<String, dynamic> userData = Map<String, dynamic>.from(value as Map<Object?, Object?>);
          _userCache[userId] = userData;
          return userData;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل بيانات المستخدم: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
    return null;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      String timestampStr = timestamp.toString();
      DateTime postTime = DateTime.parse(timestampStr);
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
      return timestamp.toString();
    }
  }

  Future<void> _updateLikeStatus(
      Map<String, dynamic> postSnapshot, String action) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      HapticFeedback.lightImpact();
      String uid = user.uid;
      DatabaseReference postRef = FirebaseDatabase.instance
          .ref()
          .child('posts')
          .child(postSnapshot['id']);
      Map<String, dynamic> postData = Map<String, dynamic>.from(postSnapshot);
      final userActions = Map<String, dynamic>.from(postData['userActions'] ?? {});
      final userAction = userActions[uid];
      if (userAction == null || userAction != action) {
        userActions[uid] = action;
        await postRef.update({
          'userActions': userActions,
        });
        setState(() {
          final idx = _cachedPosts.indexWhere((p) => p['id'] == postSnapshot['id']);
          if (idx != -1) {
            _cachedPosts[idx]['userActions'] = Map<String, dynamic>.from(userActions);
          }
        });
        if (action == 'like') await incrementChallengeProgress('إعجاب منشور');
      }
    }
  }

  Future<void> _updateReelLikeStatus(
    Map<String, dynamic>? reelSnapshot,
    String action,
  ) async {
    if (reelSnapshot != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        HapticFeedback.lightImpact();
        String uid = user.uid;
        String? reelId = reelSnapshot['id'];
        
        if (reelId == null) {
          print('Error: Reel ID is null');
          return;
        }
        
        Map<String, dynamic> reelData = reelSnapshot;
        final currentLikes = ((reelData['likes'] ?? 0) as num).toInt();
        final userAction = reelData['userActions']?[uid];

        if (userAction == null || userAction != action) {
          final newLikes = (userAction == null || userAction == 'dislike')
              ? currentLikes + 1
              : currentLikes - 1;

          DatabaseReference reelRef =
              FirebaseDatabase.instance.ref('reels').child(reelId);

          await reelRef.update({
            'userActions': {uid: action},
            'likes': newLikes,
          });
        }
      }
    }
  }

  bool _isLiked(Map<String, dynamic> postSnapshot) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      final userActions = Map<String, dynamic>.from(postSnapshot['userActions'] ?? {});
      final userAction = userActions[uid];
      return userAction == 'like';
    }
    return false;
  }

  bool _isReelLiked(Map<String, dynamic>? reelSnapshot) {
    if (reelSnapshot != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String uid = user.uid;
        final userAction = reelSnapshot['userActions']?[uid];
        return userAction == 'like';
      }
    }
    return false;
  }

  Future<void> _updateShareCount(Map<String, dynamic> postSnapshot) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      HapticFeedback.mediumImpact();
      DatabaseReference postRef = FirebaseDatabase.instance
          .ref()
          .child('posts')
          .child(postSnapshot['id']);
      Map<String, dynamic> postData = Map<String, dynamic>.from(postSnapshot);
      final currentShares = ((postData['shares'] ?? 0) as num).toInt();
      await postRef.update({
        'shares': currentShares + 1,
      });
      await _loadPosts();
      await incrementChallengeProgress('مشاركة منشور');
    }
  }

  Future<void> _updateReelShareCount(Map<String, dynamic>? reelSnapshot) async {
    if (reelSnapshot != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        HapticFeedback.mediumImpact();
        String? reelId = reelSnapshot['id'];
        
        if (reelId == null) {
          print('Error: Reel ID is null');
          return;
        }
        
        Map<String, dynamic> reelData = reelSnapshot;
        final currentShares = ((reelData['shares'] ?? 0) as num).toInt();
        
        DatabaseReference reelRef =
            FirebaseDatabase.instance.ref('reels').child(reelId);
        
        await reelRef.update({
          'shares': currentShares + 1,
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600; 
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leadingWidth: isLargeScreen ? 120 : 0,
        leading: isLargeScreen
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Image.asset(
                  'images/ashur.png',
                  width: 56,
                  height: 24,
                ),
              )
            : null,
        title: selectedPageIndex == 1
            ? _buildSearchBar()
            : (selectedEmail == null
                ? (isLargeScreen
                    ? Center(
                        child: !_isLoadingStreak
                            ? null
                            : null,
                      )
                    : _buildAppBarTitle())
                : Text(
                    'الحساب',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
        actions: selectedPageIndex == 1
            ? []
            : [
                IconButton(
                  icon: Icon(Icons.notifications, color: colorScheme.onSurface),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationCenterScreen()));
                  },
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
                  onSelected: (value) {
                    if (value == 'games') {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AshurGames()));
                    } else if (value == 'ai') {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AIChatApp()));
                    } else if (value == 'settings') {
                      HapticFeedback.lightImpact();
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen()));
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'games',
                      child: ListTile(
                        leading: Icon(Icons.games_outlined),
                        title: Text('الألعاب'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ai',
                      child: ListTile(
                        leading: Icon(Icons.auto_awesome),
                        title: Text('دردشة الذكاء الاصطناعي'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('الإعدادات'),
                      ),
                    ),
                  ],
                ),
              ],
        centerTitle: !isLargeScreen,
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: isLargeScreen 
          ? Row(
              children: [
                NavigationRail(
                  extended: false,
                  minExtendedWidth: 200,
                  minWidth: 72,
                  selectedIndex: selectedPageIndex,
                  onDestinationSelected: (int index) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      selectedEmail = null;
                      selectedPageIndex = index;
                      _tabController2.animateTo(index);
                    });
                  },
                  backgroundColor: colorScheme.surface,
                  selectedIconTheme: IconThemeData(color: colorScheme.primary),
                  selectedLabelTextStyle: TextStyle(color: colorScheme.primary),
                  unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
                  unselectedLabelTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  destinations: [
                    NavigationRailDestination(
                      icon: Image.asset('images/4x/house-2@4x.png', color: colorScheme.onSurfaceVariant),
                      selectedIcon: Image.asset('images/4x/house-2@4x.png', color: colorScheme.primary),
                      label: Text('الرئيسية'),
                    ),
                    NavigationRailDestination(
                      icon: Image.asset('images/4x/magnifier@4x.png', color: colorScheme.onSurfaceVariant),
                      selectedIcon: Image.asset('images/4x/magnifier@4x.png', color: colorScheme.primary),
                      label: Text('البحث'),
                    ),
                    NavigationRailDestination(
                      icon: Image.asset('images/4x/video@4x.png', color: colorScheme.onSurfaceVariant),
                      selectedIcon: Image.asset('images/4x/video@4x.png', color: colorScheme.primary),
                      label: Text('الريلز'),
                    ),
                    NavigationRailDestination(
                      icon: Image.asset('images/4x/msg-writing@4x.png', color: colorScheme.onSurfaceVariant),
                      selectedIcon: Image.asset('images/4x/msg-writing@4x.png', color: colorScheme.primary),
                      label: Text('المحادثات'),
                    ),
                    NavigationRailDestination(
                      icon: Image.asset('images/4x/user@4x.png', color: colorScheme.onSurfaceVariant),
                      selectedIcon: Image.asset('images/4x/user@4x.png', color: colorScheme.primary),
                      label: Text('الملف الشخصي'),
                    ),
                  ],
                ),
                VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Column(
                    children: [
                      if (selectedPageIndex == 1)
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildSearchBar(),
                        ),
                      Expanded(
                        child: TabBarView(
                          physics: NeverScrollableScrollPhysics(),
                          controller: _tabController2,
                          children: [
                            selectedPageIndex == 0 ? _buildMainFeedTabs() : _buildPostsListView(),
                            _buildGlobalSearchTabs(),
                            _buildReelsListView(),
                            _buildChatsView(),
                            selectedEmail == null
                                ? _buildProfileView(userUID)
                                : _buildProfileView(selectedEmail!),
                            _buildFollowersView(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : TabBarView(
              physics: NeverScrollableScrollPhysics(),
              controller: _tabController2,
              children: [
                selectedPageIndex == 0 ? _buildMainFeedTabs() : _buildPostsListView(),
                _buildGlobalSearchTabs(),
                _buildReelsListView(),
                _buildChatsView(),
                selectedEmail == null
                    ? _buildProfileView(userUID)
                    : _buildProfileView(selectedEmail!),
                _buildFollowersView(),
              ],
            ),
      bottomNavigationBar: (isLargeScreen || !widget.showBottomBar)
          ? null
          : Container(
              height: 60,
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.12),
                    width: 1,
                  ),
                ),
              ),
              child: NavigationBar(
                height: 56,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIndex: selectedPageIndex,
                onDestinationSelected: (int index) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    selectedEmail = null;
                    selectedPageIndex = index;
                    _tabController2.animateTo(index);
                  });
                },
                destinations: [
                  NavigationDestination(
                    icon: Image.asset('images/4x/house-2@4x.png', color: Theme.of(context).colorScheme.onSurface,),
                    label: '',
                  ),
                  NavigationDestination(
                    icon: Image.asset('images/4x/magnifier@4x.png', color: Theme.of(context).colorScheme.onSurface,),
                    label: '',
                  ),
                  NavigationDestination(
                    icon: Image.asset('images/4x/video@4x.png', color: Theme.of(context).colorScheme.onSurface,),
                    label: '',
                  ),
                  NavigationDestination(
                    icon: Image.asset('images/4x/msg-writing@4x.png', color: Theme.of(context).colorScheme.onSurface,),
                    label: '',
                  ),
                  NavigationDestination(
                    icon: userProfilePic != null && userProfilePic!.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(userProfilePic!),
                            radius: 14,
                            backgroundColor: Colors.transparent,
                          )
                        : Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface, size: 28),
                    label:'',
                  ),
                ],
              ),
            ),
      floatingActionButtonLocation: isLargeScreen
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.miniCenterFloat,
      floatingActionButton: selectedPageIndex == 0
          ? AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: FloatingActionButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _showBottomSheet(context);
                    },
                    tooltip: 'منشور جديد',
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    elevation: 6,
                    child: Image.asset(
                      'images/4x/plus@4x.png',
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  void _showBottomSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    
    if (isLargeScreen) {
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 600,
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إنشاء محتوى جديد',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'اختر نوع المحتوى الذي تريد إنشاءه',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 40),
                  
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildContentOption(
                          context,
                          icon: 'images/4x/feather@4x.png',
                          title: 'منشور',
                          subtitle: 'مشاركة نص أو صورة',
                          color: Color(0xFF2196F3),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AddScreen()),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: _buildContentOption(
                          context,
                          icon: Icons.auto_stories,
                          title: 'قصة',
                          subtitle: 'قصص تختفي خلال 24 ساعة',
                          color: Color(0xFF9C27B0),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AddStoryScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildContentOption(
                          context,
                          icon: 'images/4x/video@4x.png',
                          title: 'ريلز',
                          subtitle: 'فيديو قصير',
                          color: Color(0xFF4CAF50),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AddReelScreen()),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: _buildContentOption(
                          context,
                          icon: Icons.groups_2_rounded,
                          title: 'مجموعة',
                          subtitle: 'إنشاء مجموعة جديدة',
                          color: Color(0xFFFF9800),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CreateGroupScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 40),
                  
                  
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 24),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.add_circle_outline,
                          color: colorScheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إنشاء محتوى جديد',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'اختر نوع المحتوى الذي تريد إنشاءه',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 32),
                
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildContentOption(
                              context,
                              icon: 'images/4x/feather@4x.png',
                              title: 'منشور',
                              subtitle: 'مشاركة نص أو صورة',
                              color: Color(0xFF2196F3),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AddScreen()),
                                );
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildContentOption(
                              context,
                              icon: Icons.auto_stories,
                              title: 'قصة',
                              subtitle: 'قصص تختفي خلال 24 ساعة',
                              color: Color(0xFF9C27B0),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AddStoryScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildContentOption(
                              context,
                              icon: 'images/4x/video@4x.png',
                              title: 'ريلز',
                              subtitle: 'فيديو قصير',
                              color: Color(0xFF4CAF50),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AddReelScreen()),
                                );
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildContentOption(
                              context,
                              icon: Icons.groups_2_rounded,
                              title: 'مجموعة',
                              subtitle: 'إنشاء مجموعة جديدة',
                              color: Color(0xFFFF9800),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => CreateGroupScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 32),
                
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildContentOption(
    BuildContext context, {
    dynamic icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon is String
                    ? Image.asset(
                        icon,
                        width: 24,
                        height: 24,
                        color: Colors.white,
                      )
                    : Icon(
                        icon,
                        size: 24,
                        color: Colors.white,
                      ),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() {
    return selectedPageIndex == 1
        ? _buildSearchBar()
        : Image.asset(
            'images/ashur.png',
            width: 120,
            height: 40,
          );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'اكتب اسم الشخص الذي تريد البحث عنه هنا',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (query) {
          setState(() {
            searchQuery = query;
          });
        },
      ),
    );
  }

  Widget _buildFollowersView() {
    final colorScheme = Theme.of(context).colorScheme;
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'يرجى تسجيل الدخول',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    String currentUserUID = user.uid;

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$currentUserUID').onValue,
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
                  'خطأ في تحميل المتابعين',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'لا توجد متابعين',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        Map<String, dynamic> chats = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

        List<Widget> chatWidgets = [];
        chats.forEach((key, value) {
          if (key.contains(currentUserUID)) {
            String otherUserUID = key.replaceAll('-', '').replaceAll(currentUserUID, '');
            if (otherUserUID.isEmpty) return; // Skip self-DM (saved messages)
            chatWidgets.add(
              FutureBuilder<DatabaseEvent>(
                future: FirebaseDatabase.instance.ref('users/$otherUserUID').once(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || userSnapshot.data!.snapshot.value == null) {
                    return const SizedBox.shrink();
                  }

                  Map<String, dynamic> userData = Map<String, dynamic>.from(userSnapshot.data!.snapshot.value as Map);
                  String username = userData['username'] ?? 'Unknown';
                  String profilePic = userData['pic'] ?? '';
                  bool isVerified = userData['verify'] ?? false;
                  bool hasActiveStory = false;
                  if (userData.containsKey('stories') && userData['stories'] != null) {
                    
                    final storiesData = userData['stories'];
                    final DateTime now = DateTime.now();
                    final int twentyFourHoursAgo = now.subtract(Duration(hours: 24)).millisecondsSinceEpoch;
                    
                    if (storiesData is List) {
                      
                      for (final story in storiesData) {
                        final storyData = Map<String, dynamic>.from(story as Map);
                        final int storyTimestamp = storyData['timestamp'] ?? 0;
                        if (storyTimestamp > twentyFourHoursAgo) {
                          hasActiveStory = true;
                          break;
                        }
                      }
                    } else if (storiesData is Map) {
                      
                      final storiesMap = storiesData;
                      for (final story in storiesMap.values) {
                        final storyData = Map<String, dynamic>.from(story as Map);
                        final int storyTimestamp = storyData['timestamp'] ?? 0;
                        if (storyTimestamp > twentyFourHoursAgo) {
                          hasActiveStory = true;
                          break;
                        }
                      }
                    }
                  } else if (userData.containsKey('story') && userData['story'] != null) {
                    
                    final storyData = Map<String, dynamic>.from(userData['story'] as Map);
                    final int storyTimestamp = storyData['timestamp'] ?? 0;
                    final DateTime now = DateTime.now();
                    final int twentyFourHoursAgo = now.subtract(Duration(hours: 24)).millisecondsSinceEpoch;
                    hasActiveStory = storyTimestamp > twentyFourHoursAgo;
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasActiveStory 
                                ? Colors.purple 
                                : colorScheme.primary.withValues(alpha: 0.3),
                            width: hasActiveStory ? 3 : 2,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: hasActiveStory ? () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => StoryScreen(specificUserId: otherUserUID)),
                            );
                          } : null,
                          child: CircleAvatar(
                            backgroundImage: profilePic.isNotEmpty
                                ? NetworkImage(profilePic)
                                : AssetImage('images/ashur.png') as ImageProvider,
                            radius: 25,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            '@$username',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(width: 6),
                          UserBadges(userData: userData, iconSize: 16),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            selectedEmail = otherUserUID;
                          });
                          _tabController.animateTo(4);
                          _tabController2.animateTo(4);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          'عرض الملف',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }
        });

        if (chatWidgets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'لا توجد متابعين',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(children: chatWidgets);
      },
    );
  }

  Widget _buildProfileView(String? uid) {
    final colorScheme = Theme.of(context).colorScheme;
    if (uid == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'لم يتم العثور على المستخدم',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref().child('users/${_encodeUidForPath(uid)}').onValue,
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
                  'خطأ في تحميل الملف الشخصي',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.error,
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
                  'جاري التحميل...',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_search,
                  size: 64,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'المستخدم غير موجود',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        var userData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map<Object?, Object?>);
        String name = userData['name'] ?? '';
        String profilePic = userData['pic'] ?? '';
        String username = userData['username'] ?? '';
        String followStatus = userData[FirebaseAuth.instance.currentUser!.uid] ?? 'unfollow';
        int followersCount = userData['followers'] ?? 0;
        String bio = userData['bio'] ?? '';
        bool isVerified = userData['verify'] ?? false;
        String? coverPhoto = userData['coverPhoto'];
        Color? profileTheme;
        if (userData['profileTheme'] != null) {
          try {
            profileTheme = Color(int.parse(userData['profileTheme']));
          } catch (_) {}
        }
        bool isPrivate = userData['private'] == true;
        List blockedUsers = List.from(userData['blockedUsers'] ?? []);
        String currentUid = FirebaseAuth.instance.currentUser!.uid;
        bool isBlocked = blockedUsers.contains(currentUid);
        bool iBlocked = false;
        List myBlocked = [];
        if (currentUid != uid) {
          myBlocked = List.from((snapshot.data!.snapshot.child('blockedUsers').value as List?) ?? []);
          iBlocked = myBlocked.contains(uid);
        }
        if (iBlocked) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 64, color: colorScheme.error),
                SizedBox(height: 16),
                Text('لقد قمت بحظر هذا المستخدم', style: TextStyle(fontSize: 18, color: colorScheme.error)),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    myBlocked.remove(uid);
                    await FirebaseDatabase.instance.ref('users/$currentUid').update({'blockedUsers': myBlocked});
                    setState(() {});
                  },
                  child: Text('إلغاء الحظر'),
                ),
              ],
            ),
          );
        }
        if (isPrivate && currentUid != uid && followStatus != 'follow') {
          return Center(child: Text('هذا الحساب خاص. تابع المستخدم لرؤية ملفه.', style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant)));
        }

        Future<void> updateFollowStatus(bool follow) async {
          User? user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            HapticFeedback.lightImpact();
            DatabaseReference userRef = FirebaseDatabase.instance.ref().child('users/${_encodeUidForPath(uid)}');
            if (follow) {
              await userRef.update({
                user.uid: 'follow',
                'followers': followersCount + 1,
              });
              final username = await _getCurrentUsername();
              await sendNotificationToUser(uid, title: 'متابع جديد', body: 'قام @$username بمتابعتك.');
            } else {
              await userRef.child(user.uid).remove();
              await userRef.update({
                'followers': followersCount - 1,
              });
            }
          }
        }

        return FutureBuilder<int>(
          future: calculateStreakForUser(uid),
          builder: (context, streakSnapshot) {
            int streakValue = streakSnapshot.data ?? 0;
            final userPosts = _cachedPosts.where((post) => post['userEmail'] == uid).toList();
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (coverPhoto != null && coverPhoto.isNotEmpty)
                        Container(
                          width: double.infinity,
                          height: 160,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(
                              image: NetworkImage(coverPhoto),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          bool hasActiveStory = false;
                          final now = DateTime.now().millisecondsSinceEpoch;
                          final twentyFourHoursAgo = now - 24 * 60 * 60 * 1000;
                          if (userData['stories'] != null) {
                            final stories = userData['stories'];
                            if (stories is List) {
                              hasActiveStory = stories.any((s) => (s['timestamp'] ?? 0) > twentyFourHoursAgo);
                            } else if (stories is Map) {
                              hasActiveStory = stories.values.any((s) => (s['timestamp'] ?? 0) > twentyFourHoursAgo);
                            }
                          } else if (userData['story'] != null) {
                            final s = userData['story'];
                            hasActiveStory = (s['timestamp'] ?? 0) > twentyFourHoursAgo;
                          }
                          return GestureDetector(
                            onTap: hasActiveStory
                                ? () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StoryScreen(specificUserId: uid),
                                      ),
                                    );
                                  }
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hasActiveStory ? Colors.purple : (profileTheme ?? colorScheme.primary.withOpacity(0.3)),
                                  width: hasActiveStory ? 4 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (profileTheme ?? colorScheme.shadow).withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundImage: profilePic.isNotEmpty
                                    ? NetworkImage(profilePic)
                                    : AssetImage('images/ashur.png') as ImageProvider,
                                radius: 60,
                                backgroundColor: profileTheme ?? colorScheme.surface,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '@$username',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: profileTheme ?? colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(width: 6),
                          UserBadges(userData: userData, iconSize: 20),
                          SizedBox(width: 12),
                          (userUID == uid)
                            ? GestureDetector(
                                onTap: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final seen = prefs.getBool('seenStreaksStore') ?? false;
                                  if (!seen) {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StreaksStore(showIntro: true),
                                      ),
                                    );
                                    await prefs.setBool('seenStreaksStore', true);
                                  } else {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => StreaksStore(showIntro: false),
                                      ),
                                    );
                                  }
                                },
                                child: Chip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt, color: Colors.amber, size: 20),
                                      SizedBox(width: 4),
                                      Text(
                                        streakSnapshot.connectionState == ConnectionState.waiting ? '...' : '$streakValue',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.amber.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              )
                            : Chip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bolt, color: Colors.amber, size: 20),
                                    SizedBox(width: 4),
                                    Text(
                                      streakSnapshot.connectionState == ConnectionState.waiting ? '...' : '$streakValue',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.amber.withOpacity(0.1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                        ],
                      ),
                      if (name.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (bio.isNotEmpty) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            bio,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          if (userUID != uid)
                            Builder(
                              builder: (context) {
                                if (userData['isBot'] == true || (userData['id']?.toString().startsWith('bot_') ?? false)) {
                                  return SizedBox(
                                    width: 160,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final currentUser = FirebaseAuth.instance.currentUser;
                                        if (currentUser == null) return;
                                        final groupsSnap = await FirebaseDatabase.instance.ref('groups').get();
                                        if (!groupsSnap.exists || groupsSnap.value == null) return;
                                        final groupsMap = Map<String, dynamic>.from(groupsSnap.value as Map);
                                        final userGroups = groupsMap.values.where((g) {
                                          final members = g['members'];
                                          if (members is List) return members.contains(currentUser.uid);
                                          if (members is Map) return members.keys.contains(currentUser.uid);
                                          return false;
                                        }).toList();
                                        if (userGroups.isEmpty) {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('لا توجد مجموعات'),
                                              content: Text('أنت لست عضواً في أي مجموعة.'),
                                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('حسناً'))],
                                            ),
                                          );
                                          return;
                                        }
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return Dialog(
                                              child: SizedBox(
                                                width: 350,
                                                child: ListView.separated(
                                                  shrinkWrap: true,
                                                  itemCount: userGroups.length,
                                                  separatorBuilder: (c, i) => Divider(height: 1),
                                                  itemBuilder: (c, i) {
                                                    final group = userGroups[i];
                                                    final groupId = group['id'] ?? '';
                                                    final groupName = group['name'] ?? 'مجموعة';
                                                    final groupPic = group['pic'] ?? '';
                                                    return ListTile(
                                                      leading: groupPic.isNotEmpty ? CircleAvatar(backgroundImage: NetworkImage(groupPic)) : Icon(Icons.group),
                                                      title: Text(groupName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                      onTap: () async {
                                                        Navigator.pop(context);
                                                        final groupRef = FirebaseDatabase.instance.ref('groups/$groupId');
                                                        final snap = await groupRef.get();
                                                        if (!snap.exists || snap.value == null) return;
                                                        final groupData = Map<String, dynamic>.from(snap.value as Map);
                                                        final members = groupData['members'] is List
                                                          ? List<dynamic>.from(groupData['members'] as List)
                                                          : groupData['members'] is Map
                                                            ? List<String>.from((groupData['members'] as Map).keys)
                                                            : <dynamic>[];
                                                        if (members.contains(uid)) {
                                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('البوت موجود بالفعل في المجموعة')));
                                                          return;
                                                        }
                                                        members.add(uid);
                                                        await groupRef.update({'members': members});
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة البوت إلى المجموعة')));
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text('إضافة إلى مجموعة', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                } else {
                                  return SizedBox(
                                    width: 120,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        updateFollowStatus(followStatus == 'unfollow');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: followStatus == 'unfollow'
                                            ? colorScheme.primary
                                            : colorScheme.surfaceContainerHighest,
                                        foregroundColor: followStatus == 'unfollow'
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurfaceVariant,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text(
                                        followStatus == 'unfollow' ? 'متابعة' : 'إلغاء المتابعة',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          if (userUID != userData['id'])
                            SizedBox(
                              width: 120,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        targetUserEmail: uid,
                                        currentUserEmail: userUID,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.tertiaryContainer,
                                  foregroundColor: colorScheme.onTertiaryContainer,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  'مراسلة',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (userUID == userData['id'])
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        targetUserEmail: uid,
                                        currentUserEmail: userUID,
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.bookmark, color: Colors.white, size: 22),
                                label: Text('الرسائل المحفوظة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (userData['id'] == userUID) ...[
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: Text(
                            'تعديل الحساب',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (uid == FirebaseAuth.instance.currentUser?.uid) {
                            _tabController2.animateTo(5);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 20,
                                color: colorScheme.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'متابع $followersCount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      if (userData['highlights'] != null && (userData['highlights'] as List).isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.auto_stories, color: colorScheme.primary, size: 20),
                              SizedBox(width: 8),
                              Text('القصص المميزة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: (userData['highlights'] as List).length,
                            separatorBuilder: (context, i) => SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final highlight = (userData['highlights'] as List)[i];
                              final imageUrl = (highlight is Map && highlight['image'] is String && (highlight['image'] as String).isNotEmpty)
                                  ? highlight['image'] as String
                                  : '';
                              final title = (highlight is Map && highlight['title'] is String && (highlight['title'] as String).isNotEmpty)
                                  ? highlight['title'] as String
                                  : 'مميزة';
                              final highlightsList = (userData['highlights'] as List)
                                .asMap()
                                .entries
                                .map((entry) {
                                  final h = entry.value;
                                  return {
                                    ...(h is Map ? h : {}),
                                    'userId': uid,
                                    'username': userData['username'] ?? 'Unknown',
                                    'userPic': userData['pic'] ?? '',
                                  };
                                }).toList();
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StoryScreen(
                                        specificUserId: uid,
                                        showFollowedOnly: false,
                                        highlights: highlightsList,
                                        initialIndex: i,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: colorScheme.primary, width: 2),
                                        image: imageUrl.isNotEmpty
                                            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                            : null,
                                        color: colorScheme.surfaceContainerHighest,
                                      ),
                                      child: imageUrl.isEmpty
                                          ? Icon(Icons.auto_stories, color: colorScheme.primary, size: 32)
                                          : null,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      title,
                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (userUID != uid)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FutureBuilder<DatabaseEvent>(
                                future: FirebaseDatabase.instance.ref('users/$userUID').once(),
                                builder: (context, snap) {
                                  List blocked = [];
                                  if (snap.hasData && snap.data!.snapshot.value != null) {
                                    final map = snap.data!.snapshot.value is Map ? Map<String, dynamic>.from(snap.data!.snapshot.value as Map) : <String, dynamic>{};
                                    blocked = List.from(map['blockedUsers'] ?? []);
                                  }
                                  final isBlocked = blocked.contains(uid);
                                  return Row(
                                    children: [
                                      if (!isBlocked)
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            if (!blocked.contains(uid)) blocked.add(uid);
                                            await FirebaseDatabase.instance.ref('users/$userUID').update({'blockedUsers': blocked});
                                            setState(() {});
                                          },
                                          icon: Icon(Icons.block),
                                          label: Text('حظر'),
                                          style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: Colors.white),
                                        ),
                                      if (isBlocked)
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            blocked.remove(uid);
                                            await FirebaseDatabase.instance.ref('users/$userUID').update({'blockedUsers': blocked});
                                            setState(() {});
                                          },
                                          icon: Icon(Icons.lock_open),
                                          label: Text('إلغاء الحظر'),
                                          style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: Colors.white),
                                        ),
                                      SizedBox(width: 16),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          String? reportMsg = await showDialog<String>(
                                            context: context,
                                            builder: (context) {
                                              TextEditingController controller = TextEditingController();
                                              return AlertDialog(
                                                title: Text('إبلاغ عن المستخدم'),
                                                content: TextField(
                                                  controller: controller,
                                                  maxLines: 3,
                                                  decoration: InputDecoration(hintText: 'رسالة إضافية (اختياري)'),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, null),
                                                    child: Text('إلغاء'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(context, controller.text.trim()),
                                                    child: Text('إبلاغ'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (reportMsg != null) {
                                            await FirebaseDatabase.instance.ref('reports').push().set({'reported': uid, 'by': userUID, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'message': reportMsg});
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الإبلاغ عن المستخدم')));
                                          }
                                        },
                                        icon: Icon(Icons.flag),
                                        label: Text('إبلاغ'),
                                        style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.article,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'المنشورات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(width: 24),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReelsScreen(initialReelId: null, onProfileTap: null, onlyUserId: uid),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        child: Text(
                          'ريلز',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (userPosts.isEmpty)
                  Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد منشورات',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...userPosts.map((post) {
                  bool isLiked = _isLiked(post);
                  final userActions = Map<String, dynamic>.from(post['userActions'] ?? {});
                  final likes = userActions.values.where((v) => v == 'like').length;
                  String userId = post['userEmail'];
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getUserData(userId),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (userSnapshot.hasError || !userSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      bool isVerified = userSnapshot.data?['verify'] ?? false;
                      final profileThemeRaw = userSnapshot.data?['profileTheme'];
print('[DEBUG] Post user @${userSnapshot.data?['username']} profileTheme raw: ${profileThemeRaw.toString()} (type: ${profileThemeRaw.runtimeType})');
final parsedProfileTheme = profileThemeRaw != null && profileThemeRaw.toString().isNotEmpty
    ? _parseProfileThemeColor(profileThemeRaw)
    : colorScheme.onSurface;
print('[DEBUG] Parsed profileTheme color for @${userSnapshot.data?['username']}: $parsedProfileTheme');
  print('[DEBUG] userSnapshot.data: ${userSnapshot.data}');
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedEmail = userId;
                            selectedPageIndex = 4;
                            _tabController2.animateTo(4);
                          });
                        },
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundImage: userSnapshot.data?['pic']?.isNotEmpty == true
                                    ? NetworkImage(userSnapshot.data!['pic'])
                                    : AssetImage('images/ashur.png') as ImageProvider,
                                radius: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        userSnapshot.data?['username'] != null
                                            ? '@${userSnapshot.data!['username']}'
                                            : 'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: parsedProfileTheme,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      if (userSnapshot.data != null) UserBadges(userData: userSnapshot.data as Map<String, dynamic>, iconSize: 16),
                                    ],
                                  ),
                                  Text(
                                    _formatTimestamp(post['timestamp']),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (post['type'] == 'text' && post['desc']?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _renderTextWithGroupLinks(post['desc']),
                      ),
                    if (post['type'] != 'text' && post['desc']?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: MarkdownBody(
                          data: post['desc'],
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: TextStyle(
                              fontSize: 16,
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    if (post['type'] == 'image' && post['pic'] != null && post['pic'].toString().isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                post['pic'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Center(
                                      child: Icon(Icons.error_outline, size: 48, color: colorScheme.onSurfaceVariant),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                                onPressed: () {
                                  _saveFile(post['pic'], 'ashur_image_${post['id'] ?? DateTime.now().millisecondsSinceEpoch}.jpg');
                                },
                                tooltip: 'حفظ الصورة',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (post['type'] == 'video' && post['videoUrl'] != null && post['videoUrl'].toString().isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 250,
                        child: Stack(
                          children: [
                            ReelVideoPlayer(videoUrl: post['videoUrl'], isActive: false),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                                onPressed: () {
                                  _saveFile(post['videoUrl'], 'ashur_video_${post['id'] ?? DateTime.now().millisecondsSinceEpoch}.mp4');
                                },
                                tooltip: 'حفظ الفيديو',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (post['type'] == 'voice' && post['audioUrl'] != null && post['audioUrl'].toString().isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildVoicePlayer(post['audioUrl']),
                            IconButton(
                              icon: Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                              onPressed: () {
                                _saveFile(post['audioUrl'], 'ashur_voice_${post['id'] ?? DateTime.now().millisecondsSinceEpoch}.aac');
                              },
                              tooltip: 'حفظ الصوت',
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (post['type'] == 'group' && post['groupInvites'] != null && post['groupInvites'] is List) ...[
                      Column(
                        children: List<Widget>.from((post['groupInvites'] as List).map((groupId) => _buildGroupInviteWidget(groupId))),
                      ),
                    ],
                    if (post['desc']?.isNotEmpty == true)
                      SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isLiked 
                                      ? colorScheme.errorContainer
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? colorScheme.error : colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    _updateLikeStatus(post, isLiked ? 'dislike' : 'like');
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '$likes',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.comment_outlined,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CommentsScreen(postId: post['id']),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.share_outlined,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    _updateShareCount(post);
                                    Share.share('Check out this post on Ashur: ${post['desc']}\n${post['pic']}');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (FirebaseAuth.instance.currentUser != null &&
                        (post['userEmail'] == FirebaseAuth.instance.currentUser!.uid ||
                         (userSnapshot.data?['mod'] == true || (_userCache[FirebaseAuth.instance.currentUser!.uid]?['mod'] == true)))
                    ) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (FirebaseAuth.instance.currentUser != null &&
                              (post['userEmail'] == FirebaseAuth.instance.currentUser!.uid ||
                               (userSnapshot.data?['mod'] == true || (_userCache[FirebaseAuth.instance.currentUser!.uid]?['mod'] == true)))
                          )
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  final controller = TextEditingController(text: post['desc']);
                                  final result = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('تعديل المنشور'),
                                      content: TextField(
                                        controller: controller,
                                        maxLines: 4,
                                        decoration: InputDecoration(hintText: 'النص الجديد'),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('إلغاء'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, controller.text.trim()),
                                          child: Text('حفظ'),
                    ),
                  ],
                ),
              );
                                  if (result != null && result.isNotEmpty && result != post['desc']) {
                                    await FirebaseDatabase.instance.ref('posts').child(post['id']).update({'desc': result});
                                    setState(() {
                                      post['desc'] = result;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعديل المنشور')));
                                  }
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('حذف المنشور'),
                                      content: Text('هل أنت متأكد من حذف هذا المنشور؟ لا يمكن التراجع.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text('إلغاء'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
                                          child: Text('حذف'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await FirebaseDatabase.instance.ref('posts').child(post['id']).remove();
                                    setState(() {
                                      _cachedPosts.removeWhere((p) => p['id'] == post['id']);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف المنشور')));
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: colorScheme.error))),
                              ],
                            ),
                          IconButton(
                            icon: Icon(Icons.delete, color: colorScheme.error),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('حذف المنشور'),
                                  content: Text('هل أنت متأكد من حذف هذا المنشور؟ لا يمكن التراجع.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text('إلغاء'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
                                      child: Text('حذف'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await FirebaseDatabase.instance.ref('posts').child(post['id']).remove();
                                setState(() {
                                  _cachedPosts.removeWhere((p) => p['id'] == post['id']);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف المنشور')));
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChatsView() {
    final colorScheme = Theme.of(context).colorScheme;
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'يرجى تسجيل الدخول',
              style: TextStyle(
                fontSize: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    String currentUserUID = user.uid;

    return Column(
      children: [
        Container(
          color: colorScheme.surface,
          child: TabBar(
            controller: _chatTabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
            indicatorColor: colorScheme.primary,
            onTap: (index) {
              setState(() {});
            },
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 20),
                    SizedBox(width: 8),
                    Text('خاص'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.groups_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('المجموعات'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _chatTabController,
            children: [
              _buildDirectChatsView(currentUserUID),
              _buildGroupsView(currentUserUID),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectChatsView(String currentUserUID) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<DatabaseEvent>(
      key: ValueKey('direct_chats_${_chatTabController.index}'),
      stream: FirebaseDatabase.instance.ref('chats').onValue,
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
                  'خطأ في تحميل المحادثات',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.error,
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
                  'جاري تحميل المحادثات...',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
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
                  'لا توجد محادثات خاصة',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'ابدأ محادثة جديدة',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        Map<String, dynamic> chats = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        List<Map<String, dynamic>> chatList = [];
        chats.forEach((key, value) {
          if (key.contains(currentUserUID)) {
            String otherUserUID = key.replaceAll('-', '').replaceAll(currentUserUID, '');
            if (otherUserUID.isEmpty) return;
            chatList.add({
              'key': key,
              'otherUserUID': otherUserUID,
            });
          }
        });

        if (chatList.isEmpty) {
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
                  'لا توجد محادثات خاصة',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'ابدأ محادثة جديدة',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chatList.length,
          itemBuilder: (context, index) {
            final chat = chatList[index];
            final String otherUserUID = chat['otherUserUID'];

            return FutureBuilder<DatabaseEvent>(
              future: FirebaseDatabase.instance.ref('users/$otherUserUID').once(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData || userSnapshot.data!.snapshot.value == null) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person,
                            color: colorScheme.primary,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مستخدم غير معروف',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '@unknown',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                Map<String, dynamic> userData = Map<String, dynamic>.from(userSnapshot.data!.snapshot.value as Map);
                String username = userData['username'] ?? 'Unknown';
                String profilePic = userData['pic'] ?? '';
                bool isVerified = userData['verify'] ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              targetUserEmail: otherUserUID,
                              currentUserEmail: currentUserUID,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: profilePic.isNotEmpty
                                    ? Image.network(
                                        profilePic,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: colorScheme.primaryContainer,
                                            child: Icon(
                                              Icons.person,
                                              color: colorScheme.primary,
                                              size: 24,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.person,
                                          color: colorScheme.primary,
                                          size: 24,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '@$username',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      UserBadges(userData: userData, iconSize: 16),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  FutureBuilder<DatabaseEvent>(
                                    future: FirebaseDatabase.instance.ref('chats/${chat['key']}/messages').orderByChild('timestamp').limitToLast(1).once(),
                                    builder: (context, msgSnap) {
                                      String subtitle = '';
                                      if (msgSnap.hasData && msgSnap.data!.snapshot.value != null) {
                                        final data = msgSnap.data!.snapshot.value;
                                        Map? lastMsg;
                                        if (data is Map) {
                                          lastMsg = data.values.last as Map?;
                                        } else if (data is List && data.isNotEmpty) {
                                          lastMsg = data.last as Map?;
                                        }
                                        if (lastMsg != null) {
                                          final senderUid = lastMsg['sender'];
                                          final text = lastMsg['text'] ?? '';
                                          final hasImage = (lastMsg['imageUrl'] != null && (lastMsg['imageUrl'] as String).isNotEmpty);
                                          final hasAudio = (lastMsg['audioUrl'] != null && (lastMsg['audioUrl'] as String).isNotEmpty);
                                          String previewText = text;
                                          if (hasImage) {
                                            previewText = 'أرسل صورة';
                                          } else if (hasAudio) previewText = 'أرسل رسالة صوتية';
                                          return FutureBuilder<DatabaseEvent>(
                                            future: FirebaseDatabase.instance.ref('users/$senderUid').once(),
                                            builder: (context, senderSnap) {
                                              String senderUsername = 'unknown';
                                              if (senderSnap.hasData && senderSnap.data!.snapshot.value != null) {
                                                final senderData = Map<String, dynamic>.from(senderSnap.data!.snapshot.value as Map);
                                                senderUsername = senderData['username'] ?? 'unknown';
                                              }
                                              return Text(
                                                '@$senderUsername: $previewText',
                                                style: TextStyle(
                                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          );
                                        }
                                      }
                                      return Text(
                                        '',
                                        style: TextStyle(
                                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsView(String currentUserUID) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<DatabaseEvent>(
      key: ValueKey('groups_${_chatTabController.index}'),
      stream: FirebaseDatabase.instance.ref('groups').onValue,
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
                  'حدث خطأ في تحميل المجموعات',
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
                  'جاري تحميل المجموعات...',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final Map<dynamic, dynamic>? groupsMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;

          if (groupsMap == null) {
            return Center(
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
                    'لا توجد مجموعات',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'انضم إلى مجموعات للبدء في المحادثة',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final List<dynamic> groupsList = groupsMap.values.toList();
          final filteredGroups = groupsList.where((group) {
            final members = group['members'] as List<dynamic>?;
            return members != null && members.contains(currentUserUID);
          }).toList();

          if (filteredGroups.isEmpty) {
            return Center(
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
                    'لا توجد مجموعات',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'انضم إلى مجموعات للبدء في المحادثة',
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
            itemCount: filteredGroups.length,
            itemBuilder: (context, index) {
              final group = filteredGroups[index] as Map<dynamic, dynamic>?;

              if (group == null) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.group,
                          color: colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مجموعة غير معروفة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '0 عضو',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final String groupName = group['name'] ?? 'مجموعة غير معروفة';
              final String groupPic = group['pic'] ?? '';
              final List<dynamic> members = group['members'] ?? [];
              final int memberCount = members.length;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final String groupId = group['id'] ?? '';
                      if (groupId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChatScreen(
                              groupId: groupId,
                              currentUserUid: currentUserUID,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('خطأ في معرف المجموعة'),
                            backgroundColor: colorScheme.error,
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
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
                                            size: 24,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.groups,
                                        color: colorScheme.primary,
                                        size: 24,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  groupName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                FutureBuilder<DatabaseEvent>(
                                  future: FirebaseDatabase.instance.ref('groups/${group['id']}/messages').orderByChild('timestamp').limitToLast(1).once(),
                                  builder: (context, msgSnap) {
                                    String subtitle = '';
                                    if (msgSnap.hasData && msgSnap.data!.snapshot.value != null) {
                                      final data = msgSnap.data!.snapshot.value;
                                      Map? lastMsg;
                                      if (data is Map) {
                                        lastMsg = data.values.last as Map?;
                                      } else if (data is List && data.isNotEmpty) {
                                        lastMsg = data.last as Map?;
                                      }
                                      if (lastMsg != null) {
                                        final senderUid = lastMsg['sender'];
                                        final text = lastMsg['text'] ?? '';
                                        final hasImage = (lastMsg['imageUrl'] != null && (lastMsg['imageUrl'] as String).isNotEmpty);
                                        final hasAudio = (lastMsg['audioUrl'] != null && (lastMsg['audioUrl'] as String).isNotEmpty);
                                        String previewText = text;
                                        if (hasImage) {
                                          previewText = 'أرسل صورة';
                                        } else if (hasAudio) previewText = 'أرسل رسالة صوتية';
                                        return FutureBuilder<DatabaseEvent>(
                                          future: FirebaseDatabase.instance.ref('users/$senderUid').once(),
                                          builder: (context, senderSnap) {
                                            String senderUsername = 'unknown';
                                            if (senderSnap.hasData && senderSnap.data!.snapshot.value != null) {
                                              final senderData = Map<String, dynamic>.from(senderSnap.data!.snapshot.value as Map);
                                              senderUsername = senderData['username'] ?? 'unknown';
                                            }
                                            return Text(
                                              '@$senderUsername: $previewText',
                                              style: TextStyle(
                                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        );
                                      }
                                    }
                                    return Text(
                                      '',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        return Center(
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
                'لا توجد مجموعات',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'انضم إلى مجموعات للبدء في المحادثة',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostsListView() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoadingPosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: colorScheme.primary,
            ),
            SizedBox(height: 16),
            Text(
              'جاري تحميل المنشورات...',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_cachedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد منشورات',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'انشئ منشور جديد لتظهر هنا',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: Theme.of(context).colorScheme.primary,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _filterPostsByPrivacy(_cachedPosts),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final filteredPosts = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredPosts.length,
            itemBuilder: (context, index) {
              var post = filteredPosts[index];
              bool isLiked = _isLiked(post);
              final userActions = Map<String, dynamic>.from(post['userActions'] ?? {});
              final likes = userActions.values.where((v) => v == 'like').length;
              String userId = post['userEmail'];
              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUserData(userId),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (userSnapshot.hasError || !userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  bool isVerified = userSnapshot.data?['verify'] ?? false;
                  final profileThemeRaw = userSnapshot.data?['profileTheme'];
                  final parsedProfileTheme = profileThemeRaw != null && profileThemeRaw.toString().isNotEmpty
                      ? _parseProfileThemeColor(profileThemeRaw)
                      : colorScheme.onSurface;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedEmail = userId;
                                selectedPageIndex = 4;
                                _tabController2.animateTo(4);
                              });
                            },
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    backgroundImage: userSnapshot.data?['pic']?.isNotEmpty == true
                                        ? NetworkImage(userSnapshot.data!['pic'])
                                        : AssetImage('images/ashur.png') as ImageProvider,
                                    radius: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            userSnapshot.data?['username'] != null
                                                ? '@${userSnapshot.data!['username']}'
                                                : 'Unknown',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: parsedProfileTheme,
                                            ),
                                          ),
                                          SizedBox(width: 6),
                                          if (userSnapshot.data != null) UserBadges(userData: userSnapshot.data as Map<String, dynamic>, iconSize: 16),
                                        ],
                                      ),
                                      Text(
                                        _formatTimestamp(post['timestamp']),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (post['type'] == 'text' && post['desc']?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _renderTextWithGroupLinks(post['desc']),
                          ),
                        if (post['type'] != 'text' && post['desc']?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: MarkdownBody(
                              data: post['desc'],
                              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                p: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurface,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        if (post['type'] == 'image' && post['pic'] != null && post['pic'].toString().isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    post['pic'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        color: colorScheme.surfaceContainerHighest,
                                        child: Center(
                                          child: Icon(Icons.error_outline, size: 48, color: colorScheme.onSurfaceVariant),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                                    onPressed: () {
                                      _saveFile(post['pic'], 'ashur_image_${post['id'] ?? DateTime.now().millisecondsSinceEpoch}.jpg');
                                    },
                                    tooltip: 'حفظ الصورة',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (post['type'] == 'video' && post['videoUrl'] != null && post['videoUrl'].toString().isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            height: 250,
                            child: Stack(
                              children: [
                                ReelVideoPlayer(videoUrl: post['videoUrl'], isActive: false),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                                    onPressed: () {
                                      _saveFile(post['videoUrl'], 'ashur_video_${post['id'] ?? DateTime.now().millisecondsSinceEpoch}.mp4');
                                    },
                                    tooltip: 'حفظ الفيديو',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (post['type'] == 'voice' && post['audioUrl'] != null && post['audioUrl'].toString().isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildVoicePlayer(post['audioUrl']),
                                IconButton(
                                  icon: Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                                  onPressed: () {
                                    _saveFile(post['audioUrl'], 'ashur_voice_${post['id'] ?? DateTime.now().millisecondsSinceEpoch}.aac');
                                  },
                                  tooltip: 'حفظ الصوت',
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (post['type'] == 'group' && post['groupInvites'] != null && post['groupInvites'] is List) ...[
                          Column(
                            children: List<Widget>.from((post['groupInvites'] as List).map((groupId) => _buildGroupInviteWidget(groupId))),
                          ),
                        ],
                        if (post['desc']?.isNotEmpty == true)
                          SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isLiked 
                                          ? colorScheme.errorContainer
                                          : colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        color: isLiked ? colorScheme.error : colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        _updateLikeStatus(post, isLiked ? 'dislike' : 'like');
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '$likes',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.comment_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CommentsScreen(postId: post['id']),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.share_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        _updateShareCount(post);
                                        Share.share('Check out this post on Ashur: ${post['desc']}${post['pic'] != null ? '\n${post['pic']}' : ''}');
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  if (FirebaseAuth.instance.currentUser != null &&
                                      (post['userEmail'] == FirebaseAuth.instance.currentUser!.uid ||
                                       (userSnapshot.data?['mod'] == true || (_userCache[FirebaseAuth.instance.currentUser!.uid]?['mod'] == true)))
                                  )
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          final controller = TextEditingController(text: post['desc']);
                                          final result = await showDialog<String>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('تعديل المنشور'),
                                              content: TextField(
                                                controller: controller,
                                                maxLines: 4,
                                                decoration: InputDecoration(hintText: 'النص الجديد'),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: Text('إلغاء'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                                                  child: Text('حفظ'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (result != null && result.isNotEmpty && result != post['desc']) {
                                            await FirebaseDatabase.instance.ref('posts').child(post['id']).update({'desc': result});
                                            setState(() {
                                              post['desc'] = result;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعديل المنشور')));
                                          }
                                        } else if (value == 'delete') {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text('حذف المنشور'),
                                              content: Text('هل أنت متأكد من حذف هذا المنشور؟ لا يمكن التراجع.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: Text('إلغاء'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
                                                  child: Text('حذف'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await FirebaseDatabase.instance.ref('posts').child(post['id']).remove();
                                            setState(() {
                                              _cachedPosts.removeWhere((p) => p['id'] == post['id']);
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف المنشور')));
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                        PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: colorScheme.error))),
                                      ],
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
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _filterPostsByPrivacy(List<Map<String, dynamic>> posts) async {
    List<Map<String, dynamic>> filtered = [];
    for (final post in posts) {
      final userId = post['userEmail'];
      final userData = await _getUserData(userId);
      if (await canViewUserContent(userId, userData)) {
        filtered.add(post);
      }
    }
    return filtered;
  }

  Widget _buildGlobalSearchTabs() {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'الحسابات'),
              Tab(icon: Icon(Icons.article), text: 'المنشورات'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSearchResults(searchQuery),
                _buildPostSearchResults(searchQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostSearchResults(String query) {
    if (query.isEmpty) {
      return Center(child: Text('ابحث عن منشورات...'));
    }
    List<Map<String, dynamic>> filtered = _cachedPosts.where((post) {
      final desc = (post['desc'] ?? '').toString().toLowerCase();
      return desc.contains(query.toLowerCase());
    }).toList();
    if (filtered.isEmpty) {
      return Center(child: Text('لا توجد منشورات مطابقة'));
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final post = filtered[i];
        return FutureBuilder<Map<String, dynamic>?>(
          future: _getUserData(post['userEmail']),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return SizedBox();
            return _buildPostCard(post, userSnapshot.data!);
          },
        );
      },
    );
  }

  Widget _buildGroupSearchResults(String query) {
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance.ref('groups').once(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(child: Text('لا توجد مجموعات'));
        }
        final groupsMap = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final List<Map<String, dynamic>> groups = groupsMap.values.map((g) => Map<String, dynamic>.from(g as Map)).toList();
        final filtered = groups.where((g) {
          final name = (g['name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
        if (filtered.isEmpty) {
          return Center(child: Text('لا توجد مجموعات مطابقة'));
        }
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final group = filtered[i];
            return ListTile(
              leading: Icon(Icons.group),
              title: Text(group['name'] ?? ''),
              subtitle: Text('ID: ${group['id'] ?? ''}'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => GroupChatScreen(
                    groupId: group['id'],
                    currentUserUid: userUID,
                  ),
                ));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(String query) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'ابحث عن المستخدمين',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'اكتب اسم المستخدم في شريط البحث',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                SizedBox(height: 16),
                Text(
                  'خطأ في البحث',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.error,
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
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(height: 16),
                Text(
                  'جاري البحث...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'لا توجد نتائج',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        Map<String, dynamic> users = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        List<Map<String, dynamic>> filteredUsers = [];
        final currentUser = FirebaseAuth.instance.currentUser;
        users.forEach((key, value) {
          var userData = Map<String, dynamic>.from(value as Map);
          String username = userData['username']?.toString().toLowerCase() ?? '';
          String name = userData['name']?.toString().toLowerCase() ?? '';
          if (username.contains(query.toLowerCase()) || name.contains(query.toLowerCase())) {
            if (currentUser != null && (userData['private'] == true)) {
              final followers = userData['followers'];
              final isSelf = key == currentUser.uid;
              final isFollower = (followers is List && followers.contains(currentUser.uid)) || (followers is Map && followers.containsKey(currentUser.uid));
              if (!isSelf && !isFollower) return;
            }
            userData['id'] = key;
            filteredUsers.add(userData);
          }
        });

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(height: 16),
                Text(
                  'لا توجد نتائج لـ "$query"',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final colorScheme = Theme.of(context).colorScheme;
            var user = filteredUsers[index];
            String username = user['username'] ?? 'Unknown';
            String name = user['name'] ?? '';
            String profilePic = user['pic'] ?? '';
            bool isVerified = user['verify'] ?? false;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: profilePic.isNotEmpty
                        ? NetworkImage(profilePic)
                        : AssetImage('images/ashur.png') as ImageProvider,
                    radius: 25,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: user['profileTheme'] != null && user['profileTheme'].toString().isNotEmpty
                            ? _parseProfileThemeColor(user['profileTheme'])
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(width: 6),
                    UserBadges(userData: user, iconSize: 16),
                  ],
                ),
                subtitle: name.isNotEmpty ? Text(
                  name,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ) : null,
                trailing: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      selectedEmail = user['id'];
                    });
                    _tabController.animateTo(4);
                    _tabController2.animateTo(4);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'عرض الملف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReelsListView() {
    return ReelsScreen(
      onProfileTap: (String userId) {
        setState(() {
          selectedEmail = userId;
          selectedPageIndex = 4;
          _tabController2.animateTo(4);
        });
      },
      filterByPrivacy: true,
    );
  }

  Widget _buildVoicePlayer(String audioUrl) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.play_arrow, color: colorScheme.primary),
          onPressed: () async {
            final player = AudioPlayer();
            await player.play(UrlSource(audioUrl));
          },
        ),
        Text('تشغيل الصوت', style: TextStyle(color: colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildGroupInviteWidget(String groupId) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<DatabaseEvent>(
      future: FirebaseDatabase.instance.ref('groups/$groupId').once(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Row(children: [CircularProgressIndicator()]),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Row(children: [Icon(Icons.error_outline, color: colorScheme.error), SizedBox(width: 12), Text('مجموعة غير موجودة', style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600))]),
          );
        }
        final groupData = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final groupName = groupData['name'] ?? 'مجموعة غير معروفة';
        final groupPic = groupData['pic'] ?? '';
        final members = groupData['members'] ?? [];
        final memberCount = members.length;
        return GestureDetector(
          onTap: () async {
            final groupRef = FirebaseDatabase.instance.ref('groups/$groupId');
            final snap = await groupRef.get();
            if (snap.exists) {
              final groupData = snap.value as Map<dynamic, dynamic>;
              final members = List<dynamic>.from(groupData['members'] as List<dynamic>? ?? []);
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && !members.contains(user.uid)) {
                members.add(user.uid);
                await groupRef.update({'members': members});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الانضمام إلى المجموعة بنجاح'), backgroundColor: colorScheme.primary));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أنت بالفعل عضو في هذه المجموعة'), backgroundColor: colorScheme.primary));
              }
            }
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: groupPic.isNotEmpty ? ClipOval(child: Image.network(groupPic, width: 40, height: 40, fit: BoxFit.cover)) : Icon(Icons.group, size: 20, color: colorScheme.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(groupName, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 2),
                      Text('$memberCount عضو', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                  child: Text('انضم', style: TextStyle(color: colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _renderTextWithGroupLinks(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final groupRegex = RegExp(r'group://[^\s]+');
    final matches = groupRegex.allMatches(text);
    if (matches.isEmpty) {
      return MarkdownBody(
        data: text,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: TextStyle(fontSize: 16, color: colorScheme.onSurface, height: 1.4),
        ),
      );
    }
    List<InlineSpan> spans = [];
    int last = 0;
    for (final match in matches) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start), style: TextStyle(fontSize: 16, color: colorScheme.onSurface, height: 1.4)));
      }
      final groupId = match.group(0)!.replaceAll('group://', '');
      spans.add(WidgetSpan(child: _buildGroupInviteWidget(groupId)));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: TextStyle(fontSize: 16, color: colorScheme.onSurface, height: 1.4)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Color _parseProfileThemeColor(dynamic value) {
    try {
      if (value == null) return Theme.of(context).colorScheme.onSurface;
      if (value is int) return Color(value);
      if (value is String && value.isNotEmpty) return Color(int.parse(value));
    } catch (_) {}
    return Theme.of(context).colorScheme.onSurface;
  }

  Widget _buildMainFeedTabs() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        TabBar(
          controller: _mainFeedTabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
          indicatorColor: colorScheme.primary,
          tabs: [
            Tab(text: 'الأحدث'),
            Tab(text: 'الأكثر شعبية'),
            Tab(text: 'المستخدمون الأكثر متابعة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _mainFeedTabController,
            children: [
              _buildPostsListView(),
              _buildTrendingPostsListView(),
              _buildPopularUsersListView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingPostsListView() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoadingPosts) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            SizedBox(height: 16),
            Text('جاري تحميل المنشورات...', style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withOpacity(0.7))),
          ],
        ),
      );
    }
    if (_cachedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.5)),
            SizedBox(height: 16),
            Text('لا توجد منشورات', style: TextStyle(fontSize: 18, color: colorScheme.onSurface.withOpacity(0.7))),
            SizedBox(height: 8),
            Text('انشئ منشور جديد لتظهر هنا', style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      );
    }
    List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(_cachedPosts);
    sorted.sort((a, b) {
      int aLikes = ((a['likes'] ?? 0) as num).toInt();
      int aComments = 0;
      if (a['comments'] != null) {
        if (a['comments'] is List) {
          aComments = (a['comments'] as List).length;
        } else if (a['comments'] is Map) aComments = (a['comments'] as Map).length;
      }
      int aShares = ((a['shares'] ?? 0) as num).toInt();
      int bLikes = ((b['likes'] ?? 0) as num).toInt();
      int bComments = 0;
      if (b['comments'] != null) {
        if (b['comments'] is List) {
          bComments = (b['comments'] as List).length;
        } else if (b['comments'] is Map) bComments = (b['comments'] as Map).length;
      }
      int bShares = ((b['shares'] ?? 0) as num).toInt();
      int aScore = aLikes + aComments + aShares;
      int bScore = bLikes + bComments + bShares;
      return bScore.compareTo(aScore);
    });
    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          var post = sorted[index];
          bool isLiked = _isLiked(post);
          final userActions = Map<String, dynamic>.from(post['userActions'] ?? {});
          final likes = userActions.values.where((v) => v == 'like').length;
          String userId = post['userEmail'];
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getUserData(userId),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                  ),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (userSnapshot.hasError || !userSnapshot.hasData) {
                return const SizedBox.shrink();
              }
              bool isVerified = userSnapshot.data?['verify'] ?? false;
              final profileThemeRaw = userSnapshot.data?['profileTheme'];
              final parsedProfileTheme = profileThemeRaw != null && profileThemeRaw.toString().isNotEmpty
                  ? _parseProfileThemeColor(profileThemeRaw)
                  : colorScheme.onSurface;
              return _buildPostCard(post, userSnapshot.data!);
            },
          );
        },
      ),
    );
  }

  Widget _buildPopularUsersListView() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                SizedBox(height: 16),
                Text('خطأ في تحميل المستخدمين', style: TextStyle(fontSize: 18, color: colorScheme.error)),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: colorScheme.primary),
                SizedBox(height: 16),
                Text('جاري تحميل المستخدمين...', style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withOpacity(0.7))),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: colorScheme.onSurface.withOpacity(0.5)),
                SizedBox(height: 16),
                Text('لا يوجد مستخدمون', style: TextStyle(fontSize: 18, color: colorScheme.onSurface.withOpacity(0.7))),
              ],
            ),
          );
        }
        Map<String, dynamic> users = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        List<Map<String, dynamic>> userList = [];
        users.forEach((key, value) {
          var userData = Map<String, dynamic>.from(value as Map);
          userData['id'] = key;
          userList.add(userData);
        });
        userList.sort((a, b) {
          int aFollowers = 0;
          int bFollowers = 0;
          if (a['followers'] != null) {
            if (a['followers'] is List) {
              aFollowers = (a['followers'] as List).length;
            } else if (a['followers'] is Map) aFollowers = (a['followers'] as Map).length;
            else if (a['followers'] is int) aFollowers = a['followers'];
          }
          if (b['followers'] != null) {
            if (b['followers'] is List) {
              bFollowers = (b['followers'] as List).length;
            } else if (b['followers'] is Map) bFollowers = (b['followers'] as Map).length;
            else if (b['followers'] is int) bFollowers = b['followers'];
          }
          return bFollowers.compareTo(aFollowers);
        });
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: userList.length,
          itemBuilder: (context, index) {
            var user = userList[index];
            String username = user['username'] ?? 'Unknown';
            String name = user['name'] ?? '';
            String profilePic = user['pic'] ?? '';
            bool isVerified = user['verify'] ?? false;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.primary.withOpacity(0.3), width: 2),
                  ),
                  child: CircleAvatar(
                    backgroundImage: profilePic.isNotEmpty
                        ? NetworkImage(profilePic)
                        : AssetImage('images/ashur.png') as ImageProvider,
                    radius: 25,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      '@$username',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: user['profileTheme'] != null && user['profileTheme'].toString().isNotEmpty
                            ? _parseProfileThemeColor(user['profileTheme'])
                            : colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(width: 6),
                    UserBadges(userData: user, iconSize: 16),
                  ],
                ),
                subtitle: name.isNotEmpty ? Text(
                  name,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people, size: 18, color: colorScheme.primary),
                    SizedBox(width: 4),
                    Text(
                      (() {
                        int followers = 0;
                        if (user['followers'] != null) {
                          if (user['followers'] is List) {
                            followers = (user['followers'] as List).length;
                          } else if (user['followers'] is Map) followers = (user['followers'] as Map).length;
                          else if (user['followers'] is int) followers = user['followers'];
                        }
                        return followers.toString();
                      })(),
                      style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    selectedEmail = user['id'];
                    selectedPageIndex = 4;
                    _tabController2.animateTo(4);
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, Map<String, dynamic> userData) {
    final colorScheme = Theme.of(context).colorScheme;
    bool isVerified = userData['verify'] ?? false;
    final profileThemeRaw = userData['profileTheme'];
    final parsedProfileTheme = profileThemeRaw != null && profileThemeRaw.toString().isNotEmpty
        ? _parseProfileThemeColor(profileThemeRaw)
        : colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: parsedProfileTheme.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: userData['pic']?.isNotEmpty == true
                        ? NetworkImage(userData['pic'])
                        : AssetImage('images/ashur.png') as ImageProvider,
                    radius: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            userData['username'] != null
                                ? '@${userData['username']}'
                                : 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: parsedProfileTheme,
                            ),
                          ),
                          SizedBox(width: 6),
                          UserBadges(userData: userData, iconSize: 16),
                        ],
                      ),
                      Text(
                        _formatTimestamp(post['timestamp']),
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (post['type'] == 'text' && post['desc']?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _renderTextWithGroupLinks(post['desc']),
            ),
          if (post['type'] != 'text' && post['desc']?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MarkdownBody(
                data: post['desc'],
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          if (post['type'] == 'image' && post['pic'] != null && post['pic'].toString().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post['pic'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Icon(Icons.error_outline, size: 48, color: colorScheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                      onPressed: () {
                        _saveFile(post['pic'], 'ashur_image_${post['id'] ?? DateTime.now().millisecondsSinceEpoch}.jpg');
                      },
                      tooltip: 'حفظ الصورة',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (post['type'] == 'voice' && post['audioUrl'] != null && post['audioUrl'].toString().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildVoicePlayer(post['audioUrl']),
                  IconButton(
                    icon: Icon(Icons.download_rounded, color: colorScheme.primary, size: 28),
                    onPressed: () {
                      _saveFile(post['audioUrl'], 'ashur_voice_${post['id'] ?? DateTime.now().millisecondsSinceEpoch}.aac');
                    },
                    tooltip: 'حفظ الصوت',
                  ),
                ],
              ),
            ),
          ],
          if (post['type'] == 'group' && post['groupInvites'] != null && post['groupInvites'] is List) ...[
            Column(
              children: List<Widget>.from((post['groupInvites'] as List).map((groupId) => _buildGroupInviteWidget(groupId))),
            ),
          ],
          SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.favorite_border, color: colorScheme.primary),
                onPressed: () {
                  _updateLikeStatus(post, 'like');
                },
              ),
              Text('${(post['userActions']?.values?.where((v) => v == 'like').length ?? 0)}'),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.comment_outlined, color: colorScheme.primary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CommentsScreen(postId: post['id'])),
                  );
                },
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.share_outlined, color: colorScheme.primary),
                onPressed: () {
                  _updateShareCount(post);
                  Share.share('Check out this post on Ashur: ${post['desc'] ?? ''}\n${post['pic'] ?? ''}');
                },
              ),
              Text('${((post['shares'] ?? 0) as num).toInt()}'),
              Spacer(),
              if (FirebaseAuth.instance.currentUser != null &&
                  (post['userEmail'] == FirebaseAuth.instance.currentUser!.uid ||
                   (userData['mod'] == true || (_userCache[FirebaseAuth.instance.currentUser!.uid]?['mod'] == true)))
              ) ...[
                IconButton(
                  icon: Icon(Icons.edit, color: colorScheme.primary),
                  onPressed: () async {
                    final controller = TextEditingController(text: post['desc']);
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('تعديل المنشور'),
                        content: TextField(
                          controller: controller,
                          maxLines: 4,
                          decoration: InputDecoration(hintText: 'النص الجديد'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, controller.text.trim()),
                            child: Text('حفظ'),
                          ),
                        ],
                      ),
                    );
                    if (result != null && result.isNotEmpty && result != post['desc']) {
                      await FirebaseDatabase.instance.ref('posts').child(post['id']).update({'desc': result});
                      setState(() {
                        post['desc'] = result;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تعديل المنشور')));
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: colorScheme.error),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('حذف المنشور'),
                        content: Text('هل أنت متأكد من حذف هذا المنشور؟ لا يمكن التراجع.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('إلغاء'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error),
                            child: Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseDatabase.instance.ref('posts').child(post['id']).remove();
                      if (mounted) setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف المنشور')));
                    }
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> sendNotificationToUser(String targetUid, {required String title, required String body, String? type, Map<String, dynamic>? data}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseDatabase.instance.ref('notifications/$targetUid').push();
    await ref.set({
      'title': title,
      'body': body,
      'timestamp': now,
      'read': false,
      if (type != null) 'type': type,
      if (data != null) 'data': data,
    });
  }

  Future<bool> canViewUserContent(String userId, Map<String, dynamic>? userData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
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
}

enum ColorSeed {
  baseColor('M3 Baseline', Color(0xff6750a4)),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  teal('Teal', Colors.teal),
  green('Green', Colors.green),
  yellow('Yellow', Colors.yellow),
  orange('Orange', Colors.orange),
  deepOrange('Deep Orange', Colors.deepOrange),
  pink('Pink', Colors.pink);

  const ColorSeed(this.label, this.color);
  final String label;
  final Color color;
}
