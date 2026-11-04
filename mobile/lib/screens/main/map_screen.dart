import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/location_service.dart';
import '../../services/air_service.dart';

class StationNode {
  final String id;
  final String name;
  final String zoneType;
  final LatLng pos;
  final double trafficFactor;
  final double industrialFactor;
  final double greenFactor;
  Map<String, double> values;

  StationNode({
    required this.id,
    required this.name,
    required this.zoneType,
    required this.pos,
    required this.trafficFactor,
    required this.industrialFactor,
    required this.greenFactor,
    Map<String, double>? values,
  }) : values = values ??
            {
              'pm2_5': 0,
              'pm10': 0,
              'no2': 0,
              'co': 0,
              'so2': 0,
              'o3': 0,
            };
}

class GazetteerEntry {
  final String name;
  final String subtitle;
  final LatLng pos;
  final List<String> keywords;

  const GazetteerEntry({
    required this.name,
    required this.subtitle,
    required this.pos,
    required this.keywords,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  final LocationService _locSvc = LocationService();
  final AirService _airSvc = AirService();
  final TextEditingController _searchCtrl = TextEditingController();

  Position? _userPos;
  bool _inArea = true;
  bool _isLoading = true;
  bool _searchLoading = false;
  int _dbLatencyMs = 0;
  double _currentZoom = 12.6;
  StreamSubscription<Position>? _locationSub;

  String _mapStyle = 'dark';
  String _selectedPollutant = 'pm2_5';
  StationNode? _selectedStation;
  List<GazetteerEntry> _suggestions = [];

  Map<String, double> _anchorMetrics = {
    'pm2_5': 25.0,
    'pm10': 42.0,
    'no2': 18.0,
    'co': 320.0,
    'so2': 8.0,
    'o3': 45.0,
  };

  List<CircleMarker> _cachedCircles = [];
  List<Marker> _cachedMarkers = [];
  List<StationNode> _rankedStations = [];

  static const LatLng _anchor = LatLng(AppConstants.anchorLat, AppConstants.anchorLon);

  static const Map<String, Map<String, dynamic>> _pollutantMeta = {
    'pm2_5': {
      'label': 'PM2.5',
      'name': 'Bụi siêu mịn PM2.5',
      'unit': 'ug/m3',
      'good': 15.0,
      'mod': 25.0,
      'poor': 50.0,
    },
    'pm10': {
      'label': 'PM10',
      'name': 'Bụi mịn PM10',
      'unit': 'ug/m3',
      'good': 30.0,
      'mod': 50.0,
      'poor': 100.0,
    },
    'no2': {
      'label': 'NO2',
      'name': 'Khí giao thông NO2',
      'unit': 'ug/m3',
      'good': 20.0,
      'mod': 40.0,
      'poor': 80.0,
    },
    'co': {
      'label': 'CO',
      'name': 'Khí Carbon Monoxide',
      'unit': 'ug/m3',
      'good': 300.0,
      'mod': 600.0,
      'poor': 1200.0,
    },
    'so2': {
      'label': 'SO2',
      'name': 'Khí công nghiệp SO2',
      'unit': 'ug/m3',
      'good': 15.0,
      'mod': 35.0,
      'poor': 75.0,
    },
    'o3': {
      'label': 'O3',
      'name': 'Khí Ozone tầng mặt đất',
      'unit': 'ug/m3',
      'good': 50.0,
      'mod': 80.0,
      'poor': 120.0,
    },
  };

  final List<StationNode> _stations = [
    StationNode(
      id: 'phu_cuong',
      name: 'Phú Cường',
      zoneType: 'Trung tâm hành chính & thương mại Thủ Dầu Một',
      pos: const LatLng(10.9804, 106.6545),
      trafficFactor: 1.04,
      industrialFactor: 0.96,
      greenFactor: 0.98,
    ),
    StationNode(
      id: 'chanh_nghia',
      name: 'Chánh Nghĩa',
      zoneType: 'Khu đô thị & dịch vụ sầm uất',
      pos: const LatLng(10.9675, 106.6665),
      trafficFactor: 1.08,
      industrialFactor: 0.98,
      greenFactor: 0.96,
    ),
    StationNode(
      id: 'phu_loi',
      name: 'Phú Lợi',
      zoneType: 'Trục đường Huỳnh Văn Lũy - Phú Lợi',
      pos: const LatLng(10.9935, 106.6805),
      trafficFactor: 1.14,
      industrialFactor: 1.08,
      greenFactor: 0.92,
    ),
    StationNode(
      id: 'phu_hoa',
      name: 'Phú Hòa',
      zoneType: 'Khu Đại học Thủ Dầu Một & Đại lộ Bình Dương',
      pos: const LatLng(10.9740, 106.6895),
      trafficFactor: 1.10,
      industrialFactor: 1.12,
      greenFactor: 0.94,
    ),
    StationNode(
      id: 'hiep_thanh',
      name: 'Hiệp Thành',
      zoneType: 'Khu dân cư mật độ cao & Bệnh viện Tỉnh',
      pos: const LatLng(10.9970, 106.6585),
      trafficFactor: 1.02,
      industrialFactor: 0.95,
      greenFactor: 1.00,
    ),
    StationNode(
      id: 'hiep_an',
      name: 'Hiệp An',
      zoneType: 'Cửa ngõ phía Bắc Thủ Dầu Một',
      pos: const LatLng(11.0190, 106.6475),
      trafficFactor: 0.94,
      industrialFactor: 0.92,
      greenFactor: 1.06,
    ),
    StationNode(
      id: 'tan_an',
      name: 'Tân An',
      zoneType: 'Vùng sinh thái ven sông Sài Gòn',
      pos: const LatLng(11.0035, 106.6265),
      trafficFactor: 0.82,
      industrialFactor: 0.80,
      greenFactor: 1.18,
    ),
    StationNode(
      id: 'chanh_my',
      name: 'Chánh Mỹ',
      zoneType: 'Bán đảo cây xanh ven sông Sài Gòn',
      pos: const LatLng(10.9545, 106.6380),
      trafficFactor: 0.78,
      industrialFactor: 0.76,
      greenFactor: 1.22,
    ),
    StationNode(
      id: 'dinh_hoa',
      name: 'Định Hòa',
      zoneType: 'Trục giao thông Mỹ Phước Tân Vạn',
      pos: const LatLng(11.0285, 106.6695),
      trafficFactor: 1.06,
      industrialFactor: 1.04,
      greenFactor: 0.97,
    ),
    StationNode(
      id: 'hoa_phu',
      name: 'Hòa Phú',
      zoneType: 'Trung tâm Thành phố Mới Bình Dương',
      pos: const LatLng(11.0520, 106.6825),
      trafficFactor: 0.96,
      industrialFactor: 1.05,
      greenFactor: 1.04,
    ),
  ];

  static const List<GazetteerEntry> _gazetteer = [
    GazetteerEntry(
      name: 'Đường Huỳnh Văn Lũy (P. Phú Lợi)',
      subtitle: 'Tuyến đường chính qua Phường Phú Lợi, TP. Thủ Dầu Một',
      pos: LatLng(10.9912, 106.6788),
      keywords: ['huynh van luy', 'phu loi', 'phuong phu loi', 'duong huynh van luy'],
    ),
    GazetteerEntry(
      name: 'Đường Huỳnh Văn Lũy (P. Phú Mỹ)',
      subtitle: 'Đoạn qua Phường Phú Mỹ, TP. Thủ Dầu Một',
      pos: LatLng(11.0125, 106.6815),
      keywords: ['huynh van luy', 'phu my', 'phuong phu my'],
    ),
    GazetteerEntry(
      name: 'Đường Huỳnh Văn Lũy (P. Hòa Phú)',
      subtitle: 'Đoạn cửa ngõ Thành phố Mới Bình Dương',
      pos: LatLng(11.0415, 106.6830),
      keywords: ['huynh van luy', 'hoa phu', 'thanh pho moi'],
    ),
    GazetteerEntry(
      name: 'Đường Phú Lợi (P. Phú Lợi)',
      subtitle: 'Trục giao thông ĐT743 kết nối Phú Lợi - Mỹ Phước',
      pos: LatLng(10.9895, 106.6840),
      keywords: ['duong phu loi', 'phu loi', 'dt743', 'phuong phu loi'],
    ),
    GazetteerEntry(
      name: 'Đại lộ Bình Dương (P. Phú Hòa)',
      subtitle: 'Trục Quốc lộ 13 đoạn trung tâm Phú Hòa - Chánh Nghĩa',
      pos: LatLng(10.9768, 106.6745),
      keywords: ['dai lo binh duong', 'quoc lo 13', 'ql13', 'phu hoa', 'chanh nghia'],
    ),
    GazetteerEntry(
      name: 'Đại lộ Bình Dương (P. Hiệp Thành)',
      subtitle: 'Trục Quốc lộ 13 đoạn Ngã tư Chợ Cây Dừa - Hiệp Thành',
      pos: LatLng(10.9945, 106.6648),
      keywords: ['dai lo binh duong', 'quoc lo 13', 'hiep thanh', 'cho cay dua'],
    ),
    GazetteerEntry(
      name: 'Đường 30 Tháng 4 (P. Phú Hòa)',
      subtitle: 'Tuyến phố thương mại - dịch vụ trung tâm Thủ Dầu Một',
      pos: LatLng(10.9735, 106.6725),
      keywords: ['duong 30 thang 4', '30/4', '30 thang 4', 'phu hoa', 'chanh nghia'],
    ),
    GazetteerEntry(
      name: 'Đường Yersin (P. Hiệp Thành - Phú Cường)',
      subtitle: 'Trục kết nối Vòng xoay Ngã Sáu đến Đại lộ Bình Dương',
      pos: LatLng(10.9852, 106.6675),
      keywords: ['duong yersin', 'yersin', 'hiep thanh', 'phu cuong', 'phu loi'],
    ),
    GazetteerEntry(
      name: 'Đường Cách Mạng Tháng Tám (P. Phú Cường)',
      subtitle: 'Trục đường ven sông Sài Gòn - Chánh Mỹ - Phú Cường - Phú Thọ',
      pos: LatLng(10.9825, 106.6535),
      keywords: ['cach mang thang tam', 'cmt8', 'phu cuong', 'phu tho', 'chanh nghia'],
    ),
    GazetteerEntry(
      name: 'Đường Lê Hồng Phong (P. Phú Lợi - Phú Hòa)',
      subtitle: 'Tuyến đường kết nối khu dân cư Phú Lợi và Phú Hòa',
      pos: LatLng(10.9810, 106.6810),
      keywords: ['le hong phong', 'duong le hong phong', 'phu loi', 'phu hoa', 'phu tho'],
    ),
    GazetteerEntry(
      name: 'Đường Phạm Ngọc Thạch (P. Hiệp Thành)',
      subtitle: 'Đại lộ nối Quốc lộ 13 với Trung tâm Hành chính Tỉnh Bình Dương',
      pos: LatLng(11.0045, 106.6690),
      keywords: ['pham ngoc thach', 'duong pham ngoc thach', 'hiep thanh', 'phu my'],
    ),
    GazetteerEntry(
      name: 'Đường Nguyễn Chí Thanh (P. Hiệp An - Tân An)',
      subtitle: 'Tuyến đường qua Phường Hiệp An và Phường Tân An',
      pos: LatLng(11.0095, 106.6440),
      keywords: ['nguyen chi thanh', 'duong nguyen chi thanh', 'hiep an', 'tan an', 'tuong binh hiep'],
    ),
    GazetteerEntry(
      name: 'Đường Mỹ Phước Tân Vạn (P. Phú Lợi - Phú Mỹ)',
      subtitle: 'Tuyến cao tốc vận tải công nghiệp qua Thủ Dầu Một',
      pos: LatLng(11.0040, 106.6935),
      keywords: ['my phuoc tan van', 'duong my phuoc tan van', 'phu loi', 'phu my', 'dinh hoa'],
    ),
    GazetteerEntry(
      name: 'Đường Võ Văn Kiệt (P. Hòa Phú)',
      subtitle: 'Trục đường lớn tại Khu đô thị Thành phố Mới Bình Dương',
      pos: LatLng(11.0460, 106.6765),
      keywords: ['vo van kiet', 'duong vo van kiet', 'hoa phu', 'phu tan'],
    ),
    GazetteerEntry(
      name: 'Đường Hùng Vương (Thành phố Mới Bình Dương)',
      subtitle: 'Đại lộ Trung tâm Hành chính Tỉnh Bình Dương, P. Hòa Phú',
      pos: LatLng(11.0505, 106.6845),
      keywords: ['hung vuong', 'duong hung vuong', 'hoa phu', 'thanh pho moi', 'trung tam hanh chinh'],
    ),
    GazetteerEntry(
      name: 'Phố đi bộ Bạch Đằng (P. Phú Cường)',
      subtitle: 'Công viên và phố đi bộ ven sông Sài Gòn, Thủ Dầu Một',
      pos: LatLng(10.9788, 106.6502),
      keywords: ['bach dang', 'pho di bo bach dang', 'duong bach dang', 'phu cuong', 'song sai gon'],
    ),
    GazetteerEntry(
      name: 'Đường Trần Văn Ơn - Đại học Thủ Dầu Một (P. Phú Hòa)',
      subtitle: 'Khu vực trường Đại học Thủ Dầu Một, Phường Phú Hòa',
      pos: LatLng(10.9806, 106.6745),
      keywords: ['tran van on', 'dai hoc thu dau mot', 'tdmu', 'phu hoa'],
    ),
    GazetteerEntry(
      name: 'Chợ Thủ Dầu Một - Ngã Sáu (P. Phú Cường)',
      subtitle: 'Trung tâm thương mại truyền thống Phường Phú Cường',
      pos: LatLng(10.9802, 106.6522),
      keywords: ['cho thu dau mot', 'nga sau', 'chua ba', 'phu cuong'],
    ),
    GazetteerEntry(
      name: 'Bệnh viện Đa khoa Tỉnh Bình Dương (P. Hiệp Thành)',
      subtitle: 'Số 5 Phạm Ngọc Thạch, Phường Hiệp Thành, Thủ Dầu Một',
      pos: LatLng(11.0022, 106.6625),
      keywords: ['benh vien da khoa', 'benh vien tinh binh duong', 'hiep thanh'],
    ),
    GazetteerEntry(
      name: 'Sân vận động Gò Đậu (P. Chánh Nghĩa)',
      subtitle: 'Đường 30/4 giao Đại lộ Bình Dương, Phường Chánh Nghĩa',
      pos: LatLng(10.9708, 106.6705),
      keywords: ['san van dong go dau', 'go dau', 'chanh nghia', 'becamex'],
    ),
    GazetteerEntry(
      name: 'Phường Phú Thọ, TP. Thủ Dầu Một',
      subtitle: 'Khu dân cư phía Nam Thủ Dầu Một giáp Thuận An',
      pos: LatLng(10.9615, 106.6740),
      keywords: ['phu tho', 'phuong phu tho'],
    ),
    GazetteerEntry(
      name: 'Phường Phú Mỹ, TP. Thủ Dầu Một',
      subtitle: 'Khu vực giao giữa Huỳnh Văn Lũy và Mỹ Phước Tân Vạn',
      pos: LatLng(11.0130, 106.6820),
      keywords: ['phu my', 'phuong phu my'],
    ),
    GazetteerEntry(
      name: 'Phường Phú Tân, TP. Thủ Dầu Một',
      subtitle: 'Khu công nghiệp - đô thị phía Đông Bắc Thủ Dầu Một',
      pos: LatLng(11.0365, 106.7010),
      keywords: ['phu tan', 'phuong phu tan', 'kcn song than 3', 'kcn kim huy'],
    ),
    GazetteerEntry(
      name: 'Phường Tương Bình Hiệp, TP. Thủ Dầu Một',
      subtitle: 'Làng nghề sơn mài truyền thống ven sông Sài Gòn',
      pos: LatLng(11.0065, 106.6395),
      keywords: ['tuong binh hiep', 'phuong tuong binh hiep'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initLocationAndData();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalizeVi(String input) {
    var s = input.toLowerCase().trim();
    const map = {
      'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a',
      'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
      'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i',
      'ò': 'o', 'ó': 'o', 'ọ': 'o', 'ỏ': 'o', 'õ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o', 'ổ': 'o', 'ỗ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o', 'ỡ': 'o',
      'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
      'đ': 'd',
    };
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      sb.write(map[ch] ?? ch);
    }
    return sb
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<GazetteerEntry> _findLocalMatches(String rawQuery) {
    final norm = _normalizeVi(rawQuery);
    if (norm.isEmpty) return [];

    const stopWords = {'phuong', 'duong', 'tp', 'thanh', 'pho', 'tinh', 'khu', 'so'};
    final tokens = norm
        .split(' ')
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .toList();
    if (tokens.isEmpty) return [];

    final allEntries = <GazetteerEntry>[
      ..._gazetteer,
      ..._stations.map(
        (st) => GazetteerEntry(
          name: 'Phường ${st.name}, TP. Thủ Dầu Một',
          subtitle: st.zoneType,
          pos: st.pos,
          keywords: [_normalizeVi(st.name), 'phuong ${_normalizeVi(st.name)}'],
        ),
      ),
    ];

    final scored = <(GazetteerEntry, int)>[];
    for (final entry in allEntries) {
      final haystack = _normalizeVi('${entry.name} ${entry.subtitle} ${entry.keywords.join(' ')}');
      int score = 0;
      if (haystack.contains(norm)) {
        score += 50;
      }
      for (final kw in entry.keywords) {
        final nKw = _normalizeVi(kw);
        if (norm.contains(nKw) || nKw.contains(norm)) {
          score += 25;
        }
      }
      int matchedTokens = 0;
      for (final tk in tokens) {
        if (haystack.contains(tk)) {
          matchedTokens++;
          score += 10;
        }
      }
      if (matchedTokens == tokens.length) {
        score += 35;
      }
      if (score >= 20) {
        scored.add((entry, score));
      }
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(5).map((e) => e.$1).toList();
  }

  void _onSearchTextChanged(String val) {
    if (val.trim().length < 2) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }
    final matches = _findLocalMatches(val);
    setState(() => _suggestions = matches);
  }

  void _selectGazetteerEntry(GazetteerEntry entry) {
    FocusScope.of(context).unfocus();
    _searchCtrl.text = entry.name;
    setState(() => _suggestions = []);

    for (final st in _stations) {
      const distCalc = Distance();
      final dMeters = distCalc.as(LengthUnit.Meter, st.pos, entry.pos);
      if (dMeters < 220 && entry.name.startsWith('Phường ${st.name}')) {
        _selectStation(st, moveCamera: true);
        _logSearch(st.name, st.pos.latitude, st.pos.longitude, st.values['pm2_5'] ?? 0);
        return;
      }
    }

    final interp = _interpolateAtPoint(entry.pos);
    final node = StationNode(
      id: 'searched_point',
      name: entry.name,
      zoneType: '${entry.subtitle} (Nội suy từ Database AppAir)',
      pos: entry.pos,
      trafficFactor: 1.0,
      industrialFactor: 1.0,
      greenFactor: 1.0,
      values: interp,
    );
    setState(() {
      _selectedStation = node;
      _rebuildMapLayers();
    });
    _mapCtrl.move(entry.pos, 14.2);
    _logSearch(entry.name, entry.pos.latitude, entry.pos.longitude, interp['pm2_5'] ?? 0);
  }

  Future<void> _initLocationAndData() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied && mounted) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
    await _loadFromDatabase();
    _startLocationStream();
  }

  void _startLocationStream() {
    _locationSub?.cancel();
    try {
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 25,
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _userPos = pos;
            _inArea = _locSvc.isInServiceArea(pos.latitude, pos.longitude);
            _rebuildMapLayers();
          });
        }
      });
    } catch (_) {}
  }

  Future<void> _loadFromDatabase() async {
    setState(() => _isLoading = true);
    final sw = Stopwatch()..start();

    final posF = _locSvc.getCurrentPosition();
    final dbDataF = _airSvc.getCurrent();
    final res = await Future.wait([posF, dbDataF]);

    final pos = res[0] as Position?;
    final dbRow = res[1] as Map<String, dynamic>?;
    sw.stop();

    final basePm25 = (dbRow?['pm2_5'] as num?)?.toDouble() ?? 26.5;
    final basePm10 = (dbRow?['pm10'] as num?)?.toDouble() ?? (basePm25 * 1.45);
    final baseCo = (dbRow?['carbon_monoxide'] as num?)?.toDouble() ?? 310.0;
    final baseNo2 = (dbRow?['nitrogen_dioxide'] as num?)?.toDouble() ?? 16.5;
    final baseSo2 = (dbRow?['sulphur_dioxide'] as num?)?.toDouble() ?? 7.8;
    final baseO3 = (dbRow?['ozone'] as num?)?.toDouble() ?? 48.0;

    _anchorMetrics = {
      'pm2_5': basePm25,
      'pm10': basePm10,
      'co': baseCo,
      'no2': baseNo2,
      'so2': baseSo2,
      'o3': baseO3,
    };

    _runUnifiedSpatialAlgorithm();

    if (mounted) {
      setState(() {
        _userPos = pos;
        _dbLatencyMs = sw.elapsedMilliseconds;
        if (pos != null) {
          _inArea = _locSvc.isInServiceArea(pos.latitude, pos.longitude);
        }
        _rebuildMapLayers();
        _isLoading = false;
      });
    }
  }

  void _runUnifiedSpatialAlgorithm() {
    final basePm25 = _anchorMetrics['pm2_5']!;
    final basePm10 = _anchorMetrics['pm10']!;
    final baseCo = _anchorMetrics['co']!;
    final baseNo2 = _anchorMetrics['no2']!;
    final baseSo2 = _anchorMetrics['so2']!;
    final baseO3 = _anchorMetrics['o3']!;

    for (final s in _stations) {
      final compositePm =
          (s.trafficFactor * 0.55 + s.industrialFactor * 0.45) / s.greenFactor;
      s.values = {
        'pm2_5': (basePm25 * compositePm).clamp(3.0, 250.0),
        'pm10': (basePm10 * ((s.trafficFactor * 0.45 + s.industrialFactor * 0.55) / s.greenFactor))
            .clamp(5.0, 350.0),
        'no2': (baseNo2 * (s.trafficFactor / s.greenFactor)).clamp(1.0, 200.0),
        'co': (baseCo * (s.trafficFactor / math.sqrt(s.greenFactor))).clamp(50.0, 3000.0),
        'so2': (baseSo2 * (s.industrialFactor / s.greenFactor)).clamp(0.5, 150.0),
        'o3': (baseO3 * (1.0 / s.trafficFactor) * math.sqrt(s.greenFactor))
            .clamp(5.0, 180.0),
      };
    }

    _rankedStations = List<StationNode>.from(_stations)
      ..sort((a, b) => (a.values[_selectedPollutant] ?? 0)
          .compareTo(b.values[_selectedPollutant] ?? 0));
  }

  Map<String, double> _interpolateAtPoint(LatLng pt) {
    const distCalc = Distance();
    final result = <String, double>{};
    for (final key in _pollutantMeta.keys) {
      double numSum = 0;
      double weightSum = 0;
      for (final s in _stations) {
        final dKm = distCalc.as(LengthUnit.Meter, pt, s.pos) / 1000.0;
        final w = 1.0 / math.pow(math.max(dKm, 0.15), 2);
        numSum += (s.values[key] ?? 0) * w;
        weightSum += w;
      }
      result[key] = weightSum > 0 ? numSum / weightSum : (_anchorMetrics[key] ?? 0);
    }
    return result;
  }

  String _findNearestAreaLabel(LatLng pt) {
    const distCalc = Distance();
    StationNode? nearestStation;
    double minKm = 9999.0;
    for (final s in _stations) {
      final dKm = distCalc.as(LengthUnit.Meter, pt, s.pos) / 1000.0;
      if (dKm < minKm) {
        minKm = dKm;
        nearestStation = s;
      }
    }
    if (nearestStation != null && minKm <= 3.5) {
      return 'Điểm chọn gần P. ${nearestStation.name}';
    }
    return 'Điểm chọn Thủ Dầu Một (${pt.latitude.toStringAsFixed(3)}, ${pt.longitude.toStringAsFixed(3)})';
  }

  void _rebuildMapLayers() {
    _rankedStations = List<StationNode>.from(_stations)
      ..sort((a, b) => (a.values[_selectedPollutant] ?? 0)
          .compareTo(b.values[_selectedPollutant] ?? 0));

    final circles = <CircleMarker>[
      CircleMarker(
        point: _anchor,
        radius: AppConstants.serviceRadiusKm * 1000.0,
        useRadiusInMeter: true,
        color: AppTheme.primary.withValues(alpha: 0.025),
        borderColor: AppTheme.primary.withValues(alpha: 0.45),
        borderStrokeWidth: 1.6,
      ),
    ];

    for (final s in _stations) {
      final val = s.values[_selectedPollutant] ?? 0;
      final col = _pollutantColor(_selectedPollutant, val);
      final isSel = _selectedStation?.id == s.id;
      final radii = isSel ? [1450.0, 950.0, 520.0] : [1150.0, 750.0, 380.0];
      final alphas = isSel ? [0.14, 0.24, 0.36] : [0.08, 0.15, 0.25];

      for (int i = 0; i < 3; i++) {
        circles.add(
          CircleMarker(
            point: s.pos,
            radius: radii[i],
            useRadiusInMeter: true,
            color: col.withValues(alpha: alphas[i]),
            borderColor: i == 0
                ? col.withValues(alpha: isSel ? 0.75 : 0.35)
                : Colors.transparent,
            borderStrokeWidth: isSel ? 2.0 : 1.0,
          ),
        );
      }
    }

    if (_selectedStation != null &&
        !_stations.any((s) => s.id == _selectedStation!.id)) {
      final val = _selectedStation!.values[_selectedPollutant] ?? 0;
      final col = _pollutantColor(_selectedPollutant, val);
      circles.add(
        CircleMarker(
          point: _selectedStation!.pos,
          radius: 950,
          useRadiusInMeter: true,
          color: col.withValues(alpha: 0.22),
          borderColor: Colors.white,
          borderStrokeWidth: 2,
        ),
      );
    }

    final markers = <Marker>[];
    for (int idx = 0; idx < _stations.length; idx++) {
      markers.add(_buildStationMarker(_stations[idx], index: idx));
    }

    if (_selectedStation != null &&
        !_stations.any((s) => s.id == _selectedStation!.id)) {
      markers.add(_buildStationMarker(_selectedStation!, isCustomPin: true, index: 0));
    }

    if (_userPos != null) {
      markers.add(
        Marker(
          point: LatLng(_userPos!.latitude, _userPos!.longitude),
          width: 48,
          height: 48,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    _cachedCircles = circles;
    _cachedMarkers = markers;
  }

  Color _pollutantColor(String key, double val) {
    final m = _pollutantMeta[key] ?? _pollutantMeta['pm2_5']!;
    final good = (m['good'] as num).toDouble();
    final mod = (m['mod'] as num).toDouble();
    final poor = (m['poor'] as num).toDouble();
    if (val <= good) return AppTheme.good;
    if (val <= mod) return AppTheme.moderate;
    if (val <= poor) return AppTheme.poor;
    return AppTheme.bad;
  }

  String _pollutantStatusLabel(String key, double val) {
    final m = _pollutantMeta[key] ?? _pollutantMeta['pm2_5']!;
    final good = (m['good'] as num).toDouble();
    final mod = (m['mod'] as num).toDouble();
    final poor = (m['poor'] as num).toDouble();
    if (val <= good) return 'Tốt';
    if (val <= mod) return 'Trung bình';
    if (val <= poor) return 'Kém';
    return 'Xấu';
  }

  Marker _buildStationMarker(StationNode s, {bool isCustomPin = false, int index = 0}) {
    final val = s.values[_selectedPollutant] ?? 0;
    final col = _pollutantColor(_selectedPollutant, val);
    final selected = _selectedStation?.id == s.id;
    final valText = _selectedPollutant == 'co'
        ? val.toStringAsFixed(0)
        : val.toStringAsFixed(1);

    final bool showNameLabel = selected ||
        isCustomPin ||
        _currentZoom >= 12.1 ||
        (_currentZoom >= 11.2 && index % 2 == 0);

    final double circleSize = selected
        ? 40
        : (_currentZoom < 11.5 ? 28 : 34);

    return Marker(
      point: s.pos,
      width: 102,
      height: showNameLabel ? 68 : 42,
      child: GestureDetector(
        onTap: () => _selectStation(s, moveCamera: true),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: circleSize,
              height: circleSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: col,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: selected ? 2.6 : 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: col.withValues(alpha: selected ? 0.75 : 0.45),
                    blurRadius: selected ? 14 : 7,
                    spreadRadius: selected ? 2 : 0,
                  ),
                ],
              ),
              child: Text(
                valText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: selected ? 11.5 : (_currentZoom < 11.5 ? 9.5 : 10.5),
                  fontWeight: FontWeight.w800,
                  color: AppTheme.bg,
                ),
              ),
            ),
            if (showNameLabel) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary
                      : const Color(0xFF0B1328).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCustomPin
                        ? Colors.white
                        : col.withValues(alpha: 0.75),
                    width: 1,
                  ),
                ),
                child: Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 9.2,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.bg : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _selectStation(StationNode s, {bool moveCamera = false}) {
    setState(() {
      _selectedStation = s;
      _suggestions = [];
      _rebuildMapLayers();
    });
    if (moveCamera) {
      _mapCtrl.move(s.pos, math.max(_mapCtrl.camera.zoom, 13.4));
    }
  }

  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    if (_suggestions.isNotEmpty) {
      setState(() => _suggestions = []);
    }
    FocusScope.of(context).unfocus();

    final distKm = _locSvc.distanceKm(
      latlng.latitude,
      latlng.longitude,
      AppConstants.anchorLat,
      AppConstants.anchorLon,
    );
    if (distKm > AppConstants.serviceRadiusKm) {
      if (_selectedStation != null) {
        setState(() {
          _selectedStation = null;
          _rebuildMapLayers();
        });
      }
      _showOutOfScopeNotice(distKm);
      return;
    }

    final values = _interpolateAtPoint(latlng);
    final label = _findNearestAreaLabel(latlng);
    final customNode = StationNode(
      id: 'custom_tap',
      name: label,
      zoneType: 'Nội suy trực tiếp từ Database AppAir (${latlng.latitude.toStringAsFixed(3)}, ${latlng.longitude.toStringAsFixed(3)})',
      pos: latlng,
      trafficFactor: 1.0,
      industrialFactor: 1.0,
      greenFactor: 1.0,
      values: values,
    );
    setState(() {
      _selectedStation = customNode;
      _rebuildMapLayers();
    });
    _logSearch(customNode.name, latlng.latitude, latlng.longitude, values['pm2_5'] ?? 0);
  }

  void _showOutOfScopeNotice(double distKm) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF15203B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppTheme.poor.withValues(alpha: 0.7)),
        ),
        content: Row(
          children: [
            Expanded(
              child: Text(
                'Vị trí này cách Thủ Dầu Một ${distKm.toStringAsFixed(1)} km (ngoài vùng dữ liệu 20km của Database AppAir).',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _mapCtrl.move(_anchor, 12.6);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Về Tâm',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.bg,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchAddress(String query) async {
    final qClean = query.trim();
    if (qClean.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searchLoading = true;
      _suggestions = [];
    });

    try {
      final localMatches = _findLocalMatches(qClean);
      if (localMatches.isNotEmpty) {
        _selectGazetteerEntry(localMatches.first);
        if (mounted) setState(() => _searchLoading = false);
        return;
      }

      String searchLine = qClean;
      final qNorm = _normalizeVi(qClean);
      if (!qNorm.contains('binh duong') && !qNorm.contains('thu dau mot')) {
        searchLine = '$qClean, Thủ Dầu Một, Bình Dương, Việt Nam';
      }

      final esriUrl = Uri.parse(
        'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/findAddressCandidates'
        '?SingleLine=${Uri.encodeComponent(searchLine)}'
        '&location=${AppConstants.anchorLon},${AppConstants.anchorLat}'
        '&distance=20000'
        '&countryCode=VNM'
        '&maxLocations=5'
        '&f=json',
      );

      final res = await http.get(esriUrl).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final candidates = (data['candidates'] as List?) ?? [];
        if (candidates.isNotEmpty) {
          Map<String, dynamic>? chosen;
          for (final c in candidates) {
            final loc = c['location'] as Map<String, dynamic>?;
            if (loc != null) {
              final lat = (loc['y'] as num?)?.toDouble();
              final lon = (loc['x'] as num?)?.toDouble();
              if (lat != null &&
                  lon != null &&
                  _locSvc.isInServiceArea(lat, lon)) {
                chosen = c as Map<String, dynamic>;
                break;
              }
            }
          }
          chosen ??= candidates.first as Map<String, dynamic>;
          final loc = chosen['location'] as Map<String, dynamic>;
          final lat = (loc['y'] as num).toDouble();
          final lon = (loc['x'] as num).toDouble();
          final distKm = _locSvc.distanceKm(
            lat,
            lon,
            AppConstants.anchorLat,
            AppConstants.anchorLon,
          );

          if (distKm > AppConstants.serviceRadiusKm) {
            if (mounted) {
              _showOutOfScopeNotice(distKm);
            }
            return;
          }

          final rawAddr = chosen['address']?.toString() ?? qClean;
          final shortName = rawAddr.split(',').take(2).join(',').trim();
          final pt = LatLng(lat, lon);
          final interp = _interpolateAtPoint(pt);

          final node = StationNode(
            id: 'searched_point',
            name: shortName,
            zoneType: 'Địa điểm tra cứu tại Thủ Dầu Một (Nội suy từ Database AppAir)',
            pos: pt,
            trafficFactor: 1.0,
            industrialFactor: 1.0,
            greenFactor: 1.0,
            values: interp,
          );
          if (mounted) {
            setState(() {
              _selectedStation = node;
              _rebuildMapLayers();
            });
            _mapCtrl.move(pt, 14.0);
            _logSearch(shortName, lat, lon, interp['pm2_5'] ?? 0);
          }
          return;
        }
      }

      if (mounted) {
        _showError('Không tìm thấy địa chỉ phù hợp trong vùng Thủ Dầu Một');
      }
    } catch (_) {
      if (mounted) {
        _showError('Không thể kết nối dịch vụ tìm địa chỉ');
      }
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit()),
        backgroundColor: AppTheme.bad,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _logSearch(String address, double lat, double lon, double pm25) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('map_searches').insert({
        'user_id': uid,
        'address': address,
        'lat': lat,
        'lon': lon,
        'pm25': pm25,
      });
    } catch (_) {}
  }

  List<Widget> _buildBaseTileLayers() {
    if (_mapStyle == 'street') {
      return [
        TileLayer(
          key: const ValueKey<String>('esri_street'),
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.appair.appair',
          maxZoom: 19,
        ),
      ];
    }
    if (_mapStyle == 'satellite') {
      return [
        TileLayer(
          key: const ValueKey<String>('esri_sat_base'),
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.appair.appair',
          maxZoom: 19,
        ),
        TileLayer(
          key: const ValueKey<String>('esri_sat_ref'),
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.appair.appair',
          maxZoom: 19,
        ),
      ];
    }
    return [
      TileLayer(
        key: const ValueKey<String>('esri_dark_base'),
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.appair.appair',
        maxZoom: 19,
      ),
      TileLayer(
        key: const ValueKey<String>('esri_dark_ref'),
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.appair.appair',
        maxZoom: 19,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Bản đồ Không khí Thủ Dầu Một',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.good.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.good.withValues(alpha: 0.45)),
              ),
              child: Text(
                'DB: ${_dbLatencyMs}ms',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.good,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _loadFromDatabase,
            child: Text(
              'Làm mới',
              style: GoogleFonts.outfit(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _anchor,
              initialZoom: 12.6,
              minZoom: 5,
              maxZoom: 18,
              onTap: _onMapTap,
              onPositionChanged: (pos, hasGesture) {
                final z = pos.zoom;
                if ((z - _currentZoom).abs() >= 0.35) {
                  setState(() {
                    _currentZoom = z;
                    _rebuildMapLayers();
                  });
                }
              },
            ),
            children: [
              ..._buildBaseTileLayers(),
              CircleLayer(circles: _cachedCircles),
              MarkerLayer(markers: _cachedMarkers),
            ],
          ),
          _buildTopOverlay(),
          _buildRightControls(),
          if (_isLoading) _buildLoadingPill(),
          if (!_inArea) _buildOutOfAreaBanner(),
          _selectedStation != null
              ? _buildStationInspectorSheet(_selectedStation!)
              : _buildBottomRankingBar(),
        ],
      ),
    );
  }

  Widget _buildTopOverlay() {
    return Positioned(
      top: 10,
      left: 12,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1528).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      CustomPaint(
                        size: const Size(15, 15),
                        painter: _SearchLensPainter(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchTextChanged,
                          style: GoogleFonts.outfit(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tìm đường, phường tại Thủ Dầu Một (VD: Huỳnh Văn Lũy)...',
                            hintStyle: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: _searchAddress,
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _suggestions = []);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              'Xóa',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      if (_searchLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => _searchAddress(_searchCtrl.text),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              'Tìm',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1528).withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions.map((entry) {
                  return InkWell(
                    onTap: () => _selectGazetteerEntry(entry),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  entry.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Chọn',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _pollutantMeta.entries.map((e) {
                final active = _selectedPollutant == e.key;
                final label = e.value['label'] as String;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedPollutant == e.key) return;
                      setState(() {
                        _selectedPollutant = e.key;
                        _rebuildMapLayers();
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.primary
                            : const Color(0xFF0D1528).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? AppTheme.primary : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: active ? AppTheme.bg : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightControls() {
    final styles = [
      ('dark', 'Tối'),
      ('street', 'Phố'),
      ('satellite', 'Vệ tinh'),
    ];
    return Positioned(
      top: 104,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1528).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: styles.map((st) {
                final sel = _mapStyle == st.$1;
                return GestureDetector(
                  onTap: () {
                    if (_mapStyle == st.$1) return;
                    setState(() => _mapStyle = st.$1);
                  },
                  child: Container(
                    width: 54,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppTheme.primary.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: sel
                          ? Border.all(color: AppTheme.primary, width: 1)
                          : null,
                    ),
                    child: Text(
                      st.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                        color: sel ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          _mapActionBtn(
            label: '+',
            onTap: () => _mapCtrl.move(
                _mapCtrl.camera.center, _mapCtrl.camera.zoom + 1),
          ),
          const SizedBox(height: 6),
          _mapActionBtn(
            label: '-',
            onTap: () => _mapCtrl.move(
                _mapCtrl.camera.center, _mapCtrl.camera.zoom - 1),
          ),
          const SizedBox(height: 6),
          _mapActionBtn(
            label: 'Tâm',
            onTap: () {
              setState(() {
                _selectedStation = null;
                _currentZoom = 12.6;
                _rebuildMapLayers();
              });
              _mapCtrl.move(_anchor, 12.6);
            },
          ),
          if (_userPos != null) ...[
            const SizedBox(height: 6),
            _mapActionBtn(
              label: 'Tôi',
              onTap: () => _mapCtrl.move(
                  LatLng(_userPos!.latitude, _userPos!.longitude), 14.0),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mapActionBtn({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1528).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: label.length > 1 ? 11 : 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomRankingBar() {
    if (_rankedStations.isEmpty) return const SizedBox.shrink();
    final meta = _pollutantMeta[_selectedPollutant]!;
    final pLabel = meta['label'] as String;
    final unit = meta['unit'] as String;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 96,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1528).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Xếp hạng khu vực theo $pLabel (Phạm vi dữ liệu 20km Thủ Dầu Một)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _rankedStations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, idx) {
                  final s = _rankedStations[idx];
                  final val = s.values[_selectedPollutant] ?? 0;
                  final col = _pollutantColor(_selectedPollutant, val);
                  final isCleanest = idx == 0;
                  final isHighest = idx == _rankedStations.length - 1;
                  final valStr = _selectedPollutant == 'co'
                      ? val.toStringAsFixed(0)
                      : val.toStringAsFixed(1);

                  String rankTag = '#${idx + 1}';
                  if (isCleanest) rankTag = 'Sạch nhất';
                  if (isHighest) rankTag = 'Cao nhất';

                  return GestureDetector(
                    onTap: () => _selectStation(s, moveCamera: true),
                    child: Container(
                      width: 138,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: col.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rankTag,
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: col,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$valStr $unit (${_pollutantStatusLabel(_selectedPollutant, val)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: col,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStationInspectorSheet(StationNode s) {
    final val = s.values[_selectedPollutant] ?? 0;
    final anchorVal = _anchorMetrics[_selectedPollutant] ?? 1.0;
    final col = _pollutantColor(_selectedPollutant, val);
    final statusLbl = _pollutantStatusLabel(_selectedPollutant, val);
    final diffPct =
        anchorVal > 0 ? ((val - anchorVal) / anchorVal * 100.0) : 0.0;
    final cleaner = diffPct <= 0;
    const distCalc = Distance();
    final distKm = distCalc.as(LengthUnit.Meter, _anchor, s.pos) / 1000.0;

    final cmpText = diffPct.abs() < 1.0
        ? 'Tương đương Trạm trung tâm'
        : cleaner
            ? 'Thấp hơn trung tâm ${diffPct.abs().toStringAsFixed(0)}%'
            : 'Cao hơn trung tâm ${diffPct.abs().toStringAsFixed(0)}%';

    final advice = cleaner
        ? 'Khu vực này thoáng đãng hơn trung tâm, thuận lợi để đi dạo, chạy bộ hoặc tập thể thao ngoài trời.'
        : 'Mật độ giao thông và đô thị tại đây làm nồng độ bụi nhỉnh hơn, bạn nên đeo khẩu trang khi di chuyển qua.';

    return Positioned(
      left: 12,
      right: 12,
      bottom: 96,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1528).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: col.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 18,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'MỨC ${statusLbl.toUpperCase()}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: col,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cách tâm ${distKm.toStringAsFixed(1)} km  |  $cmpText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cleaner ? AppTheme.good : AppTheme.poor,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedStation = null;
                    _rebuildMapLayers();
                  }),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Đóng',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              s.zoneType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: _pollutantMeta.entries.map((e) {
                final k = e.key;
                final lbl = e.value['label'] as String;
                final v = s.values[k] ?? 0;
                final c = _pollutantColor(k, v);
                final isCur = k == _selectedPollutant;
                final vStr =
                    k == 'co' ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPollutant = k;
                        _rebuildMapLayers();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 3),
                      decoration: BoxDecoration(
                        color: isCur
                            ? c.withValues(alpha: 0.18)
                            : AppTheme.card,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isCur ? c : AppTheme.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            lbl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: c,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 9),
            Text(
              advice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutOfAreaBanner() {
    return Positioned(
      top: 104,
      left: 12,
      right: 76,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bad.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Vị trí của bạn ngoài bán kính 20km Thủ Dầu Một. Bản đồ đang hiển thị dữ liệu tại tâm Thủ Dầu Một.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.white,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPill() {
    return Positioned(
      top: 108,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Đang đồng bộ 6 chỉ số từ Database AppAir...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchLensPainter extends CustomPainter {
  final Color color;
  const _SearchLensPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final r = size.width * 0.36;
    final c = Offset(size.width * 0.42, size.height * 0.42);
    canvas.drawCircle(c, r, p);
    canvas.drawLine(
      Offset(c.dx + r * 0.72, c.dy + r * 0.72),
      Offset(size.width * 0.9, size.height * 0.9),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _SearchLensPainter oldDelegate) =>
      oldDelegate.color != color;
}
