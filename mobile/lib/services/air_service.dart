import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/constants.dart';

class AirService {
  final _db = Supabase.instance.client;

  void _log(String label, Stopwatch sw) {
    debugPrint('[AirService] $label: ${sw.elapsedMilliseconds}ms');
  }

  Future<Map<String, dynamic>?> getCurrent() async {
    final sw = Stopwatch()..start();

    final aiF = http
        .get(Uri.parse('${AppConstants.aiServiceUrl}/current'))
        .timeout(const Duration(seconds: 3))
        .then((r) => r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic>? : null)
        .catchError((_) => null);

    final dbF = _db
        .from('air_quality')
        .select()
        .order('recorded_at', ascending: false)
        .limit(1)
        .then((rows) => rows.isNotEmpty ? rows.first as Map<String, dynamic>? : null)
        .catchError((_) => null);

    final results = await Future.wait([aiF, dbF]);
    final aiResult = results[0];
    final dbResult = results[1];

    final chosen = aiResult ?? dbResult;
    final source = aiResult != null ? 'AI' : 'Supabase';
    _log('getCurrent ($source)', sw);
    return chosen;
  }

  Future<Map<String, dynamic>?> getForecast() async {
    final sw = Stopwatch()..start();
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.aiServiceUrl}/predict'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        _log('getForecast (AI)', sw);
        return jsonDecode(res.body);
      }
    } catch (_) {}
    _log('getForecast (no data)', sw);
    return null;
  }

  Future<Map<String, dynamic>?> getMetrics() async {
    final sw = Stopwatch()..start();
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.aiServiceUrl}/metrics'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        _log('getMetrics (AI)', sw);
        return jsonDecode(res.body);
      }
    } catch (_) {}
    _log('getMetrics (no data)', sw);
    return null;
  }

  Future<Map<String, dynamic>?> syncAirData() async {
    final sw = Stopwatch()..start();
    try {
      final res = await http
          .post(Uri.parse('${AppConstants.aiServiceUrl}/sync'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        _log('syncAirData (OK)', sw);
        return jsonDecode(res.body) as Map<String, dynamic>?;
      }
    } catch (_) {}
    _log('syncAirData (failed)', sw);
    return null;
  }

  Future<Map<String, dynamic>?> getAiNewsDraft({String angle = 'auto'}) async {
    try {
      final res = await http
          .get(Uri.parse('${AppConstants.aiServiceUrl}/news/draft?angle=$angle'))
          .timeout(const Duration(seconds: 22));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getHistory({int hours = 48}) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _db
          .from('air_quality')
          .select('recorded_at, pm2_5, pm10')
          .order('recorded_at', ascending: false)
          .limit(hours);
      _log('getHistory (${rows.length} rows)', sw);
      return List<Map<String, dynamic>>.from(rows.reversed);
    } catch (_) {
      _log('getHistory (error)', sw);
      return [];
    }
  }

  Future<Map<String, dynamic>?> checkNotify(double pm25, String group) async {
    try {
      final res = await http
          .post(
            Uri.parse('${AppConstants.aiServiceUrl}/notify/check'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pm2_5': pm25, 'health_group': group}),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  String getAqiLevel(double pm25) {
    if (pm25 <= 15) return 'tot';
    if (pm25 <= 25) return 'trung_binh';
    if (pm25 <= 50) return 'kem';
    return 'xau';
  }

  String getAqiLabel(double pm25) {
    if (pm25 <= 15) return 'Tốt';
    if (pm25 <= 25) return 'Trung bình';
    if (pm25 <= 50) return 'Kém';
    return 'Xấu';
  }

  String getAqiAdvice(double pm25) {
    if (pm25 <= 15) return 'Chất lượng không khí tốt. Thích hợp mọi hoạt động ngoài trời.';
    if (pm25 <= 25) return 'Chất lượng không khí trung bình. Người nhạy cảm nên hạn chế ra ngoài lâu.';
    if (pm25 <= 50) return 'Chất lượng không khí kém. Hạn chế hoạt động ngoài trời kéo dài.';
    return 'Chất lượng không khí xấu. Không nên ra ngoài, đeo khẩu trang nếu cần thiết.';
  }
}
