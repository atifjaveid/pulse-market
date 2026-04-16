// lib/widgets/fcm_token_debug.dart
//
// Debug-only widget: shows the FCM token and lets you copy it.
// Use it in your DebugOverlay or any dev screen.
// Remove or gate behind kDebugMode before shipping.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_services.dart';

class FcmTokenDebugTile extends StatefulWidget {
  const FcmTokenDebugTile({super.key});

  @override
  State<FcmTokenDebugTile> createState() => _FcmTokenDebugTileState();
}

class _FcmTokenDebugTileState extends State<FcmTokenDebugTile> {
  String? _token;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    NotificationService.getToken().then((t) {
      if (mounted) setState(() => _token = t);
    });
  }

  Future<void> _copy() async {
    if (_token == null) return;
    await Clipboard.setData(ClipboardData(text: _token!));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FCM Token',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white54)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _token ?? 'Loading…',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _copy,
              child: Icon(
                _copied ? Icons.check_circle_outline : Icons.copy_rounded,
                size: 18,
                color: _copied ? Colors.greenAccent : Colors.white54,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
