import 'package:flutter/material.dart';
import 'register_page.dart';
import 'journal_home.dart';
import 'db_helper.dart';
import 'theme/nuromood_ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.toggleTheme,
    this.isDarkMode = true,
  });

  final void Function(bool)? toggleTheme;
  final bool isDarkMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final DBHelper dbHelper = DBHelper();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  void login() async {
    setState(() => isLoading = true);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    final userId = await dbHelper.loginUser(email, password);
    if (!mounted) return;

    if (userId != null) {
      // ✅ Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login successful 🎉"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Small delay so user sees the notification
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JournalHomePage(
            userId: userId,
            isDarkMode: widget.isDarkMode,
            toggleTheme: widget.toggleTheme,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email or password")),
      );
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final compact = width < NeuroBreakpoints.mobile;
    final wide = width >= NeuroBreakpoints.tablet;
    final form = Padding(
      padding: EdgeInsets.all(compact ? 20 : 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MoodBrand(),
          const SizedBox(height: 24),
          const NeuroSectionLabel(text: "Private Journal", icon: Icons.lock),
          const SizedBox(height: 8),
          Text(
            "Welcome back",
            style: (compact
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.headlineMedium)
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text("Your private mood journal is ready.",
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 28),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: "Email",
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline),
              labelText: "Password",
            ),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: neuroFilledButton(context),
            onPressed: isLoading ? null : login,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("Login"),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.g_mobiledata),
            label: const Text("Google"),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Text(
                "Don't have an account?",
                style: theme.textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterPage(
                        toggleTheme: widget.toggleTheme,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  );
                },
                child: Text(
                  "Register here",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );

    return Scaffold(
      body: NeuroShell(
        padding: EdgeInsets.zero,
        child: Center(
          child: SingleChildScrollView(
            padding: neuroPagePadding(width),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 920 : 460),
              child: NeuroGlowFrame(
                child: NeuroCard(
                  padding: EdgeInsets.zero,
                  child: wide
                      ? SizedBox(
                          height: 560,
                          child: Row(
                            children: [
                              const Expanded(
                                child: NeuroAuthPanel(
                                  title: "Check in with yourself",
                                  subtitle:
                                      "A calm place to write, notice patterns, and return to what matters.",
                                ),
                              ),
                              Expanded(child: form),
                            ],
                          ),
                        )
                      : form,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
