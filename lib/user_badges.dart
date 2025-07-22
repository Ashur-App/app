import 'package:flutter/material.dart';

class UserBadges extends StatelessWidget {
  final Map<String, dynamic> userData;
  final double iconSize;
  final double spacing;

  const UserBadges({
    super.key,
    required this.userData,
    this.iconSize = 16,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];
    if (userData['verify'] == true) {
      badges.add(Container(
        decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
        padding: EdgeInsets.all(2),
        child: Icon(Icons.check, color: Colors.white, size: iconSize),
      ));
    }
    if (userData['mod'] == true) {
      badges.add(Container(
        decoration: BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
        padding: EdgeInsets.all(2),
        child: Icon(Icons.shield, color: Colors.white, size: iconSize),
      ));
    }
    if (userData['contributor'] == true) {
      badges.add(Container(
        decoration: BoxDecoration(color: Colors.amber[800], shape: BoxShape.circle),
        padding: EdgeInsets.all(2),
        child: Icon(Icons.star, color: Colors.white, size: iconSize),
      ));
    }
    if (userData['team'] == true) {
      badges.add(Container(
        decoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
        padding: EdgeInsets.all(2),
        child: Icon(Icons.groups, color: Colors.white, size: iconSize),
      ));
    }
    if (userData['achievements'] != null && userData['achievements'] is List) {
      final achievements = List<String>.from(userData['achievements'].whereType<String>().where((a) => a.isNotEmpty));
      if (achievements.isNotEmpty) {
        badges.add(
          Tooltip(
            message: 'الإنجازات: ${achievements.join(', ')}',
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  decoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.emoji_events, color: Colors.white, size: iconSize),
                ),
                if (achievements.length > 1)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: iconSize * 0.7,
                        minHeight: iconSize * 0.7,
                      ),
                      child: Text(
                        '+${achievements.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: iconSize * 0.6,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }
    if (userData['isBot'] == true) {
      badges.add(Container(
        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
        padding: EdgeInsets.all(2),
        child: Icon(Icons.smart_toy, color: Colors.white, size: iconSize),
      ));
    }
    if (badges.isEmpty) return SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < badges.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          badges[i],
        ]
      ],
    );
  }
} 