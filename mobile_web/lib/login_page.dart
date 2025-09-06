import 'package:flutter/material.dart';
import 'register_page.dart';
import 'journal_home.dart';
import 'db_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JournalHomePage(
            userId: userId,
            isDarkMode: false, // set initial theme
            toggleTheme: (val) {
              // optionally handle theme toggle, e.g., update shared preferences
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email or password")),
      );
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.8),
              theme.colorScheme.primary.withOpacity(0.6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.book,
                          size: 80, color: theme.colorScheme.primary),
                      const SizedBox(height: 10),
                      Text(
                        "Nuromood Journal",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Email
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email),
                          labelText: "Email",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.inputDecorationTheme.fillColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock),
                          labelText: "Password",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.inputDecorationTheme.fillColor,
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isLoading ? null : login,
                          child: isLoading
                              ? CircularProgressIndicator(
                                  color: theme.colorScheme.onPrimary)
                              : const Text(
                                  "Login",
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Register link
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RegisterPage()),
                              );
                            },
                            child: Text(
                              "Register here",
                              style:
                                  theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
