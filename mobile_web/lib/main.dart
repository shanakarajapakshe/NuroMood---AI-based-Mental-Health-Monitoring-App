import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'login_page.dart';
import 'journal_home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_page.dart';
import 'screens/biometric_gatekeeper.dart';
import 'services/notification_service.dart';
import 'theme/nuromood_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await DBHelper().init();

  final int? currentUser = await DBHelper().getCurrentUser();

  // Check first launch
  final prefs = await SharedPreferences.getInstance();
  final bool firstLaunch = prefs.getBool('first_launch') ?? true;
  if (firstLaunch) {
    await prefs.setBool('first_launch', false);
  }

  runApp(MyApp(currentUser: currentUser, firstLaunch: firstLaunch));
}

/// Theme extension for gradients
@immutable
class AppGradients extends ThemeExtension<AppGradients> {
  final LinearGradient background;
  final LinearGradient button;

  const AppGradients({
    required this.background,
    required this.button,
  });

  @override
  AppGradients copyWith({LinearGradient? background, LinearGradient? button}) {
    return AppGradients(
      background: background ?? this.background,
      button: button ?? this.button,
    );
  }

  @override
  AppGradients lerp(ThemeExtension<AppGradients>? other, double t) {
    if (other is! AppGradients) return this;
    return this;
  }
}

class MyApp extends StatefulWidget {
  final int? currentUser;
  final bool firstLaunch;
  const MyApp({super.key, this.currentUser, required this.firstLaunch});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = true;
  int? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser; // initialize user state
    _loadTheme(); // load saved theme
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    });
  }

  void toggleTheme(bool value) async {
    setState(() {
      isDarkMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      primaryColor: const Color(0xFF177E89),
      scaffoldBackgroundColor: const Color(0xFFEAF7F4),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFD8E6E4),
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF177E89),
        secondary: const Color(0xFF7B61D1),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: NeuroColors.ink,
        outlineVariant: const Color(0xFFD8E6E4),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: NeuroColors.ink),
        bodyMedium: TextStyle(color: NeuroColors.muted),
        titleLarge:
            TextStyle(color: NeuroColors.ink, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.78),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFFD8E6E4))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: NeuroColors.teal, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: Color(0xFFB9D3D5)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        indicatorColor: const Color(0xFF177E89).withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xFF177E89) : NeuroColors.ink,
            size: selected ? 25 : 23,
          );
        }),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: NeuroColors.muted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
      useMaterial3: true,
      extensions: const <ThemeExtension<dynamic>>[
        AppGradients(
          background: LinearGradient(
            colors: [Color(0xFFE5F4FF), Color(0xFFDDF4EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          button: LinearGradient(
            colors: [Color(0xFF63AFC1), Color(0xFF7CCBA2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );

    final darkTheme = ThemeData(
      primaryColor: NeuroColors.teal,
      scaffoldBackgroundColor: NeuroColors.dark,
      cardColor: NeuroColors.darkCard,
      dividerColor: const Color(0xFF25485C),
      colorScheme: ColorScheme.dark(
        primary: NeuroColors.teal,
        secondary: NeuroColors.electricPink,
        onPrimary: const Color(0xFF06121C),
        onSecondary: Colors.white,
        surface: NeuroColors.darkCard,
        onSurface: Colors.white,
        outlineVariant: const Color(0xFF2B6073),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFFAAC6D3)),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A2031).withValues(alpha: 0.76),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: Color(0xFFAAC6D3)),
        prefixIconColor: NeuroColors.teal,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: NeuroColors.teal.withValues(alpha: 0.24))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: NeuroColors.teal, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: NeuroColors.teal,
        foregroundColor: const Color(0xFF06121C),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide(color: NeuroColors.teal.withValues(alpha: 0.42)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF102638).withValues(alpha: 0.78),
        selectedColor: NeuroColors.teal.withValues(alpha: 0.22),
        side: BorderSide(color: NeuroColors.teal.withValues(alpha: 0.24)),
        labelStyle: const TextStyle(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFF07131F).withValues(alpha: 0.94),
        indicatorColor: NeuroColors.electricPink.withValues(alpha: 0.18),
        elevation: 10,
        shadowColor: NeuroColors.electricPink.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? NeuroColors.electricPink : NeuroColors.teal,
            size: selected ? 25 : 23,
          );
        }),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        )),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: NeuroColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      useMaterial3: true,
      extensions: const <ThemeExtension<dynamic>>[
        AppGradients(
          background: LinearGradient(
            colors: [
              Color(0xFF2E262C), // 15%
              Color(0xFF2B2332), // 23%
              Color(0xFF262031), // 48%
              Color(0xFF241A31), // 70%
              Color(0xFF1E1B30), // 93%
            ],
            stops: [0.15, 0.23, 0.48, 0.70, 0.93],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          button: LinearGradient(
            colors: [Color(0xFF8E7CFF), Color(0xFFF3A6D8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );

    return MaterialApp(
      title: 'Nuromood',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.firstLaunch
          ? RegisterPage(
              toggleTheme: toggleTheme,
              isDarkMode: isDarkMode,
            )
          : (widget.currentUser != null
              ? BiometricGatekeeper(
                  fallback: LoginPage(
                    toggleTheme: toggleTheme,
                    isDarkMode: isDarkMode,
                  ),
                  child: JournalHomePage(
                    userId: widget.currentUser!,
                    toggleTheme: toggleTheme,
                    isDarkMode: isDarkMode,
                  ),
                )
              : LoginPage(
                  toggleTheme: toggleTheme,
                  isDarkMode: isDarkMode,
                )),
    );
  }
}
