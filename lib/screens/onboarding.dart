import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final FocusNode _focusNode = FocusNode();
  final List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      title: 'مرحباً بك في آشور',
      description: 'افضل تطبيق تواصل اجتماعي عراقي',
      imageAsset: 'images/ashur.png',
    ),
    _OnboardingPageData(
      title: 'القصص والريلز',
      description: 'شارك لحظاتك عبر القصص والريلز القصيرة.',
      icon: Icons.auto_stories_rounded,
    ),
    _OnboardingPageData(
      title: 'الدردشة والمجموعات',
      description: 'تواصل مع أصدقائك وأنشئ مجموعات دردشة بسهولة.',
      icon: Icons.groups_rounded,
    ),
    _OnboardingPageData(
      title: 'تخصيص المظهر',
      description: 'اختر المظهر الذي يناسبك.',
      icon: Icons.color_lens_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    widget.onFinish();
  }

  Future<void> _confirmSkip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تخطي المقدمة؟'),
        content: Text('هل أنت متأكد أنك تريد تخطي المقدمة؟ يمكنك مشاهدتها لاحقاً من الإعدادات.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('تخطي')),
        ],
      ),
    );
    if (confirmed == true) _finishOnboarding();
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey.keyLabel == 'Arrow Right' && _currentPage < _pages.length - 1) {
        _pageController.nextPage(duration: Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else if (event.logicalKey.keyLabel == 'Arrow Left' && _currentPage > 0) {
        _pageController.previousPage(duration: Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: RawKeyboardListener(
            focusNode: _focusNode,
            onKey: _handleKey,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    physics: _currentPage == _pages.length - 1 ? NeverScrollableScrollPhysics() : null,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) {
                      final page = _pages[i];
                      return AnimatedSwitcher(
                        duration: Duration(milliseconds: 400),
                        child: Padding(
                          key: ValueKey(i),
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Semantics(
                                label: page.title,
                                child: page.imageAsset != null
                                  ? Image.asset(page.imageAsset!, height: 100, semanticLabel: page.title)
                                  : Icon(
                                      page.icon!,
                                      size: 100,
                                      color: colorScheme.primary,
                                      semanticLabel: page.title,
                                    ),
                              ),
                              SizedBox(height: 32),
                              Text(page.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              SizedBox(height: 16),
                              Text(page.description, style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                    width: i == _currentPage ? 18 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(6),
                      color: i == _currentPage ? colorScheme.primary : colorScheme.primary.withOpacity(0.3),
                    ),
                  )),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (_currentPage > 0)
                            IconButton(
                              icon: Icon(Icons.arrow_back),
                              tooltip: 'السابق',
                              onPressed: () => _pageController.previousPage(duration: Duration(milliseconds: 400), curve: Curves.easeInOut),
                            ),
                          TextButton(
                            onPressed: _confirmSkip,
                            child: Text('تخطي'),
                          ),
                        ],
                      ),
                      _currentPage == _pages.length - 1
                        ? ElevatedButton(
                            onPressed: _finishOnboarding,
                            child: Text('ابدأ'),
                          )
                        : IconButton(
                            icon: Icon(Icons.arrow_forward),
                            tooltip: 'التالي',
                            onPressed: () => _pageController.nextPage(duration: Duration(milliseconds: 400), curve: Curves.easeInOut),
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

class _OnboardingPageData {
  final String title;
  final String description;
  final String? imageAsset;
  final IconData? icon;
  _OnboardingPageData({required this.title, required this.description, this.imageAsset, this.icon});
} 