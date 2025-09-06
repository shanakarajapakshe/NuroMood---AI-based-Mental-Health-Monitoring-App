import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'login_page.dart';
import 'journal_home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  const MyApp({Key? key, this.currentUser, required this.firstLaunch}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;
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
      isDarkMode = prefs.getBool('is_dark_mode') ?? false;
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
      primaryColor: const Color(0xFF7B6CF6),
      scaffoldBackgroundColor: Colors.white,
      cardColor: const Color(0xFFF9FAFB),
      dividerColor: const Color(0xFFE5E7EB),
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF7B6CF6),
        secondary: const Color(0xFFE89AC7),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        background: Colors.white,
        surface: const Color(0xFFF9FAFB),
        onBackground: const Color(0xFF111827),
        onSurface: const Color(0xFF111827),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF111827)),
        bodyMedium: TextStyle(color: Color(0xFF4B5563)),
        titleLarge: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.bold),
      ),
      useMaterial3: true,
      extensions: const <ThemeExtension<dynamic>>[
        AppGradients(
          background: LinearGradient(
            colors: [Color(0xFF7B6CF6), Color(0xFFE89AC7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          button: LinearGradient(
            colors: [Color(0xFFA5B4FC), Color(0xFFC084FC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );

    final darkTheme = ThemeData(
  primaryColor: const Color(0xFF8E7CFF),
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF1C1C20),
  dividerColor: const Color(0xFF2D2D32),
  colorScheme: ColorScheme.dark(
    primary: const Color(0xFF8E7CFF),
    secondary: const Color(0xFFF3A6D8),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    background: const Color(0xFF121212),
    surface: const Color(0xFF1C1C20),
    onBackground: Colors.white,
    onSurface: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Color(0xFFA1A1AA)),
    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    ? const RegisterPage() // first launch → show registration
    : (widget.currentUser != null
        ? JournalHomePage(
            userId: widget.currentUser!,
            toggleTheme: toggleTheme,
   isDarkMode: isDarkMode,
          )
        : const LoginPage()),

    );
  }
}
