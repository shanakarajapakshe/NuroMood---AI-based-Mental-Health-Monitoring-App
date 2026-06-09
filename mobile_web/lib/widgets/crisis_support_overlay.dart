import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/nuromood_ui.dart';

class CrisisSupportOverlay extends StatelessWidget {
  const CrisisSupportOverlay({
    super.key,
    required this.onDismissed,
    required this.onAction,
  });

  final VoidCallback onDismissed;
  final void Function(String action) onAction;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onDismissed,
    required void Function(String action) onAction,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => CrisisSupportOverlay(onDismissed: onDismissed, onAction: onAction),
    );
  }

  Future<void> _call(String phoneNumber) async {
    onAction('call:$phoneNumber');
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark ? NeuroColors.darkCard : NeuroColors.blush,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: Icon(Icons.volunteer_activism, size: 46, color: theme.colorScheme.primary)),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'We care. Please reach out.',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your journal suggests this might be a heavy moment. A trained person can help you through the next few minutes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            NeuroCard(
              child: Column(
                children: [
                  _HelpLineTile(
                    title: '1926 National Mental Health Helpline',
                    subtitle: 'Sri Lanka - national support',
                    onCall: () => _call('1926'),
                  ),
                  _HelpLineTile(
                    title: 'Sri Lanka Sumithrayo',
                    subtitle: '011 269 6666',
                    onCall: () => _call('0112696666'),
                  ),
                  _HelpLineTile(
                    title: 'Emergency Services',
                    subtitle: '119 Sri Lanka Police Emergency',
                    onCall: () => _call('119'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: neuroFilledButton(context),
                icon: const Icon(Icons.call),
                label: const Text('Call 1926 Now'),
                onPressed: () => _call('1926'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () {
                  onAction('dismissed_safe');
                  onDismissed();
                  Navigator.pop(context);
                },
                child: const Text('I am safe right now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpLineTile extends StatelessWidget {
  const _HelpLineTile({
    required this.title,
    required this.subtitle,
    required this.onCall,
  });

  final String title;
  final String subtitle;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.support_agent)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: 'Call',
        icon: const Icon(Icons.call),
        onPressed: onCall,
      ),
    );
  }
}
