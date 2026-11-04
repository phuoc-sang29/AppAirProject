import 'package:flutter/services.dart';

Future<void> playTonePlatform(String soundKey) async {
  if (soundKey == 'silent') return;
  try {
    await SystemSound.play(SystemSoundType.click);
    if (soundKey == 'chime_breeze') {
      await Future.delayed(const Duration(milliseconds: 110));
      await SystemSound.play(SystemSoundType.click);
    } else if (soundKey == 'crystal_drop') {
      await HapticFeedback.lightImpact();
    }
  } catch (_) {}
}

Future<void> requestWebNotifPermissionPlatform() async {}

Future<void> showWebOsNotificationPlatform(String title, String body) async {}
