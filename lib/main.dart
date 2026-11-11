import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_shell.dart';
import 'profile_store.dart';
import 'services/image_proxy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await ProfileStore.load();
    await ImageCacheService.init();
  } catch (_) {}
  runApp(const PlayerDeckApp());
}

class AccentColorScope extends InheritedWidget {
  final Color accentColor;

  const AccentColorScope({
    super.key,
    required this.accentColor,
    required super.child,
  });

  static Color of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AccentColorScope>();
    return scope?.accentColor ?? const Color(0xFF7F9D9D); // #7F9D9D Accent
  }

  /// Returns black text/icon color for content on accent background
  static Color onAccent(BuildContext context) {
    return Colors.black;
  }

  @override
  bool updateShouldNotify(AccentColorScope oldWidget) {
    return oldWidget.accentColor != accentColor;
  }
}

class PlayerDeckApp extends StatefulWidget {
  const PlayerDeckApp({super.key});

  @override
  State<PlayerDeckApp> createState() => _PlayerDeckAppState();
}

class _PlayerDeckAppState extends State<PlayerDeckApp> {
  Color _accentColor = const Color(0xFF7F9D9D); // #7F9D9D Accent Default
  bool _isDarkMode = true;
  List<Color> _recentColors = [
    const Color(0xFF7F9D9D), // #7F9D9D
    const Color(0xFF5D7679), // Dark Sage
    const Color(0xFF699696), // Sage Teal
    const Color(0xFF757575), // Material Grey
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accentValue = prefs.getInt('accent_color');
      final isDarkMode = prefs.getBool('dark_mode');
      final recentColorsStr = prefs.getStringList('recent_colors');

      setState(() {
        _accentColor = const Color(0xFF7F9D9D); // Enforce #7F9D9D Accent
        if (isDarkMode != null) _isDarkMode = isDarkMode;
      });
      await prefs.setInt('accent_color', const Color(0xFF7F9D9D).toARGB32());
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('accent_color', _accentColor.toARGB32());
      await prefs.setBool('dark_mode', _isDarkMode);
      await prefs.setStringList(
        'recent_colors',
        _recentColors.map((e) => e.toARGB32().toString()).toList(),
      );
    } catch (_) {}
  }

  void _onAccentChanged(Color color) {
    setState(() {
      _accentColor = color;
    });
  }

  void _onAccentSaved(Color color) {
    setState(() {
      _accentColor = color;
      _recentColors.remove(color);
      _recentColors.insert(0, color);
      if (_recentColors.length > 4) _recentColors = _recentColors.sublist(0, 4);
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return AccentColorScope(
      accentColor: _accentColor,
      child: MaterialApp(
        title: 'PlayerDeck',
        debugShowCheckedModeBanner: false,
        theme: _isDarkMode ? _buildDarkTheme() : _buildLightTheme(),
        home: AppShell(
          onAccentChanged: _onAccentChanged,
          onAccentSaved: _onAccentSaved,
          recentColors: _recentColors,
          isDarkMode: _isDarkMode,
          onToggleDarkMode: (v) {
            setState(() => _isDarkMode = v);
            _saveSettings();
          },
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000), // OLED Pitch Black
      colorScheme: scheme.copyWith(
        primary: _accentColor,
        onPrimary: Colors.black,
        secondary: _accentColor,
        onSecondary: Colors.black,
        surface: const Color(0xFF1C1C1E),
        onSurface: Colors.white,
        outline: const Color(0xFF38383A),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _accentColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
        hintStyle: const TextStyle(color: Color(0xFF48484A)),
        prefixIconColor: const Color(0xFF8E8E93),
        suffixStyle: const TextStyle(color: Color(0xFF8E8E93)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2C2C2E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        selectedItemColor: _accentColor,
        unselectedItemColor: const Color(0xFF8E8E93),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _accentColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      colorScheme: scheme.copyWith(
        primary: _accentColor,
        secondary: _accentColor,
        surface: Colors.white,
        onSurface: const Color(0xFF1C1C1E),
        outline: const Color(0xFFE5E5EA),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1C1C1E), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
        hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
        prefixIconColor: const Color(0xFF8E8E93),
        suffixStyle: const TextStyle(color: Color(0xFF8E8E93)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1C1C1E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1C1C1E),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1C1C1E),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: _accentColor,
        unselectedItemColor: const Color(0xFF8E8E93),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
