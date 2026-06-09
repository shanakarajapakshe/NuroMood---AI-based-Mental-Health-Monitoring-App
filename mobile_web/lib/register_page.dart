import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'login_page.dart';
import 'theme/nuromood_ui.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.toggleTheme,
    this.isDarkMode = true,
  });

  final void Function(bool)? toggleTheme;
  final bool isDarkMode;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final DBHelper dbHelper = DBHelper();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  void register() async {
    setState(() => isLoading = true);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final success = await dbHelper.registerUser(email, password);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(
            toggleTheme: widget.toggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email already registered")),
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
          const NeuroSectionLabel(
              text: "Start Nuromood", icon: Icons.auto_awesome),
          const SizedBox(height: 8),
          Text(
            "Create your safe space",
            style: (compact
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.headlineMedium)
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text("Privacy-first journaling with mood insights.",
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
            obscureText: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline),
              labelText: "Password",
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: neuroFilledButton(context),
            onPressed: isLoading ? null : register,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text("Register"),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Text(
                "Already have an account?",
                style: theme.textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginPage(
                        toggleTheme: widget.toggleTheme,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),
                  );
                },
                child: Text(
                  "Login here",
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
                                  title: "Start with one honest note",
                                  subtitle:
                                      "Capture today, see emotional patterns, and keep your journal close.",
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
