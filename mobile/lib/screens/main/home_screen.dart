import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../services/air_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/metric_tile.dart';
import '../../widgets/shimmer_box.dart';
import 'forecast_screen.dart';
import 'info_screen.dart';
import 'map_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

enum SkyPeriod { morning, afternoon, night }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _Dashboard(),
      const ForecastScreen(),
      const InfoScreen(),
      const MapScreen(),
      const ChatScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1228).withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: _navItem(0, 'Trang chủ')),
                  Expanded(child: _navItem(1, 'Dự báo')),
                  Expanded(child: _navItem(2, 'Bản tin')),
                  Expanded(child: _navItem(3, 'Bản đồ')),
                  Expanded(child: _navItem(4, 'Chat AI')),
                  Expanded(child: _navItem(5, 'Hồ sơ')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx, String label) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: active
              ? Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: active ? 16 : 5,
              height: 3.5,
              decoration: BoxDecoration(
                color: active ? AppTheme.primary : Colors.white.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.72),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard();

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  final _air = AirService();
  final _auth = AuthService();
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _forecast;
  bool _loading = true;
  String _userName = '';
  String _healthGroup = 'binh_thuong';
  SkyPeriod? _overridePeriod;

  @override
  void initState() {
    super.initState();
    _load();
  }

  SkyPeriod get _activePeriod {
    if (_overridePeriod != null) return _overridePeriod!;
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 15) {
      return SkyPeriod.morning;
    } else if (hour >= 15 && hour < 18) {
      return SkyPeriod.afternoon;
    }
    return SkyPeriod.night;
  }

  String get _periodTitle {
    switch (_activePeriod) {
      case SkyPeriod.morning:
        return 'Buổi sáng';
      case SkyPeriod.afternoon:
        return 'Buổi chiều';
      case SkyPeriod.night:
        return 'Buổi tối';
    }
  }

  String get _skyNetworkUrl {
    switch (_activePeriod) {
      case SkyPeriod.morning:
        return 'https://images.unsplash.com/photo-1513002749550-c59d786b8e6c?auto=format&fit=crop&w=1600&q=85';
      case SkyPeriod.afternoon:
        return 'https://images.unsplash.com/photo-1508739773434-c26b3d09e071?auto=format&fit=crop&w=1600&q=85';
      case SkyPeriod.night:
        return 'https://images.unsplash.com/photo-1507400492013-162706c8c05e?auto=format&fit=crop&w=1600&q=85';
    }
  }

  String get _skyAssetPath {
    switch (_activePeriod) {
      case SkyPeriod.morning:
        return 'assets/images/sky_morning.jpg';
      case SkyPeriod.afternoon:
        return 'assets/images/sky_afternoon.jpg';
      case SkyPeriod.night:
        return 'assets/images/sky_night.jpg';
    }
  }

  List<Color> get _scrimColors {
    switch (_activePeriod) {
      case SkyPeriod.morning:
        return [
          const Color(0xFF0A2859).withValues(alpha: 0.62),
          const Color(0xFF103E7E).withValues(alpha: 0.38),
          const Color(0xFF0C2348).withValues(alpha: 0.72),
        ];
      case SkyPeriod.afternoon:
        return [
          const Color(0xFF1A143B).withValues(alpha: 0.58),
          const Color(0xFF3E204F).withValues(alpha: 0.35),
          const Color(0xFF16122E).withValues(alpha: 0.76),
        ];
      case SkyPeriod.night:
        return [
          const Color(0xFF050917).withValues(alpha: 0.52),
          const Color(0xFF0B142E).withValues(alpha: 0.35),
          const Color(0xFF060B19).withValues(alpha: 0.78),
        ];
    }
  }

  Color get _glassFillColor {
    switch (_activePeriod) {
      case SkyPeriod.morning:
        return const Color(0xFF0F2D59).withValues(alpha: 0.54);
      case SkyPeriod.afternoon:
        return const Color(0xFF23163B).withValues(alpha: 0.56);
      case SkyPeriod.night:
        return const Color(0xFF101C3B).withValues(alpha: 0.62);
    }
  }

  void _cyclePeriod() {
    setState(() {
      if (_overridePeriod == null) {
        _overridePeriod = SkyPeriod.morning;
      } else if (_overridePeriod == SkyPeriod.morning) {
        _overridePeriod = SkyPeriod.afternoon;
      } else if (_overridePeriod == SkyPeriod.afternoon) {
        _overridePeriod = SkyPeriod.night;
      } else {
        _overridePeriod = null;
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final skyMode = prefs.getString('app_sky_mode') ?? 'auto';
    final profile = await _auth.getUserProfile();
    final airData = await _air.getCurrent();
    final forecastData = await _air.getForecast();

    if (mounted) {
      setState(() {
        if (skyMode == 'morning') {
          _overridePeriod = SkyPeriod.morning;
        } else if (skyMode == 'afternoon') {
          _overridePeriod = SkyPeriod.afternoon;
        } else if (skyMode == 'night') {
          _overridePeriod = SkyPeriod.night;
        } else {
          _overridePeriod = null;
        }
        _userName = profile?['full_name'] ?? 'Bạn';
        _healthGroup = profile?['health_group'] ?? 'binh_thuong';
        _data = airData;
        _forecast = forecastData;
        _loading = false;
      });

      final pm25 = (airData?['pm2_5'] as num?)?.toDouble() ?? 0;
      NotificationService.listenAdminNotifications();
      await NotificationService.checkAndNotify(pm25, _healthGroup);

      final forecastList = (forecastData?['forecast_pm2_5'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList();
      if (forecastList != null && forecastList.isNotEmpty) {
        await NotificationService.forecastNotify(forecastList);
        await NotificationService.scheduleDailyPeriods(
          forecastList,
          pm25,
          healthGroup: _healthGroup,
        );
      }
    }
  }

  List<double> get _forecastValues {
    return (_forecast?['forecast_pm2_5'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
  }

  @override
  Widget build(BuildContext context) {
    final period = _activePeriod;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 550),
              child: Stack(
                key: ValueKey<SkyPeriod>(period),
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _skyNetworkUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      _skyAssetPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _scrimColors,
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          _buildTopBar(),
                          const SizedBox(height: 16),
                          _loading
                              ? const ShimmerBox(height: 210)
                              : _buildHeroSection(),
                          const SizedBox(height: 26),
                          _loading
                              ? const ShimmerBox(height: 180)
                              : _buildHourlyGlassCard(),
                          const SizedBox(height: 16),
                          _loading
                              ? const ShimmerBox(height: 240)
                              : _buildPeriodForecastCard(),
                          const SizedBox(height: 16),
                          _loading
                              ? const ShimmerBox(height: 260)
                              : _buildMetricsGrid(),
                          const SizedBox(height: 14),
                          _buildTimestamp(),
                          const SizedBox(height: 115),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final modeText = _overridePeriod == null
        ? 'Tự động: $_periodTitle'
        : 'Cảnh: $_periodTitle';

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Text(
                'Xin chào, $_userName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _cyclePeriod,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Text(
              modeText,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Text(
              'Tải lại',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    if (_data == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Chưa có dữ liệu. Kéo xuống để tải lại.',
          style: GoogleFonts.inter(color: Colors.white),
        ),
      );
    }

    final pm25 = (_data!['pm2_5'] as num?)?.toDouble() ?? 0;
    final label = _air.getAqiLabel(pm25);
    final level = _air.getAqiLevel(pm25);
    final statusColor = AppTheme.levelColor(level);

    final allValues = <double>[pm25, ..._forecastValues];
    final highVal = allValues.reduce((a, b) => a > b ? a : b);
    final lowVal = allValues.reduce((a, b) => a < b ? a : b);

    return Column(
      children: [
        Text(
          'CHẤT LƯỢNG KHÔNG KHÍ TRỰC TIẾP',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: Colors.white.withValues(alpha: 0.9),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Thủ Dầu Một',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 34,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            letterSpacing: -0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 64,
            fontWeight: FontWeight.w300,
            color: statusColor,
            height: 1.06,
            letterSpacing: -1.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chất lượng không khí hiện tại ($_periodTitle)',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'PM2.5: ${pm25.toStringAsFixed(1)} µg/m³   Cao: ${highVal.toStringAsFixed(0)}   Thấp: ${lowVal.toStringAsFixed(0)}',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyGlassCard() {
    final pm25 = (_data?['pm2_5'] as num?)?.toDouble() ?? 0;
    final forecastList = _forecastValues;
    final now = DateTime.now();

    String summaryText = _air.getAqiAdvice(pm25);
    if (forecastList.isNotEmpty) {
      double minV = forecastList.first;
      int minIdx = 0;
      double maxV = forecastList.first;
      int maxIdx = 0;
      for (int i = 0; i < forecastList.length; i++) {
        if (forecastList[i] < minV) {
          minV = forecastList[i];
          minIdx = i;
        }
        if (forecastList[i] > maxV) {
          maxV = forecastList[i];
          maxIdx = i;
        }
      }
      final bestHour = DateFormat('HH:00').format(now.add(Duration(hours: minIdx + 1)));
      final peakHour = DateFormat('HH:00').format(now.add(Duration(hours: maxIdx + 1)));
      final bestLabel = _air.getAqiLabel(minV).toLowerCase();
      final peakLabel = _air.getAqiLabel(maxV).toLowerCase();
      summaryText =
          'Dự báo không khí đạt mức $bestLabel vào khoảng $bestHour (${minV.toStringAsFixed(1)} µg/m³), và chuyển sang mức $peakLabel lúc $peakHour (${maxV.toStringAsFixed(1)} µg/m³).';
    }

    final items = <Map<String, dynamic>>[
      {
        'time': 'Bây giờ',
        'val': pm25,
      },
      ...List.generate(
        forecastList.length > 11 ? 11 : forecastList.length,
        (i) => {
          'time': '${now.add(Duration(hours: i + 1)).hour} giờ',
          'val': forecastList[i],
        },
      ),
    ];

    return _glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              summaryText,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.6,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          SizedBox(
            height: 118,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (_, i) {
                final item = items[i];
                final v = (item['val'] as num).toDouble();
                final level = _air.getAqiLevel(v);
                final label = _air.getAqiLabel(v);
                final color = AppTheme.levelColor(level);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['time'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.28),
                        border: Border.all(color: color, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${v.toStringAsFixed(0)} µg',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodForecastCard() {
    final pm25 = (_data?['pm2_5'] as num?)?.toDouble() ?? 0;
    final forecastList = _forecastValues;
    if (forecastList.isEmpty) {
      return const SizedBox.shrink();
    }

    final all = <double>[pm25, ...forecastList];
    final globalMin = all.reduce((a, b) => a < b ? a : b);
    final globalMax = all.reduce((a, b) => a > b ? a : b);

    List<double> sliceRange(int start, int end) {
      if (start >= forecastList.length) return [pm25];
      final safeEnd = end > forecastList.length ? forecastList.length : end;
      return forecastList.sublist(start, safeEnd);
    }

    final periods = [
      {'name': 'Hiện tại', 'vals': [pm25, ...sliceRange(0, 3)]},
      {'name': '6 giờ tới', 'vals': sliceRange(0, 6)},
      {'name': '12 giờ tới', 'vals': sliceRange(6, 12)},
      {'name': '18 giờ tới', 'vals': sliceRange(12, 18)},
      {'name': '24 giờ tới', 'vals': sliceRange(18, 24)},
    ];

    return _glassContainer(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIỄN BIẾN CHẤT LƯỢNG KHÔNG KHÍ 24 GIỜ',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 0.6,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          ...periods.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            final vals = p['vals'] as List<double>;
            final minV = vals.reduce((a, b) => a < b ? a : b);
            final maxV = vals.reduce((a, b) => a > b ? a : b);
            final avgV = vals.reduce((a, b) => a + b) / vals.length;
            final label = _air.getAqiLabel(avgV);
            final color = AppTheme.levelColor(_air.getAqiLevel(avgV));

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 74,
                        child: Text(
                          p['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 76,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          minV.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: Colors.white.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildRangeBar(
                          minV: minV,
                          maxV: maxV,
                          currentV: idx == 0 ? pm25 : avgV,
                          globalMin: globalMin,
                          globalMax: globalMax,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 30,
                        child: Text(
                          maxV.toStringAsFixed(0),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (idx < periods.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRangeBar({
    required double minV,
    required double maxV,
    required double currentV,
    required double globalMin,
    required double globalMax,
  }) {
    final span = (globalMax - globalMin).abs() < 1 ? 1.0 : (globalMax - globalMin);
    final startFrac = ((minV - globalMin) / span).clamp(0.0, 0.9);
    final endFrac = ((maxV - globalMin) / span).clamp(startFrac + 0.08, 1.0);
    final dotFrac = ((currentV - globalMin) / span).clamp(startFrac, endFrac);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final left = w * startFrac;
        final width = (w * (endFrac - startFrac)).clamp(14.0, w);
        final dotX = (w * dotFrac).clamp(4.0, w - 4.0);

        return SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: left,
                width: width,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF34D399),
                        Color(0xFFFBBF24),
                        Color(0xFFFB923C),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: dotX - 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0B1124), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid() {
    if (_data == null) return const SizedBox();
    final pm25 = (_data!['pm2_5'] as num?)?.toDouble() ?? 0;
    final pm10 = (_data!['pm10'] as num?)?.toDouble() ?? 0;
    final co = (_data!['carbon_monoxide'] as num?)?.toDouble() ?? 0;
    final no2 = (_data!['nitrogen_dioxide'] as num?)?.toDouble() ?? 0;
    final so2 = (_data!['sulphur_dioxide'] as num?)?.toDouble() ?? 0;
    final o3 = (_data!['ozone'] as num?)?.toDouble() ?? 0;

    final tiles = [
      MetricTile(
        label: 'PM2.5',
        value: pm25,
        unit: 'µg/m³',
        color: AppTheme.primary,
        maxValue: 75,
        levelLabel: _air.getAqiLabel(pm25),
      ),
      MetricTile(
        label: 'PM10',
        value: pm10,
        unit: 'µg/m³',
        color: AppTheme.secondary,
        maxValue: 150,
        levelLabel: pm10 <= 45
            ? 'Tốt'
            : pm10 <= 90
                ? 'Trung bình'
                : pm10 <= 180
                    ? 'Kém'
                    : 'Xấu',
      ),
      MetricTile(
        label: 'KHÍ CO',
        value: co,
        unit: 'µg/m³',
        color: AppTheme.moderate,
        maxValue: 15000,
        levelLabel: co <= 4400
            ? 'Tốt'
            : co <= 9400
                ? 'Trung bình'
                : 'Kém',
      ),
      MetricTile(
        label: 'KHÍ NO2',
        value: no2,
        unit: 'µg/m³',
        color: AppTheme.poor,
        maxValue: 300,
        levelLabel: no2 <= 40
            ? 'Tốt'
            : no2 <= 100
                ? 'Trung bình'
                : no2 <= 200
                    ? 'Kém'
                    : 'Xấu',
      ),
      MetricTile(
        label: 'KHÍ SO2',
        value: so2,
        unit: 'µg/m³',
        color: const Color(0xFF26C6DA),
        maxValue: 300,
        levelLabel: so2 <= 50
            ? 'Tốt'
            : so2 <= 125
                ? 'Trung bình'
                : so2 <= 250
                    ? 'Kém'
                    : 'Xấu',
      ),
      MetricTile(
        label: 'KHÍ O3',
        value: o3,
        unit: 'µg/m³',
        color: AppTheme.good,
        maxValue: 360,
        levelLabel: o3 <= 60
            ? 'Tốt'
            : o3 <= 120
                ? 'Trung bình'
                : o3 <= 240
                    ? 'Kém'
                    : 'Xấu',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'CHỈ SỐ THÀNH PHẦN KHÔNG KHÍ',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.24,
          ),
          itemBuilder: (_, i) => tiles[i],
        ),
      ],
    );
  }

  Widget _glassContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: _glassFillColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTimestamp() {
    final raw = _data?['recorded_at']?.toString() ?? '';
    String display = 'Chưa có dữ liệu';
    if (raw.isNotEmpty) {
      try {
        final dt = DateTime.parse(raw).toLocal();
        display = DateFormat('HH:mm - dd/MM/yyyy').format(dt);
      } catch (_) {}
    }
    return Center(
      child: Text(
        'Dữ liệu Open-Meteo cập nhật lúc $display',
        style: GoogleFonts.inter(
          fontSize: 11.5,
          color: Colors.white.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}
