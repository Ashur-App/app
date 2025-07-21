import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'dart:collection';
import 'package:intl/intl.dart';
import 'streaks_store.dart';

class ProfileAnalyticsPage extends StatefulWidget {
  static const routeName = 'profile_analytics';
  const ProfileAnalyticsPage({super.key});
  @override
  State<ProfileAnalyticsPage> createState() => _ProfileAnalyticsPageState();
}

class _ProfileAnalyticsPageState extends State<ProfileAnalyticsPage> {
  int posts = 0;
  int reels = 0;
  int followers = 0;
  int likes = 0;
  int comments = 0;
  int shares = 0;
  int likesGiven = 0;
  int commentsGiven = 0;
  int sharesGiven = 0;
  bool loading = true;
  List<int> followerHistory = [];
  List<DateTime> followerDates = [];
  List<int> postTimes = List.filled(24, 0);
  Map<String, int> postsPerDay = {};
  List<double> likesPerPost = [];
  List<double> commentsPerPost = [];
  List<double> sharesPerPost = [];
  List<double> engagementPerPost = [];
  int reelsViews = 0;
  int reelsWatchTime = 0;
  List<double> reelsViewsPerReel = [];
  List<double> reelsWatchTimePerReel = [];
  List<double> reelsEngagementPerReel = [];
  bool analyticsUnlocked = false;

  @override
  void initState() {
    super.initState();
    checkAnalyticsUnlocked();
    loadStats();
    loadFollowerHistory();
    loadPostTimes();
  }

  Future<void> checkAnalyticsUnlocked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final userSnap = await FirebaseDatabase.instance.ref('users/$uid').get();
    if (userSnap.exists && userSnap.value != null) {
      final userData = Map<String, dynamic>.from(userSnap.value as Map<Object?, Object?>);
      if (userData['hasProfileAnalytics'] == true) {
        setState(() { analyticsUnlocked = true; });
      } else {
        setState(() { analyticsUnlocked = false; });
      }
    }
  }

  Future<void> loadStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    int p = 0, r = 0, f = 0, l = 0, c = 0, s = 0;
    int lGiven = 0, cGiven = 0, sGiven = 0;
    final postsSnap = await FirebaseDatabase.instance.ref('posts').get();
    if (postsSnap.exists && postsSnap.value != null) {
      final postsMap = postsSnap.value as Map<Object?, Object?>;
      for (final entry in postsMap.entries) {
        final key = entry.key;
        final post = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
        final userActions = Map<String, dynamic>.from(post['userActions'] ?? {});
        if (post['userEmail'] == uid) {
          p++;
          l += userActions.values.where((v) => v == 'like').length;
          s += ((post['shares'] ?? 0) as num).toInt();
          final commentsSnap = await FirebaseDatabase.instance.ref('comments/$key/comments').get();
          int postComments = 0;
          if (commentsSnap.exists && commentsSnap.value != null) {
            if (commentsSnap.value is List) {
              postComments = (commentsSnap.value as List).length;
            } else if (commentsSnap.value is Map) {
              postComments = (commentsSnap.value as Map).length;
            }
          }
          c += postComments;
          final createdAt = post['created_at'];
          if (createdAt != null) {
            final date = DateTime.tryParse(createdAt);
            if (date != null) {
              final day = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              postsPerDay[day] = (postsPerDay[day] ?? 0) + 1;
            }
          }
          final likes = userActions.values.where((v) => v == 'like').length.toDouble();
          final shares = ((post['shares'] ?? 0) as num).toDouble();
          likesPerPost.add(likes);
          commentsPerPost.add(postComments.toDouble());
          sharesPerPost.add(shares);
          engagementPerPost.add(likes + postComments + shares);
        } else {
          if (userActions[uid] == 'like') lGiven++;
          if (post['shares'] != null && post['shares'] is Map && (post['shares'] as Map).containsKey(uid)) sGiven++;
          final commentsSnap = await FirebaseDatabase.instance.ref('comments/$key/comments').get();
          if (commentsSnap.exists && commentsSnap.value != null) {
            if (commentsSnap.value is List) {
              for (final comment in commentsSnap.value as List) {
                if (comment is Map && comment['userEmail'] == uid) cGiven++;
              }
            } else if (commentsSnap.value is Map) {
              for (final comment in (commentsSnap.value as Map).values) {
                if (comment is Map && comment['userEmail'] == uid) cGiven++;
              }
            }
          }
        }
      }
    }
    final reelsSnap = await FirebaseDatabase.instance.ref('reels').get();
    if (reelsSnap.exists && reelsSnap.value != null) {
      final reelsMap = reelsSnap.value as Map<Object?, Object?>;
      for (final entry in reelsMap.entries) {
        final key = entry.key;
        final reel = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
        final userActions = Map<String, dynamic>.from(reel['userActions'] ?? {});
        if (reel['uid'] == uid) {
          r++;
          l += userActions.values.where((v) => v == 'like').length;
          s += ((reel['shares'] ?? 0) as num).toInt();
          final commentsSnap = await FirebaseDatabase.instance.ref('reels_comments/$key').get();
          int reelComments = 0;
          if (commentsSnap.exists && commentsSnap.value != null) {
            if (commentsSnap.value is List) {
              reelComments = (commentsSnap.value as List).length;
            } else if (commentsSnap.value is Map) {
              reelComments = (commentsSnap.value as Map).length;
            }
          }
          c += reelComments;
          int views = (reel['views'] ?? 0) as int;
          int watchTime = (reel['watchTime'] ?? 0) as int;
          reelsViews += views;
          reelsWatchTime += watchTime;
          reelsViewsPerReel.add(views.toDouble());
          reelsWatchTimePerReel.add(watchTime.toDouble() / 1000.0);
          final likes = userActions.values.where((v) => v == 'like').length.toDouble();
          final shares = ((reel['shares'] ?? 0) as num).toDouble();
          reelsEngagementPerReel.add(likes + reelComments + shares);
        } else {
          if (userActions[uid] == 'like') lGiven++;
          if (reel['shares'] != null && reel['shares'] is Map && (reel['shares'] as Map).containsKey(uid)) sGiven++;
          final commentsSnap = await FirebaseDatabase.instance.ref('reels_comments/$key').get();
          if (commentsSnap.exists && commentsSnap.value != null) {
            if (commentsSnap.value is List) {
              for (final comment in commentsSnap.value as List) {
                if (comment is Map && (comment['uid'] == uid || comment['userEmail'] == uid)) cGiven++;
              }
            } else if (commentsSnap.value is Map) {
              for (final comment in (commentsSnap.value as Map).values) {
                if (comment is Map && (comment['uid'] == uid || comment['userEmail'] == uid)) cGiven++;
              }
            }
          }
        }
      }
    }
    final userSnap = await FirebaseDatabase.instance.ref('users/$uid').get();
    if (userSnap.exists && userSnap.value != null) {
      final userData = Map<String, dynamic>.from(userSnap.value as Map<Object?, Object?>);
      if (userData['followers'] != null) {
        if (userData['followers'] is List) {
          f = (userData['followers'] as List).length;
        } else if (userData['followers'] is Map) {
          f = (userData['followers'] as Map).length;
        } else if (userData['followers'] is int) {
          f = userData['followers'];
        }
      }
    }
    setState(() {
      posts = p;
      reels = r;
      followers = f;
      likes = l;
      comments = c;
      shares = s;
      likesGiven = lGiven;
      commentsGiven = cGiven;
      sharesGiven = sGiven;
      loading = false;
    });
  }

  Future<void> loadFollowerHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final histSnap = await FirebaseDatabase.instance.ref('users/$uid/followerHistory').get();
    if (histSnap.exists && histSnap.value != null) {
      final histMap = Map<String, dynamic>.from(histSnap.value as Map);
      followerHistory = histMap.values.map((v) => v as int).toList();
      followerDates = histMap.keys.map((k) => DateTime.parse(k)).toList();
      setState(() {});
    }
  }

  Future<void> loadPostTimes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final postsSnap = await FirebaseDatabase.instance.ref('posts').get();
    if (postsSnap.exists && postsSnap.value != null) {
      final postsMap = postsSnap.value as Map<Object?, Object?>;
      for (final entry in postsMap.entries) {
        final post = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
        if (post['userEmail'] == uid && post['created_at'] != null) {
          final dt = DateTime.tryParse(post['created_at']);
          if (dt != null) postTimes[dt.hour]++;
        }
      }
      setState(() {});
    }
  }

  String _formatDay(String day) {
    try {
      final date = DateTime.parse(day);
      return DateFormat('MM/dd').format(date);
    } catch (_) {
      return day;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!analyticsUnlocked) {
      return Scaffold(
        appBar: AppBar(
          title: Text('إحصائيات الملف الشخصي'),
          backgroundColor: colorScheme.surface,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: colorScheme.primary),
              SizedBox(height: 24),
              Text('إحصائيات الملف الشخصي مقفلة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
              SizedBox(height: 12),
              Text('قم بفتحها من متجر الستريكس', style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
              SizedBox(height: 32),
              ElevatedButton.icon(
                icon: Icon(Icons.analytics),
                label: Text('فتح المتجر'),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => StreaksStore(showIntro: false)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('إحصائيات الملف الشخصي'),
        backgroundColor: colorScheme.surface,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('إحصائياتك', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                      ],
                    ),
                    SizedBox(height: 32),
                    StatTile(label: 'المنشورات', value: posts, icon: Icons.article),
                    StatTile(label: 'الريلز', value: reels, icon: Icons.video_collection),
                    StatTile(label: 'المتابعين', value: followers, icon: Icons.people),
                    StatTile(label: 'الإعجابات التي حصلت عليها', value: likes, icon: Icons.favorite),
                    StatTile(label: 'الإعجابات التي قمت بها', value: likesGiven, icon: Icons.favorite_border),
                    StatTile(label: 'التعليقات التي حصلت عليها', value: comments, icon: Icons.comment),
                    StatTile(label: 'التعليقات التي قمت بها', value: commentsGiven, icon: Icons.mode_comment_outlined),
                    StatTile(label: 'المشاركات التي حصلت عليها', value: shares, icon: Icons.share),
                    StatTile(label: 'المشاركات التي قمت بها', value: sharesGiven, icon: Icons.ios_share),
                    SizedBox(height: 32),
                    StatTile(label: 'مشاهدات الريلز', value: reelsViews, icon: Icons.visibility),
                    StatTile(label: 'وقت المشاهدة (ثانية)', value: reelsWatchTime ~/ 1000, icon: Icons.timer),
                    if (postsPerDay.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: 32),
                          Text('عدد المنشورات لكل يوم', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (final entry in SplayTreeMap<String, int>.from(postsPerDay).entries)
                                    BarChartGroupData(
                                      x: SplayTreeMap<String, int>.from(postsPerDay).keys.toList().indexOf(entry.key),
                                      barRods: [BarChartRodData(toY: entry.value.toDouble(), color: colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4),
                                        rodStackItems: [],
                                        borderSide: BorderSide.none,
                                        backDrawRodData: BackgroundBarChartRodData(show: false),
                                      )],
                                      showingTooltipIndicators: [0],
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                                    }),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      final keys = SplayTreeMap<String, int>.from(postsPerDay).keys.toList();
                                      if (idx >= 0 && idx < keys.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(_formatDay(keys[idx]), style: TextStyle(fontSize: 10)),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  ),
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      final keys = SplayTreeMap<String, int>.from(postsPerDay).keys.toList();
                                      return BarTooltipItem('${_formatDay(keys[group.x.toInt()])}\n${rod.toY.toInt()} منشور', TextStyle(color: Colors.white));
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (likesPerPost.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: 32),
                          Text('الإعجابات لكل منشور', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (int i = 0; i < likesPerPost.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [BarChartRodData(toY: likesPerPost[i], color: colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4))],
                                      showingTooltipIndicators: [0],
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                                    }),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                      if (value.toInt() % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('P${value.toInt() + 1}', style: TextStyle(fontSize: 10)),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  ),
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem('منشور ${group.x + 1}\n${rod.toY.toInt()} إعجاب', TextStyle(color: Colors.white));
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (commentsPerPost.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: 32),
                          Text('التعليقات لكل منشور', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (int i = 0; i < commentsPerPost.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [BarChartRodData(toY: commentsPerPost[i], color: colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4))],
                                      showingTooltipIndicators: [0],
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                                    }),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                      if (value.toInt() % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('P${value.toInt() + 1}', style: TextStyle(fontSize: 10)),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  ),
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem('منشور ${group.x + 1}\n${rod.toY.toInt()} تعليق', TextStyle(color: Colors.white));
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (sharesPerPost.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: 32),
                          Text('المشاركات لكل منشور', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (int i = 0; i < sharesPerPost.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [BarChartRodData(toY: sharesPerPost[i], color: colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4))],
                                      showingTooltipIndicators: [0],
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                                    }),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                      if (value.toInt() % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('P${value.toInt() + 1}', style: TextStyle(fontSize: 10)),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  ),
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem('منشور ${group.x + 1}\n${rod.toY.toInt()} مشاركة', TextStyle(color: Colors.white));
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (engagementPerPost.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: 32),
                          Text('معدل التفاعل لكل منشور', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (int i = 0; i < engagementPerPost.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [BarChartRodData(toY: engagementPerPost[i], color: colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4))],
                                      showingTooltipIndicators: [0],
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                                    }),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                      if (value.toInt() % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('P${value.toInt() + 1}', style: TextStyle(fontSize: 10)),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  ),
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem('منشور ${group.x + 1}\n${rod.toY.toInt()} تفاعل', TextStyle(color: Colors.white));
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (reelsViewsPerReel.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: 32),
                          Text('المشاهدات لكل ريل', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (int i = 0; i < reelsViewsPerReel.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [BarChartRodData(toY: reelsViewsPerReel[i], color: colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4))],
                                      showingTooltipIndicators: [0],
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                                    }),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                      if (value.toInt() % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('R${value.toInt() + 1}', style: TextStyle(fontSize: 10)),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  ),
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem('ريل ${group.x + 1}\n${rod.toY.toInt()} مشاهدة', TextStyle(color: Colors.white));
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (reelsWatchTimePerReel.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: 32),
                          Text('وقت المشاهدة لكل ريل (ثانية)', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (int i = 0; i < reelsWatchTimePerReel.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [BarChartRodData(toY: reelsWatchTimePerReel[i], color: colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4))],
                                      showingTooltipIndicators: [0],
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                                    }),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                      if (value.toInt() % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('R${value.toInt() + 1}', style: TextStyle(fontSize: 10)),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  ),
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem('ريل ${group.x + 1}\n${rod.toY.toInt()} ثانية', TextStyle(color: Colors.white));
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (reelsEngagementPerReel.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: 32),
                          Text('معدل التفاعل لكل ريل', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 240,
                            child: BarChart(
                              BarChartData(
                                barGroups: [
                                  for (int i = 0; i < reelsEngagementPerReel.length; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [BarChartRodData(toY: reelsEngagementPerReel[i], color: colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4))],
                                      showingTooltipIndicators: [0],
                                    ),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (value, meta) {
                                      return Text(value.toInt().toString(), style: TextStyle(fontSize: 12));
                                    }),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
                                      if (value.toInt() % 5 == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('R${value.toInt() + 1}', style: TextStyle(fontSize: 10)),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    }),
                                  ),
                                ),
                                barTouchData: BarTouchData(
                                  enabled: true,
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem('ريل ${group.x + 1}\n${rod.toY.toInt()} تفاعل', TextStyle(color: Colors.white));
                                    },
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(show: false),
                              ),
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final data = {
                          'posts': posts,
                          'reels': reels,
                          'followers': followers,
                          'likes': likes,
                          'comments': comments,
                          'shares': shares,
                          'likesGiven': likesGiven,
                          'commentsGiven': commentsGiven,
                          'sharesGiven': sharesGiven,
                          'followerHistory': followerHistory,
                          'postTimes': postTimes,
                        };
                        final csv = data.entries.map((e) => '${e.key},${e.value}').join('\n');
                        await FileSaver.instance.saveFile(
                          name: 'ashur_analytics.csv',
                          bytes: Uint8List.fromList(csv.codeUnits),
                          mimeType: MimeType.csv,
                        );
                      },
                      icon: Icon(Icons.download),
                      label: Text('تصدير البيانات'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  const StatTile({required this.label, required this.value, required this.icon, super.key});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary, size: 28),
          SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 18, color: colorScheme.onSurface, fontWeight: FontWeight.bold)),
          Spacer(),
          Text(value.toString(), style: TextStyle(fontSize: 20, color: colorScheme.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
} 