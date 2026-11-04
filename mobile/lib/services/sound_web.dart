import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:html' as html;

final Map<String, String> _cachedDataUris = {};

String _buildWavDataUri(List<(double, double, double)> notes) {
  const int sampleRate = 22050;
  final samples = <int>[];
  for (final n in notes) {
    final freq = n.$1;
    final dur = n.$2;
    final vol = n.$3;
    final count = (sampleRate * dur).toInt();
    for (int i = 0; i < count; i++) {
      final t = i / sampleRate;
      final attack = math.min(1.0, i / (sampleRate * 0.008));
      final decay = math.exp(-5.0 * t / dur);
      final env = attack * decay;
      final waveVal = vol *
          env *
          (0.75 * math.sin(2 * math.pi * freq * t) +
              0.25 * math.sin(2 * math.pi * (freq * 2) * t));
      final pcm = (waveVal * 32767).round().clamp(-32767, 32767);
      samples.add(pcm);
    }
  }

  final dataSize = samples.length * 2;
  final totalSize = 36 + dataSize;
  final bytes = ByteData(44 + dataSize);

  void writeStr(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  bytes.setUint32(4, totalSize, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < samples.length; i++) {
    bytes.setInt16(44 + i * 2, samples[i], Endian.little);
  }

  final b64 = base64Encode(bytes.buffer.asUint8List());
  return 'data:audio/wav;base64,$b64';
}

Future<void> playTonePlatform(String soundKey) async {
  if (soundKey == 'silent') return;
  try {
    String? uri = _cachedDataUris[soundKey];
    if (uri == null) {
      if (soundKey == 'chime_breeze') {
        uri = _buildWavDataUri([
          (587.33, 0.11, 0.38),
          (739.99, 0.11, 0.40),
          (880.00, 0.11, 0.42),
          (1174.66, 0.30, 0.45),
        ]);
      } else if (soundKey == 'crystal_drop') {
        uri = _buildWavDataUri([
          (1046.50, 0.10, 0.40),
          (1567.98, 0.32, 0.45),
        ]);
      } else {
        uri = _buildWavDataUri([
          (880.00, 0.13, 0.42),
          (1318.50, 0.32, 0.48),
        ]);
      }
      _cachedDataUris[soundKey] = uri;
    }
    final audio = html.AudioElement(uri);
    audio.volume = 0.65;
    await audio.play();
  } catch (_) {}
}

Future<void> requestWebNotifPermissionPlatform() async {
  try {
    if (html.Notification.supported &&
        html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  } catch (_) {}
}

Future<void> showWebOsNotificationPlatform(String title, String body) async {
  try {
    if (!html.Notification.supported) return;
    if (html.Notification.permission != 'granted') {
      final perm = await html.Notification.requestPermission();
      if (perm != 'granted') return;
    }
    html.Notification(title, body: body);
  } catch (_) {}
}
