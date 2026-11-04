import 'sound_stub.dart' if (dart.library.html) 'sound_web.dart';

class SoundPlayer {
  static Future<void> play(String soundKey) => playTonePlatform(soundKey);
  static Future<void> requestWebPermission() =>
      requestWebNotifPermissionPlatform();
  static Future<void> showWebNotification(String title, String body) =>
      showWebOsNotificationPlatform(title, body);
}
