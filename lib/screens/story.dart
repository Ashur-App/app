import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../user_badges.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class StoryScreen extends StatefulWidget {
  final String? specificUserId; 
  final bool showFollowedOnly; 
  final List<dynamic>? highlights;
  final int? initialIndex; 
  const StoryScreen({
    super.key, 
    this.specificUserId,
    this.showFollowedOnly = false,
    this.highlights,
    this.initialIndex,
  });

  @override
  _StoryScreenState createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late int _currentStoryIndex;
  bool _isLoading = true;
  List<Map<String, dynamic>> _stories = [];
  List<String> _followedUsers = [];
  String? _selectedEmoji;
  bool _showEmojiPicker = false;
  final List<String> _emojiOptions = ['😍','😂','🔥','👏','😢','👍','👎'];

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
      value: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
    _currentStoryIndex = widget.initialIndex ?? 0;
    if (widget.highlights != null) {
      _stories = widget.highlights!.map((h) => Map<String, dynamic>.from(h as Map)).toList();
      _isLoading = false;
      _scaleController.forward();
    } else {
      _loadStories();
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowedUsers() async {
    if (!widget.showFollowedOnly) return;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${currentUser.uid}');
        final snapshot = await userRef.get();
        if (snapshot.exists) {
          final userData = Map<String, dynamic>.from(snapshot.value as Map);
          final profileFields = {'username', 'pic', 'bio', 'email', 'name', 'verify', 'followers', 'stories', 'story'};
          _followedUsers = userData.entries
            .where((e) => e.value == 'follow' && !profileFields.contains(e.key))
            .map((e) => e.key)
            .toList();
        }
      }
    } catch (e) {
      
    }
  }

  Future<void> _loadStories() async {
    try {
      
      if (widget.showFollowedOnly) {
        await _loadFollowedUsers();
      }
      
      
      final usersRef = FirebaseDatabase.instance.ref('users');
      final snapshot = await usersRef.get();
      
      if (snapshot.exists) {
        final Map<dynamic, dynamic> usersMap = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> storiesList = [];
        final DateTime now = DateTime.now();
        final int twentyFourHoursAgo = now.subtract(Duration(hours: 24)).millisecondsSinceEpoch;
        
        usersMap.forEach((userId, userData) {
          final userMap = Map<String, dynamic>.from(userData as Map);
          
          
          if (widget.specificUserId != null && userId != widget.specificUserId) {
            return; 
          }
          
          
          if (widget.showFollowedOnly && !_followedUsers.contains(userId)) {
            return; 
          }
          
          
          if (userMap.containsKey('stories') && userMap['stories'] != null) {
            
            final storiesData = userMap['stories'];
            if (storiesData is List) {
              
              for (int i = 0; i < storiesData.length; i++) {
                final storyData = Map<String, dynamic>.from(storiesData[i] as Map);
                final int storyTimestamp = storyData['timestamp'] ?? 0;
                final bool isNonExpirable = storyData['expires'] == false;
                if (isNonExpirable || storyTimestamp > twentyFourHoursAgo) {
                  storiesList.add({
                    ...storyData,
                    'userId': userId,
                    'username': userMap['username'] ?? 'Unknown',
                    'userPic': userMap['pic'] ?? '',
                    'storyIndex': i,
                    'totalStories': storiesData.length,
                  });
                }
              }
            } else if (storiesData is Map) {
              
              final storiesMap = storiesData;
              final userStoriesList = storiesMap.values.toList();
              for (int i = 0; i < userStoriesList.length; i++) {
                final storyData = Map<String, dynamic>.from(userStoriesList[i] as Map);
                final int storyTimestamp = storyData['timestamp'] ?? 0;
                final bool isNonExpirable = storyData['expires'] == false;
                if (isNonExpirable || storyTimestamp > twentyFourHoursAgo) {
                  storiesList.add({
                    ...storyData,
                    'userId': userId,
                    'username': userMap['username'] ?? 'Unknown',
                    'userPic': userMap['pic'] ?? '',
                    'storyIndex': i,
                    'totalStories': userStoriesList.length,
                  });
                }
              }
            }
          } else if (userMap.containsKey('story') && userMap['story'] != null) {
            
            final storyData = Map<String, dynamic>.from(userMap['story'] as Map);
            final int storyTimestamp = storyData['timestamp'] ?? 0;
            
            
            if (storyTimestamp > twentyFourHoursAgo) {
              storiesList.add({
                ...storyData,
                'userId': userId,
                'username': userMap['username'] ?? 'Unknown',
                'userPic': userMap['pic'] ?? '',
                'storyIndex': 0,
                'totalStories': 1,
              });
            } else {
              
              _removeOldStory(userId);
            }
          }
        });
        
        
        storiesList.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        
        setState(() {
          _stories = storiesList;
          _isLoading = false;
        });
        
        _scaleController.forward();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeOldStory(String userId) async {
    try {
      final userRef = FirebaseDatabase.instance.ref('users/$userId');
      final snapshot = await userRef.get();
      
      if (snapshot.exists) {
        final userData = Map<String, dynamic>.from(snapshot.value as Map);
        
        if (userData.containsKey('stories')) {
          
          final storiesData = userData['stories'];
          final DateTime now = DateTime.now();
          final int twentyFourHoursAgo = now.subtract(Duration(hours: 24)).millisecondsSinceEpoch;
          
          List<dynamic> updatedStories;
          if (storiesData is List) {
            
            updatedStories = storiesData.where((story) {
              final storyMap = Map<String, dynamic>.from(story as Map);
              final int timestamp = storyMap['timestamp'] ?? 0;
              return timestamp > twentyFourHoursAgo;
            }).toList();
          } else if (storiesData is Map) {
            
            final storiesMap = storiesData;
            updatedStories = storiesMap.values.where((story) {
              final storyMap = Map<String, dynamic>.from(story as Map);
              final int timestamp = storyMap['timestamp'] ?? 0;
              return timestamp > twentyFourHoursAgo;
            }).toList();
          } else {
            updatedStories = [];
          }
          
          await userRef.update({
            'stories': updatedStories,
          });
        } else if (userData.containsKey('story')) {
          
          await userRef.child('story').remove();
        }
      }
    } catch (e) {}
  }

  void _nextStory() {
    if (_currentStoryIndex < _stories.length - 1) {
      if (!kIsWeb) { HapticFeedback.lightImpact(); }
      _scaleController.reverse().then((_) {
        setState(() { _currentStoryIndex++; });
        _scaleController.forward();
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      if (!kIsWeb) { HapticFeedback.lightImpact(); }
      _scaleController.reverse().then((_) {
        setState(() { _currentStoryIndex--; });
        _scaleController.forward();
      });
    }
  }

  void _nextUserStory() {
    final currentStory = _stories[_currentStoryIndex];
    final currentUserId = currentStory['userId'];
    final userStories = _stories.where((story) => story['userId'] == currentUserId).toList();
    final currentUserIndex = userStories.indexWhere((story) => story['storyId'] == currentStory['storyId']);
    if (currentUserIndex < userStories.length - 1) {
      final nextUserStory = userStories[currentUserIndex + 1];
      final nextGlobalIndex = _stories.indexWhere((story) => story['storyId'] == nextUserStory['storyId']);
      if (nextGlobalIndex != -1) {
        if (!kIsWeb) { HapticFeedback.lightImpact(); }
        _scaleController.reverse().then((_) {
          setState(() { _currentStoryIndex = nextGlobalIndex; });
          _scaleController.forward();
        });
      }
    } else {
      _nextStory();
    }
  }

  void _previousUserStory() {
    final currentStory = _stories[_currentStoryIndex];
    final currentUserId = currentStory['userId'];
    final userStories = _stories.where((story) => story['userId'] == currentUserId).toList();
    final currentUserIndex = userStories.indexWhere((story) => story['storyId'] == currentStory['storyId']);
    if (currentUserIndex > 0) {
      final prevUserStory = userStories[currentUserIndex - 1];
      final prevGlobalIndex = _stories.indexWhere((story) => story['storyId'] == prevUserStory['storyId']);
      if (prevGlobalIndex != -1) {
        if (!kIsWeb) { HapticFeedback.lightImpact(); }
        _scaleController.reverse().then((_) {
          setState(() { _currentStoryIndex = prevGlobalIndex; });
          _scaleController.forward();
        });
      }
    } else {
      _previousStory();
    }
  }

  Widget _buildStoryContent(ColorScheme colorScheme) {
    final story = _stories[_currentStoryIndex];
    final user = FirebaseAuth.instance.currentUser;
    final isOwnStory = user != null && (story['userId'] ?? '') == (user.uid ?? '');
    final storyUserId = story['userId']?.toString() ?? '';
    final storyId = story['storyId']?.toString() ?? '';
    final storyImage = story['image'] is String && (story['image']?.isNotEmpty ?? false) ? story['image'] : '';
    final storyUserPic = story['userPic'] is String && (story['userPic']?.isNotEmpty ?? false) ? story['userPic'] : '';
    final storyUsername = story['username']?.toString() ?? 'مستخدم';
    final storyTimestamp = story['timestamp'];
    if (user != null) {
      FirebaseDatabase.instance.ref('users/$storyUserId/stories').get().then((snapshot) {
        if (snapshot.exists) {
          List stories = [];
          if (snapshot.value is List) {
            stories = List.from(snapshot.value as List);
          } else if (snapshot.value is Map) stories = (snapshot.value as Map).values.toList();
          for (int i = 0; i < stories.length; i++) {
            if (stories[i]['storyId'] == storyId) {
              final viewers = (stories[i]['viewers'] ?? {}) as Map;
              if (!viewers.containsKey(user.uid)) {
                viewers[user.uid] = DateTime.now().millisecondsSinceEpoch;
                stories[i]['viewers'] = viewers;
                FirebaseDatabase.instance.ref('users/$storyUserId/stories').set(stories);
              }
            }
          }
        }
      });
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 2) {
          _previousUserStory();
        } else {
          _nextUserStory();
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          _previousUserStory();
        } else if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _nextUserStory();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: storyImage.isNotEmpty
                    ? Image.network(
                        storyImage,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 64,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); },
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              storyUserPic.isNotEmpty
                                ? CircleAvatar(backgroundImage: NetworkImage(storyUserPic), radius: 18)
                                : CircleAvatar(radius: 18, child: Icon(Icons.person)),
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('@$storyUsername', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                      SizedBox(width: 4),
                                      UserBadges(userData: story, iconSize: 14),
                                    ],
                                  ),
                                  Text(_formatTimeAgo(storyTimestamp), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isOwnStory)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final storiesSnap = await FirebaseDatabase.instance.ref('users/$storyUserId/stories').get();
                                  if (storiesSnap.exists) {
                                    List stories = [];
                                    if (storiesSnap.value is List) {
                                      stories = List.from(storiesSnap.value as List);
                                    } else if (storiesSnap.value is Map) stories = (storiesSnap.value as Map).values.toList();
                                    final highlight = stories.firstWhere((s) => s['storyId'] == storyId, orElse: () => null);
                                    if (highlight != null) {
                                      final highlightsSnap = await FirebaseDatabase.instance.ref('users/$storyUserId/highlights').get();
                                      List highlights = [];
                                      if (highlightsSnap.exists && highlightsSnap.value is List) {
                                        highlights = List.from(highlightsSnap.value as List);
                                      } else if (highlightsSnap.exists && highlightsSnap.value is Map) highlights = (highlightsSnap.value as Map).values.toList();
                                      final already = highlights.any((h) => h['storyId'] == storyId);
                                      if (already) {
                                        showDialog(context: context, builder: (context) => AlertDialog(title: Text('المميزة'), content: Text('هذه القصة موجودة بالفعل في المميزة.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('حسناً'))]));
                                        return;
                                      }
                                      highlights.add(Map<String, dynamic>.from(highlight));
                                      await FirebaseDatabase.instance.ref('users/$storyUserId/highlights').set(highlights);
                                      showDialog(context: context, builder: (context) => AlertDialog(title: Text('المميزة'), content: Text('تمت إضافة القصة إلى المميزة بنجاح.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('حسناً'))]));
                                      setState(() {});
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: Text('إضافة إلى المميزة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              SizedBox(width: 6),
                              ElevatedButton(
                                onPressed: () async {
                                  final storiesSnap = await FirebaseDatabase.instance.ref('users/$storyUserId/stories').get();
                                  if (storiesSnap.exists) {
                                    List stories = [];
                                    if (storiesSnap.value is List) {
                                      stories = List.from(storiesSnap.value as List);
                                    } else if (storiesSnap.value is Map) stories = (storiesSnap.value as Map).values.toList();
                                    final s = stories.firstWhere((s) => s['storyId'] == storyId, orElse: () => null);
                                    if (s != null && s['viewers'] != null) {
                                      final viewers = s['viewers'] as Map;
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                        builder: (context) {
                                          return Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('المشاهدون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                                SizedBox(height: 12),
                                                ...viewers.keys.map<Widget>((uid) {
                                                  return FutureBuilder<DatabaseEvent>(
                                                    future: FirebaseDatabase.instance.ref('users/$uid').once(),
                                                    builder: (context, snap) {
                                                      if (!snap.hasData || snap.data!.snapshot.value == null) return SizedBox();
                                                      final u = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
                                                      return ListTile(
                                                        leading: u['pic'] != null && u['pic'].toString().isNotEmpty ? CircleAvatar(backgroundImage: NetworkImage(u['pic'])) : CircleAvatar(child: Icon(Icons.person)),
                                                        title: Text('@${u['username'] ?? 'Unknown'}'),
                                                      );
                                                    },
                                                  );
                                                }),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: Text('المشاهدون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: Container()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (story['story_desc']?.isNotEmpty == true)
                          Container(
                            padding: EdgeInsets.all(14),
                            margin: EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(story['story_desc'], style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5), textAlign: TextAlign.center),
                          ),
                        if (story['type'] == 'qa')
                          _buildQAWidget(story),
                        if (story['type'] == 'countdown')
                          _buildCountdownWidget(story),
                        if (story['poll'] != null)
                          _buildLivePollWidget(story),
                        SizedBox(height: 10),
                        _buildStoryProgressBar(),
                        SizedBox(height: 10),
                        _buildEmojiReactionsBar(story, user),
                        if (_showEmojiPicker)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            child: Center(
                              child: EmojiPicker(
                                onEmojiSelected: (cat, emoji) async {
                                  setState(() { _selectedEmoji = emoji.emoji; _showEmojiPicker = false; });
                                  if (user != null) {
                                    final storiesSnap = await FirebaseDatabase.instance.ref('users/$storyUserId/stories').get();
                                    if (storiesSnap.exists) {
                                      List stories = [];
                                      if (storiesSnap.value is List) {
                                        stories = List.from(storiesSnap.value as List);
                                      } else if (storiesSnap.value is Map) stories = (storiesSnap.value as Map).values.toList();
                                      for (int i = 0; i < stories.length; i++) {
                                        if (stories[i]['storyId'] == storyId) {
                                          final reactions = stories[i]['reactions'] ?? {};
                                          if (reactions[_selectedEmoji] == null) reactions[_selectedEmoji] = {};
                                          reactions[_selectedEmoji][user.uid] = true;
                                          stories[i]['reactions'] = reactions;
                                        }
                                      }
                                      await FirebaseDatabase.instance.ref('users/$storyUserId/stories').set(stories);
                                      setState(() {});
                                    }
                                  }
                                },
                                config: Config(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime postTime;
    if (timestamp is int) {
      postTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else if (timestamp is String) postTime = DateTime.parse(timestamp);
    else return '';
    final now = DateTime.now();
    final diff = now.difference(postTime);
    if (diff.inDays > 0) return '${diff.inDays} يوم';
    if (diff.inHours > 0) return '${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return '${diff.inMinutes} دقيقة';
    return 'الآن';
  }
  Widget _buildEmojiReactionsBar(Map<String, dynamic> story, User? user) {
    final storyUserId = story['userId'];
    final storyId = story['storyId'];
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$storyUserId/stories').onValue,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.snapshot.value == null) return SizedBox();
        List stories = [];
        if (snap.data!.snapshot.value is List) {
          stories = List.from(snap.data!.snapshot.value as List);
        } else if (snap.data!.snapshot.value is Map) stories = (snap.data!.snapshot.value as Map).values.toList();
        Map? s;
        for (final st in stories) {
          if (st is Map && st['storyId'] == storyId) s = st;
        }
        if (s == null) return SizedBox();
        final reactions = s['reactions'] ?? {};
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
                    children: [
              ..._emojiOptions.map((emoji) {
                final count = reactions[emoji]?.length ?? 0;
                final isSelected = user != null && reactions[emoji]?.containsKey(user.uid) == true;
                return GestureDetector(
                  onTap: user == null ? null : () async {
                    final storiesSnap = await FirebaseDatabase.instance.ref('users/$storyUserId/stories').get();
                    if (storiesSnap.exists) {
                      List stories = [];
                      if (storiesSnap.value is List) {
                        stories = List.from(storiesSnap.value as List);
                      } else if (storiesSnap.value is Map) stories = (storiesSnap.value as Map).values.toList();
                      for (int i = 0; i < stories.length; i++) {
                        if (stories[i]['storyId'] == storyId) {
                          final reactions = stories[i]['reactions'] ?? {};
                          if (reactions[emoji] == null) reactions[emoji] = {};
                          if (reactions[emoji][user.uid] == true) {
                            reactions[emoji].remove(user.uid);
                          } else {
                            reactions[emoji][user.uid] = true;
                          }
                                                  stories[i]['reactions'] = reactions;
                        }
                      }
                      await FirebaseDatabase.instance.ref('users/$storyUserId/stories').set(stories);
                      setState(() {});
                    }
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 150),
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amber : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                        ),
                    child: Row(
                      children: [
                        Text(emoji, style: TextStyle(fontSize: 22)),
                        if (count > 0) ...[
                          SizedBox(width: 4),
                          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
              ],
            ),
          ),
                );
              }),
              GestureDetector(
                onTap: () { setState(() { _showEmojiPicker = !_showEmojiPicker; }); },
            child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 6),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
              ),
                  child: Icon(Icons.add_reaction, color: Colors.black, size: 22),
            ),
          ),
      ],
          ),
        );
      },
    );
  }

  Widget _buildPollWidget(Map<String, dynamic> story) {
    final poll = story['poll'] is Map<String, dynamic>
        ? story['poll'] as Map<String, dynamic>
        : Map<String, dynamic>.from(story['poll'] as Map);
    final options = List<String>.from(poll['options'] ?? []);
    final votes = List<int>.from(poll['votes'] ?? List.filled(options.length, 0));
    final question = poll['question'] ?? '';
    final user = FirebaseAuth.instance.currentUser;
    int? userVoteIndex;
    if (poll['voters'] != null && user != null) {
      final voters = poll['voters'] as List?;
      if (voters != null) {
        for (int i = 0; i < voters.length; i++) {
          if (voters[i] is Map && voters[i]['uid'] == user.uid) {
            userVoteIndex = voters[i]['option'];
            break;
          }
        }
      }
    }
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 32),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ElevatedButton(
                onPressed: user == null ? null : () => _votePoll(story, i, userVoteIndex),
                style: ElevatedButton.styleFrom(
                  backgroundColor: userVoteIndex == i ? Colors.blue : Colors.grey[300],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(options[i], style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${votes[i]}', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _votePoll(Map<String, dynamic> story, int optionIndex, int? previousVoteIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final poll = story['poll'] is Map<String, dynamic>
        ? story['poll'] as Map<String, dynamic>
        : Map<String, dynamic>.from(story['poll'] as Map);
    List<int> votes = List<int>.from(poll['votes'] ?? List.filled((poll['options'] as List).length, 0));
    votes = List<int>.from(votes);
    List voters = poll['voters'] ?? [];
    voters = List.from(voters);
    bool found = false;
    for (int i = 0; i < voters.length; i++) {
      if (voters[i] is Map && voters[i]['uid'] == user.uid) {
        found = true;
        if (voters[i]['option'] != optionIndex) {
          if (voters[i]['option'] is int && voters[i]['option'] < votes.length) {
            votes[voters[i]['option']] = (votes[voters[i]['option']]) - 1;
          }
          voters[i]['option'] = optionIndex;
          votes[optionIndex] = (votes[optionIndex]) + 1;
        }
        break;
      }
    }
    if (!found) {
      voters.add({'uid': user.uid, 'option': optionIndex});
      votes[optionIndex] = (votes[optionIndex]) + 1;
    }
    poll['votes'] = votes;
    poll['voters'] = voters;
    setState(() {});
    final userRef = FirebaseDatabase.instance.ref('users/${story['userId']}/stories');
    final snapshot = await userRef.get();
    if (snapshot.exists) {
      List stories = [];
      if (snapshot.value is List) {
        stories = List.from(snapshot.value as List);
      } else if (snapshot.value is Map) {
        stories = (snapshot.value as Map).values.toList();
      }
      for (int i = 0; i < stories.length; i++) {
        if (stories[i]['storyId'] == story['storyId']) {
          stories[i]['poll'] = poll;
        }
      }
      await userRef.set(stories);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }
    if (_stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories, color: colorScheme.primary, size: 64),
              SizedBox(height: 24),
              Text('لا توجد قصص متاحة', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: kIsWeb 
        ? KeyboardListener(
            focusNode: FocusNode(),
            autofocus: true,
            onKeyEvent: (event) {
              if (event is KeyDownEvent) {
                switch (event.logicalKey) {
                  case LogicalKeyboardKey.arrowLeft:
                                    _previousUserStory();
                    break;
                  case LogicalKeyboardKey.arrowRight:
                    _nextUserStory();
                    break;
                  case LogicalKeyboardKey.escape:
                    Navigator.of(context).pop();
                    break;
                }
              }
            },
            child: _buildStoryContent(colorScheme),
          )
        : _buildStoryContent(colorScheme),
    );
  }

  Widget _buildStoryProgressBar() {
    if (_stories.isEmpty) return SizedBox();
    final currentStory = _stories[_currentStoryIndex];
    final currentUserId = currentStory['userId']?.toString() ?? '';
    final currentStoryId = currentStory['storyId']?.toString() ?? '';
    final userStories = _stories.where((story) => (story['userId']?.toString() ?? '') == currentUserId).toList();
    final currentUserIndex = userStories.indexWhere((story) => (story['storyId']?.toString() ?? '') == currentStoryId);
    return Column(
      children: [
        Text(
          currentStory['username']?.toString() ?? 'Unknown User',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Row(
          children: List.generate(userStories.length, (index) {
            final story = userStories[index];
            final isCurrentStory = (story['storyId']?.toString() ?? '') == currentStoryId;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isCurrentStory
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  int _getCurrentUserStoryIndex() {
    final currentStory = _stories[_currentStoryIndex];
    final currentUserId = currentStory['userId'];
    
    
    final userStories = _stories.where((story) => story['userId'] == currentUserId).toList();
    
    
    for (int i = 0; i < userStories.length; i++) {
      if (userStories[i]['storyId'] == currentStory['storyId']) {
        return i;
      }
    }
    return 0;
  }

  int _getCurrentUserTotalStories() {
    final currentStory = _stories[_currentStoryIndex];
    final currentUserId = currentStory['userId'];
    
    
    return _stories.where((story) => story['userId'] == currentUserId).length;
  }

  bool _canGoToPreviousUserStory() {
    final currentStory = _stories[_currentStoryIndex];
    final currentUserId = currentStory['userId'];
    
    
    final userStories = _stories.where((story) => story['userId'] == currentUserId).toList();
    final currentUserIndex = userStories.indexWhere((story) => story['storyId'] == currentStory['storyId']);
    
    return currentUserIndex > 0;
  }

  bool _canGoToNextUserStory() {
    final currentStory = _stories[_currentStoryIndex];
    final currentUserId = currentStory['userId'];
    
    
    final userStories = _stories.where((story) => story['userId'] == currentUserId).toList();
    final currentUserIndex = userStories.indexWhere((story) => story['storyId'] == currentStory['storyId']);
    
    return currentUserIndex < userStories.length - 1;
  }

  Widget _buildLivePollWidget(Map<String, dynamic> story) {
    final userId = story['userId'];
    final storyId = story['storyId'];
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$userId/stories').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return _buildPollWidget(story);
        }
        List stories = [];
        if (snapshot.data!.snapshot.value is List) {
          stories = List.from(snapshot.data!.snapshot.value as List);
        } else if (snapshot.data!.snapshot.value is Map) {
          stories = (snapshot.data!.snapshot.value as Map).values.toList();
        }
        Map<String, dynamic>? liveStory;
        for (final s in stories) {
          if (s is Map && s['storyId'] == storyId) {
            liveStory = Map<String, dynamic>.from(s);
            break;
          }
        }
        if (liveStory == null) return _buildPollWidget(story);
        final merged = {...story, ...liveStory};
        return _buildPollWidget(merged);
      },
    );
  }

  Widget _buildQAWidget(Map<String, dynamic> story) {
    final user = FirebaseAuth.instance.currentUser;
    final storyUserId = story['userId'];
    final storyId = story['storyId'];
    final isOwnStory = user != null && storyUserId == user.uid;
    final answers = story['qa_answers'] ?? {};
    final controller = TextEditingController();
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(story['qa_question'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black), textAlign: TextAlign.center),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(hintText: 'إجابتك', border: OutlineInputBorder()),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    final storiesSnap = await FirebaseDatabase.instance.ref('users/$storyUserId/stories').get();
                    if (storiesSnap.exists) {
                      List stories = [];
                      if (storiesSnap.value is List) {
                        stories = List.from(storiesSnap.value as List);
                      } else if (storiesSnap.value is Map) stories = (storiesSnap.value as Map).values.toList();
                      for (int i = 0; i < stories.length; i++) {
                        if (stories[i]['storyId'] == storyId) {
                          final qa = stories[i]['qa_answers'] ?? {};
                          qa[user!.uid] = controller.text.trim();
                          stories[i]['qa_answers'] = qa;
                        }
                      }
                      await FirebaseDatabase.instance.ref('users/$storyUserId/stories').set(stories);
                      setState(() {});
                    }
                  }
                },
                child: Text('إرسال'),
              ),
            ],
          ),
          if (isOwnStory && answers is Map && answers.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12),
                Text('الإجابات:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                ...answers.entries.map((e) => FutureBuilder<DatabaseEvent>(
                  future: FirebaseDatabase.instance.ref('users/${e.key}').once(),
                  builder: (context, snap) {
                    String username = e.key;
                    if (snap.hasData && snap.data!.snapshot.value != null) {
                      final u = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
                      username = u['username'] ?? e.key;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('@$username: ${e.value}', style: TextStyle(color: Colors.black)),
                    );
                  },
                )),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCountdownWidget(Map<String, dynamic> story) {
    final target = story['countdown_target'] is int ? DateTime.fromMillisecondsSinceEpoch(story['countdown_target']) : DateTime.now();
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snap) {
        final now = snap.data ?? DateTime.now();
        final diff = target.difference(now);
        final finished = diff.isNegative;
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Text(story['countdown_title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black), textAlign: TextAlign.center),
              SizedBox(height: 12),
              finished
                ? Text('انتهى العد التنازلي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                : Text('${diff.inHours.remainder(24).toString().padLeft(2, '0')}:${diff.inMinutes.remainder(60).toString().padLeft(2, '0')}:${diff.inSeconds.remainder(60).toString().padLeft(2, '0')}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black)),
            ],
          ),
        );
      },
    );
  }
}
