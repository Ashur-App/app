import 'package:flutter/material.dart';

class AppDevsScreen extends StatelessWidget {
  const AppDevsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final devs = [
      {'name': 'NEOAPPS', 'role': 'المبرمج', 'avatar': 'images/ashur.png'},
      {'name': 'باقر', 'role': 'المالك', 'avatar': 'images/ashur.png'},
      {'name': 'مصطفى حيدر', 'role': 'تسويق', 'avatar': 'images/ashur.png'},
      {'name': 'DARK', 'role': 'تجربه', 'avatar': 'images/ashur.png'},
      {'name': 'علي', 'role': 'مطور', 'avatar': 'images/ashur.png'},
      {'name': 'سجاد عماد', 'role': 'تسويق وتجربه', 'avatar': 'images/ashur.png'},
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('المطورون', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: colorScheme.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset('images/ashur.png', width: 64, height: 64),
              SizedBox(height: 18),
              Text('فريق تطوير تطبيق آشور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: colorScheme.primary)),
              SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: devs.length,
                  separatorBuilder: (_, __) => SizedBox(height: 18),
                  itemBuilder: (context, i) {
                    final dev = devs[i];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: AssetImage(dev['avatar']!),
                              radius: 28,
                              backgroundColor: colorScheme.primary.withOpacity(0.1),
                            ),
                            SizedBox(width: 18),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dev['name']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: colorScheme.primary)),
                                SizedBox(height: 4),
                                Text(dev['role']!, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 