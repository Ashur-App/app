

import 'dart:convert';

import 'package:ashur/screens/gamedetails.dart';
import 'package:ashur/secrets.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AshurGames extends StatefulWidget {
  const AshurGames({super.key});

  @override
  _AshurGamesState createState() => _AshurGamesState();
}

class _AshurGamesState extends State<AshurGames> {
  List<Map<String, dynamic>> _games = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final response = await http.get(
        Uri.parse(ashurGamesUrl)
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> gamesData = json.decode(response.body);
        setState(() {
          _games = gamesData.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'فشل في تحميل الألعاب (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
    setState(() {
        _hasError = true;
        _errorMessage = 'خطأ في الاتصال: $e';
        _isLoading = false;
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
        appBar: AppBar(
        title: Text(
          'ألعاب أشور',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
          leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_hasError)
            IconButton(
              icon: Icon(Icons.refresh, color: colorScheme.primary),
              onPressed: _loadGames,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'جاري تحميل الألعاب...',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _hasError
              ? Center(
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
                        'حدث خطأ في تحميل الألعاب',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _loadGames,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                                  Icon(
                                    Icons.refresh,
                                    color: colorScheme.onPrimary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                        Text(
                                    'إعادة المحاولة',
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _games.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.games_outlined,
                            size: 64,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد ألعاب متاحة',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'سيتم إضافة ألعاب جديدة قريباً',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.6,
                      ),
                      itemCount: _games.length,
                      itemBuilder: (context, index) {
                        final game = _games[index];
                        final name = game['name'] ?? 'لعبة غير معروفة';
                        final image = game['image'] ?? '';
                        final description = game['description'] ?? '';

                        return Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
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
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => GameDetails(
                                      games_data: game,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(40),
                                        color: colorScheme.primary.withValues(alpha: 0.1),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(40),
                                        child: image.isNotEmpty
                                            ? Image.network(
                                                image,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.games,
                                                    size: 40,
                                                    color: colorScheme.primary,
                                                  );
                                                },
                                              )
                                            : Icon(
                                                Icons.games,
                                                size: 40,
                                                color: colorScheme.primary,
                                              ),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (description.isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        description,
                                        style: TextStyle(
                                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'العب الآن',
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                        ),
                      ],
                    ),
                  ),
                            ),
                          ),
              );
            },
          ),
    );
  }
}
