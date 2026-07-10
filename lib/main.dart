import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'services/tab_manager.dart';
import 'utils/device_optimizer.dart';
import 'screens/browser_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize device optimizer for low-end hardware
  DeviceOptimizer().init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SheinBrowserApp());
}

class SheinBrowserApp extends StatelessWidget {
  const SheinBrowserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(
          create: (_) => TabManager()..loadRecentlyClosed(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, sp, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SHEIN Browser',
            themeMode: sp.themeMode,
            theme: _lightTheme(),
            darkTheme: _darkTheme(),
            home: const BrowserScreen(),
          );
        },
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF69B4),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF222222),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF69B4),
        brightness: Brightness.dark,
        surface: const Color(0xFF0F0F1A),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Color(0xFFE8E8F0),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
