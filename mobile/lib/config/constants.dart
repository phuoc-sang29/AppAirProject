import 'package:flutter/foundation.dart';

class AppConstants {
  static const String supabaseUrl = 'https://veauosznuyqjvoepnopc.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_EsNQpCfL_ZqShwMpagRN-g_BvrQKQ2o';

  static String get aiServiceUrl =>
      kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';

  static String get backendUrl =>
      kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';

  static const double anchorLat = 10.9807;
  static const double anchorLon = 106.6753;
  static const double serviceRadiusKm = 20.0;

  static const List<String> healthGroups = [
    'binh_thuong',
    'benh_ho_hap',
    'tre_em',
    'van_dong',
  ];

  static const Map<String, String> healthGroupLabels = {
    'binh_thuong': 'Sức khỏe bình thường',
    'benh_ho_hap': 'Bệnh hô hấp & Hen suyễn',
    'hen_suyen': 'Bệnh hô hấp & Hen suyễn',
    'tre_em': 'Trẻ em & Người cao tuổi',
    'van_dong': 'Vận động ngoài trời',
  };

  static const Map<String, String> healthGroupDescriptions = {
    'binh_thuong': 'Sinh hoạt và làm việc thông thường trong nhà, văn phòng',
    'benh_ho_hap': 'Hen suyễn, viêm mũi dị ứng, viêm xoang, phổi hoặc tim mạch',
    'tre_em': 'Hệ hô hấp nhạy cảm theo độ tuổi, cần cảnh báo sớm từ 15 ug/m3',
    'van_dong': 'Chạy bộ, tập thể thao hoặc làm việc, di chuyển nhiều trên đường',
  };

  static String normalizeHealthGroup(String? raw) {
    if (raw == null || raw.isEmpty) return 'binh_thuong';
    if (raw == 'hen_suyen') return 'benh_ho_hap';
    if (healthGroups.contains(raw)) return raw;
    return 'binh_thuong';
  }
}
