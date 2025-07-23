import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'foryou.dart';
import '../user_badges.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

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

class StreaksStore extends StatefulWidget {
  final bool showIntro;
  const StreaksStore({super.key, required this.showIntro});

  @override
  State<StreaksStore> createState() => _StreaksStoreState();
}

class _StreaksStoreState extends State<StreaksStore> with SingleTickerProviderStateMixin {
  bool _showIntro = false;
  int _streaks = 0;
  int _spentStreaks = 0;
  bool _loading = true;
  String? _uid;
  List<Map<String, dynamic>> _storeItems = [];
  bool _storeLoading = true;
  Set<String> _purchasedKeys = {};
  DateTime? _now;
  late TabController _tabController;
  List<Map<String, dynamic>> _rewardHistory = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  final TextEditingController _promoController = TextEditingController();
  bool _redeemingPromo = false;
  Map<String, dynamic>? _userData;


  Future<void> _loadNow() async {
    _now = DateTime.now();
  }

  Future<void> _syncSubscriptionKeys(Map<String, dynamic> userData) async {
    if (_uid == null) return;
    final userRef = FirebaseDatabase.instance.ref('users/$_uid');
    for (final item in _storeItems) {
      if (item['type'] == 'subscription' && item['syncKey'] != null) {
        final expiry = userData[item['userKey'] ?? item['id']];
        final now = DateTime.now().millisecondsSinceEpoch;
        final isActive = expiry != null && now < expiry;
        final syncKey = item['syncKey'];
        if (userData[syncKey] != isActive) {
          await userRef.update({syncKey: isActive});
        }
      }
    }
  }

  Future<void> _loadPurchased() async {
    if (_uid == null) return;
    final userRef = FirebaseDatabase.instance.ref('users/$_uid');
    final snap = await userRef.get();
    if (snap.exists && snap.value != null) {
      final userData = Map<String, dynamic>.from(snap.value as Map);
      Set<String> keys = {};
      for (final item in _storeItems) {
        final userKey = item['userKey'] ?? item['id'];
        if (userData.containsKey(userKey)) {
          keys.add(userKey);
        }
      }
      _purchasedKeys = keys;
      await _syncSubscriptionKeys(userData);
      setState(() {});
    }
  }

  Future<void> _loadChallenges() async {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _showIntro = widget.showIntro;
    _loadNow().then((_) {
      _loadStreaks();
      _loadStoreItems();
      _loadRewardHistory();
      _loadLeaderboard();
      _loadFollowersAndFollowing();
      _loadChallenges();
    });
  }

  Future<void> _loadStreaks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    _uid = user.uid;
    final userRef = FirebaseDatabase.instance.ref('users/$_uid');
    final spentRef = FirebaseDatabase.instance.ref('users/$_uid/spentStreaks');
    int calculatedStreaks = await _calculateStreak(_uid!);
    int spent = 0;
    final snap = await userRef.get();
    if (snap.exists && snap.value != null) {
      _userData = Map<String, dynamic>.from(snap.value as Map);
    }
    final spentSnap = await spentRef.get();
    if (spentSnap.exists && spentSnap.value != null) {
      final val = spentSnap.value;
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
    setState(() {
      _streaks = calculatedStreaks - spent;
      _spentStreaks = spent;
      _loading = false;
    });
  }

  Future<int> _calculateStreak(String uid) async {
    int postsCount = 0;
    int reelsCount = 0;
    int followersCount = 0;
    int likesCount = 0;
    int commentsCount = 0;
    int sharesCount = 0;
    int chatsCount = 0;
    final postsSnapshot = await FirebaseDatabase.instance.ref('posts').get();
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
    final reelsSnapshot = await FirebaseDatabase.instance.ref('reels').get();
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
    final userSnapshot = await FirebaseDatabase.instance.ref('users/$uid').get();
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
    }
    int streak = (postsCount * 1) + (reelsCount * 2) + (followersCount * 1) + (likesCount * 0.5).round() + (commentsCount * 1) + (sharesCount * 1) + (chatsCount * 1);
    return streak;
  }

  Future<void> _loadStoreItems() async {
    setState(() { _storeLoading = true; });
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
      _storeItems = items;
      _storeLoading = false;
    });
    await _loadPurchased();
  }

  Future<void> _buyItem(Map<String, dynamic> item) async {
    if (_uid == null) return;
    if (_streaks < (item['cost'] ?? 0)) return;
    final userRef = FirebaseDatabase.instance.ref('users/$_uid');
    final spentRef = FirebaseDatabase.instance.ref('users/$_uid/spentStreaks');
    final itemType = item['type'];
    final cost = item['cost'] ?? 0;
    setState(() { _storeLoading = true; });
    final now = DateTime.now().millisecondsSinceEpoch;
    if (itemType == 'subscription') {
      final userKey = item['userKey'] ?? item['id'];
      final duration = (item['durationDays'] ?? 30) as int;
      final expiry = now + duration * 24 * 60 * 60 * 1000;
      await userRef.update({userKey: expiry});
      if (item['syncKey'] != null) {
        await userRef.update({item['syncKey']: true});
      }
      await spentRef.push().set({'item': item['id'] ?? userKey, 'cost': cost, 'ts': now});
      await userRef.update({'streaks': _streaks - cost});
      await _loadStreaks();
      await _loadPurchased();
      setState(() { _storeLoading = false; });
      return;
    } else if (itemType == 'flag' || (item['userKey'] != null)) {
      final userKey = item['userKey'] ?? item['id'];
      final userValue = item.containsKey('userValue') ? item['userValue'] : true;
      await userRef.update({userKey: userValue});
      await spentRef.push().set({'item': item['id'] ?? userKey, 'cost': cost, 'ts': now});
      await userRef.update({'streaks': _streaks - cost});
      await _loadStreaks();
      setState(() { _storeLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم شراء ${item['title']}!'), backgroundColor: Colors.green));
      await _loadPurchased();
    } else if (itemType == 'code') {
      final codesRef = FirebaseDatabase.instance.ref('streaks_store/items/${item['id']}/codes');
      final codesSnap = await codesRef.get();
      List codes = [];
      if (codesSnap.exists && codesSnap.value != null) {
        if (codesSnap.value is List) {
          codes = List.from(codesSnap.value as List)..removeWhere((e) => e == null);
        } else if (codesSnap.value is Map) {
          codes = (codesSnap.value as Map).values.toList();
        }
      }
      if (codes.isEmpty) {
        setState(() { _storeLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا توجد أكواد متاحة حالياً'), backgroundColor: Colors.red));
        return;
      }
      codes.shuffle();
      final code = codes.first;
      codes.removeAt(0);
      await codesRef.set(codes);
      await spentRef.push().set({'item': item['id'], 'cost': cost, 'ts': now});
      await userRef.update({'streaks': _streaks - cost});
      await _loadStreaks();
      setState(() { _storeLoading = false; });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('كودك الخاص'),
          content: SelectableText(code.toString()),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code.toString()));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم نسخ الكود!')));
              },
              child: Text('نسخ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        ),
      );
      await _loadPurchased();
    }
    await _loadStoreItems();
  }

  String _formatExpiry(int expiry) {
    final dt = DateTime.fromMillisecondsSinceEpoch(expiry);
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadRewardHistory() async {
    if (_uid == null) return;
    final spentRef = FirebaseDatabase.instance.ref('users/$_uid/spentStreaks');
    final snap = await spentRef.get();
    List<Map<String, dynamic>> history = [];
    if (snap.exists && snap.value != null) {
      final val = snap.value;
      if (val is Map) {
        for (final entry in val.values) {
          if (entry is Map) {
            history.add(entry.map((k, v) => MapEntry(k.toString(), v)));
          }
        }
        history.sort((a, b) => (b['ts'] ?? 0).compareTo(a['ts'] ?? 0));
      }
    }
    setState(() { _rewardHistory = history; });
  }

  Future<void> _giftItem(Map<String, dynamic> item, {String? recipientUid}) async {
    if (_uid == null) return;
    final targetUid = recipientUid ?? _uid;
    final recipientRef = FirebaseDatabase.instance.ref('users/$targetUid');
    final userKey = item['userKey'] ?? item['id'];
    final userValue = item.containsKey('userValue') ? item['userValue'] : true;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (item['type'] == 'subscription') {
      final duration = (item['durationDays'] ?? 30) as int;
      final expiry = now + duration * 24 * 60 * 60 * 1000;
      await recipientRef.update({userKey: expiry});
      if (item['syncKey'] != null) {
        await recipientRef.update({item['syncKey']: true});
      }
    } else {
      await recipientRef.update({userKey: userValue});
    }
    final spentRef = FirebaseDatabase.instance.ref('users/$_uid/spentStreaks');
    await spentRef.push().set({'item': item['id'] ?? userKey, 'cost': item['cost'] ?? 0, 'ts': now, 'giftedTo': targetUid});
    await FirebaseDatabase.instance.ref('users/$_uid').update({'streaks': _streaks - (item['cost'] ?? 0)});
    await _loadStreaks();
    await _loadPurchased();
    await _loadRewardHistory();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إهداء ${item['title']}!'), backgroundColor: Colors.green));
  }

  Future<void> _loadLeaderboard() async {
    final usersRef = FirebaseDatabase.instance.ref('users');
    final snap = await usersRef.get();
    List<Map<String, dynamic>> users = [];
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      final List<Future<Map<String, dynamic>?>> futures = [];
      for (final entry in data.entries) {
        final key = entry.key;
        final user = Map<String, dynamic>.from(entry.value as Map);
        futures.add(() async {
          try {
            int streaks = await _calculateStreak(key);
            final spentRef = FirebaseDatabase.instance.ref('users/$key/spentStreaks');
            final spentSnap = await spentRef.get();
            int spent = 0;
            if (spentSnap.exists && spentSnap.value != null) {
              final val = spentSnap.value;
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
            streaks -= spent;
            if (streaks > 0) {
              return {
                'uid': key,
                'username': user['username'] ?? '',
                'pic': user['pic'] ?? '',
                'streaks': streaks,
                'verify': user['verify'] ?? false,
                'mod': user['mod'] ?? false,
                'contributor': user['contributor'] ?? false,
                'team': user['team'] ?? false,
              };
            }
          } catch (_) {}
          return null;
        }());
      }
      final results = await Future.wait(futures);
      users = results.whereType<Map<String, dynamic>>().toList();
      users.sort((a, b) => (b['streaks'] ?? 0).compareTo(a['streaks'] ?? 0));
    }
    setState(() { _leaderboard = users.take(50).toList(); });
  }

  Future<void> _loadFollowersAndFollowing() async {
    if (_uid == null) return;
    final userRef = FirebaseDatabase.instance.ref('users/$_uid');
    final snap = await userRef.get();
    List<Map<String, dynamic>> followers = [];
    List<Map<String, dynamic>> following = [];
    if (snap.exists && snap.value != null) {
      final userData = Map<String, dynamic>.from(snap.value as Map);
      if (userData['followers'] is Map) {
        (userData['followers'] as Map).forEach((k, v) {
          followers.add({'uid': k, 'username': v is Map ? v['username'] ?? '' : '', 'pic': v is Map ? v['pic'] ?? '' : ''});
        });
      } else if (userData['followers'] is List) {
        for (final v in userData['followers']) {
          if (v is String) followers.add({'uid': v});
        }
      }
      if (userData['following'] is Map) {
        (userData['following'] as Map).forEach((k, v) {
          following.add({'uid': k, 'username': v is Map ? v['username'] ?? '' : '', 'pic': v is Map ? v['pic'] ?? '' : ''});
        });
      } else if (userData['following'] is List) {
        for (final v in userData['following']) {
          if (v is String) following.add({'uid': v});
        }
      }
    }
    setState(() { _followers = followers; _following = following; });
  }

  Future<void> _redeemPromoCode() async {
    if (_uid == null) return;
    final code = _promoController.text.trim();
    print('DEBUG: Entered promo code: "$code"');
    if (code.isEmpty) return;
    setState(() { _redeemingPromo = true; });
    final promoRef = FirebaseDatabase.instance.ref('streaks_store/promo');
    final promoSnap = await promoRef.get();
    if (!promoSnap.exists || promoSnap.value == null) {
      setState(() { _redeemingPromo = false; });
      print('DEBUG: No promo codes found in DB');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا توجد رموز ترويجية حالياً'), backgroundColor: Colors.red));
      return;
    }
    final promos = Map<String, dynamic>.from(promoSnap.value as Map);
    print('DEBUG: Loaded promos: \n$promos');
    bool found = false;
    for (final entry in promos.entries) {
      final promoKey = entry.key;
      final promoData = Map<String, dynamic>.from(entry.value as Map);
      final encrypted = promoData['encrypted'] as String?;
      final usage = (promoData['usage'] ?? 1) as int;
      final ivStr = promoData['iv'] as String?;
      print('DEBUG: Checking promoKey=$promoKey encrypted=$encrypted usage=$usage iv=$ivStr');
      if (encrypted == null || usage < 1 || ivStr == null) continue;
      try {
        final keyStr = code.padRight(32, '0').substring(0, 32);
        print('DEBUG: Using key: "$keyStr"');
        final key = encrypt.Key.fromUtf8(keyStr);
        final iv = encrypt.IV.fromBase64(ivStr);
        print('DEBUG: Using IV: ${iv.bytes}');
        final encrypter = encrypt.Encrypter(encrypt.AES(key));
        final decrypted = encrypter.decrypt64(encrypted, iv: iv);
        print('DEBUG: Decryption success, got productId: "$decrypted"');
        final productId = decrypted;
        final userRef = FirebaseDatabase.instance.ref('users/$_uid');
        final spentRef = FirebaseDatabase.instance.ref('users/$_uid/spentStreaks');
        final now = DateTime.now().millisecondsSinceEpoch;
        await userRef.update({productId: true});
        await spentRef.push().set({'item': productId, 'cost': 0, 'ts': now, 'promo': code});
        if (usage > 1) {
          await promoRef.child(promoKey).update({'usage': usage - 1});
        } else {
          await promoRef.child(promoKey).remove();
        }
        setState(() { _redeemingPromo = false; });
        print('DEBUG: Promo code redeemed successfully');
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تفعيل الرمز وحصلت على المنتج!'), backgroundColor: Colors.green)); }
        await _loadPurchased();
        found = true;
        break;
      } catch (e) {
        print('DEBUG: Decryption failed for promoKey=$promoKey: $e');
      }
    }
    if (!found) {
      setState(() { _redeemingPromo = false; });
      print('DEBUG: No valid promo code found for input');
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('رمز غير صالح أو منتهي'), backgroundColor: Colors.red)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading || _storeLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Ashur Streaks'),
          backgroundColor: colorScheme.surface,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_showIntro) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Ashur Streaks'),
          backgroundColor: colorScheme.surface,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('مرحبا الى اشور ستريكس', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                SizedBox(height: 24),
                Text('هنا يمكنك استخدام نقاط الستريك التي جمعتها من نشاطك في التطبيق لشراء مزايا أو عناصر خاصة. كلما زاد تفاعلك، زادت نقاط الستريك لديك!', style: TextStyle(fontSize: 18, color: colorScheme.onSurface), textAlign: TextAlign.center),
                SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showIntro = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('حسنا'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () {
            if (_userData != null && (_userData!['mod'] == true)) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddProductPage()),
              );
            }
          },
          child: Text('Ashur Streaks'),
        ),
        backgroundColor: colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'المتجر'),
            Tab(text: 'المتصدرين'),
            Tab(text: 'التحديات'),
            Tab(text: 'المكافآت'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promoController,
                        enabled: !_redeemingPromo,
                        decoration: InputDecoration(
                          hintText: 'ادخل رمز ترويجي',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _redeemingPromo ? null : _redeemPromoCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _redeemingPromo ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('تفعيل'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _storeItems.isEmpty
                  ? Center(child: Text('لا توجد عناصر في المتجر حالياً', style: TextStyle(fontSize: 22, color: colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      itemCount: _storeItems.length,
                      itemBuilder: (context, idx) {
                        final item = _storeItems[idx];
                        final cost = item['cost'] ?? 0;
                        final type = item['type'];
                        final userKey = item['userKey'] ?? item['id'];
                        return FutureBuilder<DatabaseEvent>(
                          future: _uid == null ? null : FirebaseDatabase.instance.ref('users/$_uid').once(),
                          builder: (context, userSnap) {
                            Map<String, dynamic> userData = {};
                            if (userSnap.hasData && userSnap.data!.snapshot.value != null) {
                              userData = Map<String, dynamic>.from(userSnap.data!.snapshot.value as Map);
                            }
                            bool isSubscription = item['type'] == 'subscription';
                            bool isActive = false;
                            int? expiry;
                            if (isSubscription) {
                              expiry = userData[userKey];
                              final now = DateTime.now().millisecondsSinceEpoch;
                              isActive = expiry != null && now < expiry;
                            }
                            final alreadyOwned = _purchasedKeys.contains(userKey);
                            return Card(
                              margin: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_iconFromString(item['icon'], type), color: colorScheme.primary, size: 28),
                                        SizedBox(width: 12),
                                        Text(item['title'] ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                                        Spacer(),
                                        Chip(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bolt, color: Colors.amber, size: 16),
                                              SizedBox(width: 2),
                                              Text('$cost', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          backgroundColor: Colors.amber.withOpacity(0.1),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text(item['desc'] ?? '', style: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant)),
                                    SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: isSubscription
                                            ? (
                                              isActive
                                                ? Row(
                                                    children: [
                                                      if (item['route'] != null)
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed: () {
                                                              Navigator.of(context).pushNamed(item['route']);
                                                            },
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: colorScheme.primary,
                                                              foregroundColor: colorScheme.onPrimary,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(16),
                                                              ),
                                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                            ),
                                                            child: Text('إدارة'),
                                                          ),
                                                        ),
                                                      if (item['route'] == null)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                          decoration: BoxDecoration(
                                                            color: colorScheme.primaryContainer,
                                                            borderRadius: BorderRadius.circular(16),
                                                          ),
                                                          child: Text('نشط', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                                        ),
                                                      SizedBox(width: 12),
                                                      Text('حتى ${_formatExpiry(expiry!)}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                                                    ],
                                                  )
                                                : ElevatedButton(
                                                    onPressed: (_streaks < cost) ? null : () => _buyItem(item),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: colorScheme.primary,
                                                      foregroundColor: colorScheme.onPrimary,
                                                      padding: EdgeInsets.symmetric(vertical: 14),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    child: Text('اشترك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                  )
                                            )
                                            : (alreadyOwned && item['route'] != null
                                                ? ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.of(context).pushNamed(item['route']);
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: colorScheme.primary,
                                                      foregroundColor: colorScheme.onPrimary,
                                                      padding: EdgeInsets.symmetric(vertical: 14),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    child: Text('فتح'),
                                                  )
                                                : Row(
                                                    children: [
                                                      Expanded(
                                                        child: ElevatedButton(
                                                          onPressed: (_streaks < cost || alreadyOwned) ? null : () => _buyItem(item),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: colorScheme.primary,
                                                            foregroundColor: colorScheme.onPrimary,
                                                            padding: EdgeInsets.symmetric(vertical: 14),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          ),
                                                          child: Text(alreadyOwned ? 'تمتلكها' : 'شراء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      if (!alreadyOwned && _streaks >= cost)
                                                        ElevatedButton(
                                                          onPressed: () => _giftItem(item),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: colorScheme.secondary,
                                                            foregroundColor: colorScheme.onSecondary,
                                                            padding: EdgeInsets.symmetric(vertical: 14),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          ),
                                                          child: Text('إهداء'),
                                                        ),
                                                    ],
                                                  )
                                            ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
          _leaderboard.isEmpty
            ? Center(child: Text('لا يوجد متصدرون بعد', style: TextStyle(fontSize: 22, color: colorScheme.onSurfaceVariant)))
            : ListView.builder(
                itemCount: _leaderboard.length,
                itemBuilder: (context, idx) {
                  final user = _leaderboard[idx];
                  final isMe = user['uid'] == _uid;
                  return ListTile(
                    leading: user['pic'] != null && user['pic'] != '' ? CircleAvatar(backgroundImage: NetworkImage(user['pic'])) : CircleAvatar(child: Icon(Icons.person)),
                    title: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => foryouscreen(id: user['uid'], showBottomBar: false),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            user['username'] != null && user['username'].toString().isNotEmpty
                              ? '@${user['username']}'
                              : '@${user['uid']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: user['profileTheme'] != null && user['profileTheme'] != '' ? Color(int.tryParse(user['profileTheme']) ?? 0) : Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          SizedBox(width: 6),
                          UserBadges(userData: user, iconSize: 16),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, color: Colors.amber, size: 18),
                        SizedBox(width: 4),
                        Text('${user['streaks'] ?? 0}', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        if (!isMe) ...[
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.card_giftcard, color: Theme.of(context).colorScheme.secondary),
                            tooltip: 'إهداء عنصر',
                            onPressed: () async {
                              final ownedItems = _storeItems.where((item) {
                                final userKey = item['userKey'] ?? item['id'];
                                return _purchasedKeys.contains(userKey);
                              }).toList();
                              if (ownedItems.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لا تملك أي عناصر لإهدائها')));
                                return;
                              }
                              Map<String, dynamic>? selectedItem;
                              await showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text('اختر عنصر لإهدائه'),
                                    content: SizedBox(
                                      width: 300,
                                      height: 300,
                                      child: ListView.builder(
                                        itemCount: ownedItems.length,
                                        itemBuilder: (context, idx) {
                                          final item = ownedItems[idx];
                                          return ListTile(
                                            leading: Icon(_iconFromString(item['icon'], item['type']), color: Theme.of(context).colorScheme.primary),
                                            title: Text(item['title'] ?? ''),
                                            subtitle: Text(item['desc'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                                            onTap: () {
                                              selectedItem = item;
                                              Navigator.pop(context);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                              if (selectedItem != null) {
                                await _giftItem(selectedItem!, recipientUid: user['uid']);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          FutureBuilder<DatabaseEvent>(
            future: FirebaseDatabase.instance.ref('challenges').once(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return Center(child: Text('لا توجد تحديات حالياً'));
              }
              final data = Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
              final List<Map<String, dynamic>> challenges = [];
              data.forEach((key, value) {
                if (value is Map) {
                  final challenge = Map<String, dynamic>.from(value);
                  challenge['type'] = key;
                  if (challenge['show'] == null || challenge['show'] == true) {
                    challenges.add(challenge);
                  }
                }
              });
              if (challenges.isEmpty) {
                return Center(child: Text('لا توجد تحديات حالياً'));
              }
              return FutureBuilder<DatabaseEvent>(
                future: _uid == null ? null : FirebaseDatabase.instance.ref('users/$_uid/challenges').once(),
                builder: (context, userSnap) {
                  Map<String, dynamic> userChallenges = {};
                  if (userSnap.hasData && userSnap.data!.snapshot.value != null) {
                    userChallenges = Map<String, dynamic>.from(userSnap.data!.snapshot.value as Map);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: challenges.length,
                    itemBuilder: (context, idx) {
                      final challenge = challenges[idx];
                      final key = challenge['type'];
                      IconData icon;
                      switch (challenge['icon']) {
                        case 'bolt': icon = Icons.bolt; break;
                        case 'star': icon = Icons.star; break;
                        case 'flag': icon = Icons.flag; break;
                        case 'analytics': icon = Icons.analytics; break;
                        case 'gift': icon = Icons.card_giftcard; break;
                        case 'color': icon = Icons.color_lens; break;
                        case 'crown': icon = Icons.emoji_events; break;
                        case 'verified': icon = Icons.verified; break;
                        default:
                          icon = challenge['type'] == 'daily' ? Icons.bolt : challenge['type'] == 'weekly' ? Icons.star : Icons.flag;
                      }
                      final userData = userChallenges[key] ?? {};
                      final int progress = userData['progress'] is int ? userData['progress'] : 0;
                      final bool claimed = userData['claimed'] == true;
                      final int count = challenge['count'] is int ? challenge['count'] : 1;
                      final bool completed = progress >= count;
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          leading: Icon(icon, color: Colors.blue),
                          title: Text(challenge['title'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (challenge['desc'] != null) Text(challenge['desc']),
                              if (challenge['action'] != null && challenge['count'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('المطلوب: ${challenge['action']} × ${challenge['count']}', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('التقدم: $progress/$count', style: TextStyle(color: completed ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          trailing: completed
                            ? claimed
                              ? Icon(Icons.check, color: Colors.grey)
                              : ElevatedButton(
                                  onPressed: () async {
                                    if (_uid == null) return;
                                    await FirebaseDatabase.instance.ref('users/$_uid/challenges/$key/claimed').set(true);
                                    final reward = challenge['reward'] is int ? challenge['reward'] : 0;
                                    final itemId = challenge['item'];
                                    if (reward > 0) {
                                      final spentRef = FirebaseDatabase.instance.ref('users/$_uid/spentStreaks');
                                      final now = DateTime.now().millisecondsSinceEpoch;
                                      await spentRef.push().set({'item': 'challenge_reward', 'cost': reward * -1, 'ts': now, 'challenge': key});
                                    }
                                    if (itemId != null && itemId is String && itemId.isNotEmpty) {
                                      final itemSnap = await FirebaseDatabase.instance.ref('streaks_store/items/$itemId').get();
                                      if (itemSnap.exists && itemSnap.value != null) {
                                        final item = Map<String, dynamic>.from(itemSnap.value as Map);
                                        final userRef = FirebaseDatabase.instance.ref('users/$_uid');
                                        final userKey = item['userKey'] ?? item['id'];
                                        final userValue = item.containsKey('userValue') ? item['userValue'] : true;
                                        final now = DateTime.now().millisecondsSinceEpoch;
                                        if (item['type'] == 'subscription') {
                                          final duration = (item['durationDays'] ?? 30) as int;
                                          final expiry = now + duration * 24 * 60 * 60 * 1000;
                                          await userRef.update({userKey: expiry});
                                          if (item['syncKey'] != null) {
                                            await userRef.update({item['syncKey']: true});
                                          }
                                        } else {
                                          await userRef.update({userKey: userValue});
                                        }
                                        final spentRef = FirebaseDatabase.instance.ref('users/$_uid/spentStreaks');
                                        await spentRef.push().set({'item': item['id'] ?? userKey, 'cost': 0, 'ts': now, 'challenge': key});
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم استلام ${item['title'] ?? 'عنصر'} من التحدي!'), backgroundColor: Colors.green));
                                        }
                                      }
                                    }
                                    setState(() {});
                                  },
                                  child: Text('استلم'),
                                )
                            : null,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          _rewardHistory.isEmpty
            ? Center(child: Text('لا توجد مكافآت بعد', style: TextStyle(fontSize: 22, color: colorScheme.onSurfaceVariant)))
            : ListView.builder(
                itemCount: _rewardHistory.length,
                itemBuilder: (context, idx) {
                  final reward = _rewardHistory[idx];
                  final item = _storeItems.firstWhere((e) => (e['id'] ?? '') == (reward['item'] ?? ''), orElse: () => {});
                  return ListTile(
                    leading: Icon(_iconFromString(item['icon'], item['type']), color: colorScheme.primary, size: 28),
                    title: Text(item['title'] ?? reward['item'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item['desc'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(DateTime.fromMillisecondsSinceEpoch((reward['ts'] ?? 0) is int ? reward['ts'] : 0).toString().split(' ')[0], style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  );
                },
              ),
        ],
      ),
    );
  }
}

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _iconController = TextEditingController();
  final TextEditingController _userKeyController = TextEditingController();
  final TextEditingController _userValueController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _syncKeyController = TextEditingController();
  final TextEditingController _promoCodeController = TextEditingController();
  final TextEditingController _promoUsageController = TextEditingController(text: '1');
  bool _saving = false;
  bool _promoSaving = false;
  bool _hidden = false;
  String? _selectedProductId;
  List<Map<String, dynamic>> _allProducts = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadAllProducts();
  }

  Future<void> _loadAllProducts() async {
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
      _allProducts = items;
      _loadingProducts = false;
      if (_allProducts.isNotEmpty) {
        _selectedProductId = _allProducts.first['id'];
      }
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; });
    final ref = FirebaseDatabase.instance.ref('streaks_store/items');
    final newRef = ref.push();
    final data = {
      'title': _titleController.text.trim(),
      'desc': _descController.text.trim(),
      'cost': int.tryParse(_costController.text.trim()) ?? 0,
      'icon': _iconController.text.trim(),
      'type': _typeController.text.trim(),
      'userKey': _userKeyController.text.trim().isEmpty ? null : _userKeyController.text.trim(),
      'userValue': _userValueController.text.trim().isEmpty ? null : _userValueController.text.trim(),
      'durationDays': _durationController.text.trim().isEmpty ? null : int.tryParse(_durationController.text.trim()),
      'syncKey': _syncKeyController.text.trim().isEmpty ? null : _syncKeyController.text.trim(),
      'hidden': _hidden,
    };
    data.removeWhere((k, v) => v == null || (v is String && v.isEmpty));
    await newRef.set(data);
    setState(() { _saving = false; });
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة المنتج')));
    }
  }

  Future<void> _addPromoCode() async {
    final code = _promoCodeController.text.trim();
    final productId = _selectedProductId;
    final usage = int.tryParse(_promoUsageController.text.trim()) ?? 1;
    if (code.isEmpty || productId == null) return;
    setState(() { _promoSaving = true; });
    final key = encrypt.Key.fromUtf8(code.padRight(32, '0').substring(0, 32));
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(productId, iv: iv).base64;
    final promoRef = FirebaseDatabase.instance.ref('streaks_store/promo').push();
    await promoRef.set({'encrypted': encrypted, 'usage': usage, 'iv': iv.base64});
    setState(() { _promoSaving = false; });
    _promoCodeController.clear();
    _promoUsageController.text = '1';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة الرمز الترويجي')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('إضافة منتج جديد')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: 'العنوان'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(labelText: 'الوصف'),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _costController,
                    decoration: InputDecoration(labelText: 'التكلفة'),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _iconController,
                    decoration: InputDecoration(labelText: 'الأيقونة'),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _typeController,
                    decoration: InputDecoration(labelText: 'النوع'),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _userKeyController,
                    decoration: InputDecoration(labelText: 'userKey (اختياري)'),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _userValueController,
                    decoration: InputDecoration(labelText: 'userValue (اختياري)'),
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _durationController,
                    decoration: InputDecoration(labelText: 'مدة الاشتراك بالأيام (اختياري)'),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _syncKeyController,
                    decoration: InputDecoration(labelText: 'syncKey (اختياري)'),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _hidden,
                        onChanged: (v) {
                          setState(() { _hidden = v ?? false; });
                        },
                      ),
                      Text('منتج مخفي (فقط عبر رمز ترويجي)'),
                    ],
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('إضافة المنتج'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40),
            Text('إضافة رمز ترويجي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 16),
            _loadingProducts
                ? Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: _selectedProductId,
                    items: _allProducts.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['id'],
                        child: Text((item['title'] ?? item['id']).toString() + (item['hidden'] == true ? ' (مخفي)' : '')),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() { _selectedProductId = v; });
                    },
                    decoration: InputDecoration(labelText: 'اختر المنتج'),
                  ),
            SizedBox(height: 12),
            TextField(
              controller: _promoCodeController,
              decoration: InputDecoration(labelText: 'الرمز'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _promoUsageController,
              decoration: InputDecoration(labelText: 'عدد مرات الاستخدام'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _promoSaving ? null : _addPromoCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _promoSaving ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('إضافة الرمز الترويجي'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 