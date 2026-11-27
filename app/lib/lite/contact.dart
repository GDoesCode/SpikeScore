import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../edition.dart';

/// Opens the email app with a message to [Edition.contactEmail]. If there is
/// no address yet, or no email app, the message is copied instead so it can
/// be pasted anywhere.
Future<void> sendToSpikeScore(
  BuildContext context, {
  required String subject,
  required String body,
}) async {
  if (Edition.contactEmail.isNotEmpty) {
    final uri = Uri(
      scheme: 'mailto',
      path: Edition.contactEmail,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // No email app: fall through and copy instead.
    }
  }
  await Clipboard.setData(ClipboardData(text: '$subject\n\n$body'));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied. Paste it into an email or message to us.')),
    );
  }
}
