import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../custom_theme.dart';
import '../main.dart';

class CustomThemesScreen extends StatefulWidget {
  const CustomThemesScreen({super.key});

  @override
  State<CustomThemesScreen> createState() => _CustomThemesScreenState();
}

class _CustomThemesScreenState extends State<CustomThemesScreen> {
  List<CustomTheme> _themes = [];
  String? _selectedThemeName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    setState(() => _loading = true);
    final themes = await CustomThemeManager.syncThemes();
    final selected = await CustomThemeManager.syncSelectedTheme();
    setState(() {
      _themes = themes;
      _selectedThemeName = selected;
      _loading = false;
    });
  }

  Future<void> _saveThemes() async {
    await CustomThemeManager.saveLocalThemes(_themes);
    final user = await CustomThemeManager.syncThemes();
    setState(() {});
  }

  void _showThemeEditor({CustomTheme? theme}) {
    final nameController = TextEditingController(text: theme?.name ?? '');
    Color primary = theme?.primaryColor ?? Colors.blue;
    Color accent = theme?.accentColor ?? Colors.amber;
    Color background = theme?.backgroundColor ?? Colors.white;
    Color text = theme?.textColor ?? Colors.black;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(theme == null ? 'إنشاء مظهر جديد' : 'تعديل المظهر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'اسم المظهر'),
                ),
                SizedBox(height: 12),
                _ColorPickerRow(
                  label: 'اللون الأساسي',
                  color: primary,
                  onChanged: (c) => setState(() => primary = c),
                ),
                _ColorPickerRow(
                  label: 'لون التمييز',
                  color: accent,
                  onChanged: (c) => setState(() => accent = c),
                ),
                _ColorPickerRow(
                  label: 'لون الخلفية',
                  color: background,
                  onChanged: (c) => setState(() => background = c),
                ),
                _ColorPickerRow(
                  label: 'لون النص',
                  color: text,
                  onChanged: (c) => setState(() => text = c),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final newTheme = CustomTheme(
                  name: name,
                  primaryColor: primary,
                  accentColor: accent,
                  backgroundColor: background,
                  textColor: text,
                );
                setState(() {
                  if (theme != null) {
                    final idx = _themes.indexWhere((t) => t.name == theme.name);
                    if (idx != -1) _themes[idx] = newTheme;
                  } else {
                    _themes.add(newTheme);
                  }
                });
                _saveThemes();
                Navigator.pop(context);
              },
              child: Text(theme == null ? 'حفظ' : 'تحديث'),
            ),
          ],
        );
      },
    );
  }

  void _deleteTheme(CustomTheme theme) async {
    setState(() {
      _themes.removeWhere((t) => t.name == theme.name);
      if (_selectedThemeName == theme.name) _selectedThemeName = null;
    });
    await _saveThemes();
  }

  void _selectTheme(CustomTheme theme) async {
    setState(() {
      _selectedThemeName = theme.name;
    });
    await CustomThemeManager.saveSelectedThemeName(theme.name);
    final user = await CustomThemeManager.syncSelectedTheme();
    customThemeNotifier.value = theme;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المظاهر المخصصة'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showThemeEditor(),
            tooltip: 'إضافة مظهر',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _themes.isEmpty
              ? Center(child: Text('لا توجد مظاهر مخصصة بعد'))
              : ListView.builder(
                  itemCount: _themes.length,
                  itemBuilder: (context, i) {
                    final theme = _themes[i];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(theme.name),
                        subtitle: Row(
                          children: [
                            _ColorDot(theme.primaryColor),
                            _ColorDot(theme.accentColor),
                            _ColorDot(theme.backgroundColor),
                            _ColorDot(theme.textColor),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _showThemeEditor(theme: theme),
                              tooltip: 'تعديل',
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => _deleteTheme(theme),
                              tooltip: 'حذف',
                            ),
                            Radio<String>(
                              value: theme.name,
                              groupValue: _selectedThemeName,
                              onChanged: (_) => _selectTheme(theme),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;
  const _ColorPickerRow({required this.label, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                Color tempColor = color;
                return AlertDialog(
                  title: Text(label),
                  content: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: color,
                      onColorChanged: (c) => tempColor = c,
                      enableAlpha: false,
                      showLabel: false,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        onChanged(tempColor);
                        Navigator.pop(context);
                      },
                      child: Text('اختيار'),
                    ),
                  ],
                );
              },
            );
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot(this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      margin: EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
      ),
    );
  }
} 