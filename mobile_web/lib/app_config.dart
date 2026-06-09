class AppConfig {
  static const bool isDemo =
      bool.fromEnvironment('NUROMOOD_DEMO', defaultValue: false);

  static const int demoUserId = 1;
}
