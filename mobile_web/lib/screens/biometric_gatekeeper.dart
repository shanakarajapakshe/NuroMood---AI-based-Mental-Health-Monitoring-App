import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/security_service.dart';

class BiometricGatekeeper extends StatefulWidget {
  const BiometricGatekeeper({
    super.key,
    required this.child,
    required this.fallback,
  });

  final Widget child;
  final Widget fallback;

  @override
  State<BiometricGatekeeper> createState() => _BiometricGatekeeperState();
}

class _BiometricGatekeeperState extends State<BiometricGatekeeper>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _checking = true;
  bool _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      _unlocked = true;
      _checking = false;
      return;
    }
    _unlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      setState(() {
        _unlocked = false;
      });
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _unlocked = true;
        _checking = false;
      });
      return;
    }
    setState(() => _checking = true);
    final success = await SecurityService.instance.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() {
      _unlocked = success;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;

    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 18),
                Text('NeuroMood is locked',
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Use biometrics to open your private journal.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (_checking)
                  const CircularProgressIndicator()
                else ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Retry Biometrics'),
                    onPressed: _unlock,
                  ),
                  const SizedBox(height: 12),
                  widget.fallback,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
