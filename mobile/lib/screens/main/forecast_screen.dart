import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../services/air_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/shimmer_box.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final _air = AirService();
  final _auth = AuthService();

  Map<String, dynamic>? _forecast;
  Map<String, dynamic>? _metrics;
  List<Map<String, dynamic>> _history = [];
  String _healthGroup = 'binh_thuong';
  String _hourFilter = 'all';
  bool _loading = true;
  bool _aiOnline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedRange = prefs.getString('app_forecast_range') ?? 'all';
    final results = await Future.wait([
      _air.getForecast(),
      _air.getMetrics(),
      _air.getHistory(hours: 24),
      _auth.getUserProfile(),
    ]);
    if (mounted) {
      final profile = results[3] as Map<String, dynamic>?;
      setState(() {
        _hourFilter = savedRange;
        _forecast = results[0] as Map<String, dynamic>?;
        _metrics = results[1] as Map<String, dynamic>?;
        _history = results[2] as List<Map<String, dynamic>>;
        _healthGroup = profile?['health_group']?.toString() ?? 'binh_thuong';
        _aiOnline = _forecast != null;
        _loading = false;
      });
    }
  }

  DateTime _baseHour() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour);
  }

  String _personalizedAdvice(double maxPm25, double minPm25, DateTime bestTime, DateTime peakTime) {
    final bestStr = DateFormat('HH:00').format(bestTime);
    final peakStr = DateFormat('HH:00').format(peakTime);
    final normGroup = AppConstants.normalizeHealthGroup(_healthGroup);
    final groupLabel = AppConstants.healthGroupLabels[normGroup] ?? 'Sức khỏe bình thường';

    if (normGroup == 'benh_ho_hap') {
      if (maxPm25 > 25) {
        return 'Nhóm $groupLabel: Dự báo bụi mịn đạt đỉnh ${maxPm25.toStringAsFixed(1)} ug/m3 lúc $peakStr. Bạn nên ưu tiên ra ngoài quanh $bestStr (${minPm25.toStringAsFixed(1)} ug/m3), mang sẵn thuốc dự phòng hen suyễn/xoang và đeo khẩu trang KN95.';
      }
      return 'Nhóm $groupLabel: Chất lượng không khí 24 giờ tới khá thuận lợi cho hệ hô hấp, khung giờ thoáng sạch nhất là $bestStr (${minPm25.toStringAsFixed(1)} ug/m3).';
    }
    if (normGroup == 'tre_em') {
      if (maxPm25 > 25) {
        return 'Nhóm $groupLabel: Hạn chế cho trẻ nhỏ và người cao tuổi hoạt động ngoài trời quanh khung giờ $peakStr (${maxPm25.toStringAsFixed(1)} ug/m3). Thời điểm tốt nhất để dạo mát là khoảng $bestStr.';
      }
      return 'Nhóm $groupLabel: Không khí an toàn cho trẻ vui chơi và người lớn tuổi tập dưỡng sinh, lý tưởng nhất lúc $bestStr (${minPm25.toStringAsFixed(1)} ug/m3).';
    }
    if (normGroup == 'van_dong') {
      if (maxPm25 > 25) {
        return 'Nhóm $groupLabel: Khung giờ vàng để chạy bộ, đạp xe ngoài trời là lúc $bestStr (${minPm25.toStringAsFixed(1)} ug/m3). Tránh tập cardio cường độ cao ngoài đường lúc $peakStr (${maxPm25.toStringAsFixed(1)} ug/m3) vì lượng khí hít vào tăng gấp 3-5 lần.';
      }
      return 'Nhóm $groupLabel: Điều kiện lý tưởng để chạy bộ và làm việc ngoài trời suốt 24 giờ tới, khung giờ thoáng mát nhất là $bestStr (${minPm25.toStringAsFixed(1)} ug/m3).';
    }
    if (maxPm25 > 25) {
      return 'Nhóm $groupLabel: Khung giờ không khí thoáng sạch nhất để tập thể dục hoặc mở cửa thông gió là $bestStr (${minPm25.toStringAsFixed(1)} ug/m3). Hạn chế hoạt động ngoài trời kéo dài lúc $peakStr (${maxPm25.toStringAsFixed(1)} ug/m3).';
    }
    return 'Nhóm $groupLabel: Chất lượng không khí 24 giờ tới ổn định, thuận lợi cho mọi hoạt động ngoài trời (tốt nhất lúc $bestStr).';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dự báo và Báo cáo 24 giờ',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _aiOnline ? AppTheme.good : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _aiOnline
                      ? 'Mô hình 1D-CNN + LSTM đang hoạt động'
                      : 'AI đang ngoại tuyến',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _aiOnline ? AppTheme.good : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _load,
            child: Text('Làm mới',
                style: GoogleFonts.outfit(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            _loading ? const ShimmerBox(height: 190) : _buildAiSummaryCard(),
            const SizedBox(height: 20),
            _buildSectionTitle('Xu hướng 48 giờ (24h Thực tế và 24h Dự báo)'),
            const SizedBox(height: 12),
            _loading ? const ShimmerBox(height: 280) : _buildForecastChart(),
            const SizedBox(height: 20),
            _buildSectionTitle('Lịch trình chất lượng không khí 24 giờ tới'),
            const SizedBox(height: 10),
            _buildFilterBar(),
            const SizedBox(height: 12),
            _loading ? const ShimmerBox(height: 300) : _buildHourlyList(),
            const SizedBox(height: 20),
            _loading ? const ShimmerBox(height: 90) : _buildModelTrustCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSummaryCard() {
    final list = (_forecast?['forecast_pm2_5'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          'Đang kết nối mô hình dự báo AI. Vui lòng bấm Làm mới để tải bản tin dự báo 24 giờ.',
          style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
      );
    }

    final base = _baseHour();
    double minVal = list.first;
    double maxVal = list.first;
    int minIdx = 0;
    int maxIdx = 0;
    for (int i = 0; i < list.length; i++) {
      if (list[i] < minVal) {
        minVal = list[i];
        minIdx = i;
      }
      if (list[i] > maxVal) {
        maxVal = list[i];
        maxIdx = i;
      }
    }

    final bestTime = base.add(Duration(hours: minIdx + 1));
    final peakTime = base.add(Duration(hours: maxIdx + 1));
    final bestColor = AppTheme.levelColor(_air.getAqiLevel(minVal));
    final peakColor = AppTheme.levelColor(_air.getAqiLevel(maxVal));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.16),
            AppTheme.card,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('BẢN TIN TÓM TẮT AI 24H',
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppTheme.primary)),
              ),
              const Spacer(),
              Text('Thủ Dầu Một',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: bestColor.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Khung giờ sạch nhất',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text(DateFormat('HH:00').format(bestTime),
                          style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: bestColor)),
                      const SizedBox(height: 2),
                      Text('${_air.getAqiLabel(minVal)} (${minVal.toStringAsFixed(1)} ug/m3)',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: bestColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: peakColor.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đỉnh ô nhiễm dự kiến',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text(DateFormat('HH:00').format(peakTime),
                          style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: peakColor)),
                      const SizedBox(height: 2),
                      Text('${_air.getAqiLabel(maxVal)} (${maxVal.toStringAsFixed(1)} ug/m3)',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: peakColor)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _personalizedAdvice(maxVal, minVal, bestTime, peakTime),
            style: GoogleFonts.outfit(
                fontSize: 12.5, color: AppTheme.textPrimary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastChart() {
    final forecastList = (_forecast?['forecast_pm2_5'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final historyPm25 =
        _history.map((r) => (r['pm2_5'] as num?)?.toDouble() ?? 0.0).toList();

    final histSpots = historyPm25
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final forecastSpots = <FlSpot>[];
    if (historyPm25.isNotEmpty && forecastList.isNotEmpty) {
      forecastSpots.add(FlSpot(
          (historyPm25.length - 1).toDouble(), historyPm25.last));
    }
    for (int i = 0; i < forecastList.length; i++) {
      forecastSpots.add(FlSpot((historyPm25.length + i).toDouble(), forecastList[i]));
    }

    final allValues = [...historyPm25, ...forecastList];
    final maxY = allValues.isEmpty
        ? 60.0
        : (allValues.reduce((a, b) => a > b ? a : b) + 8).clamp(25.0, 120.0);
    final base = _baseHour();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Diễn biến bụi mịn PM2.5 (ug/m3)',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
              ),
              Text('Chạm điểm để xem giờ',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 210,
            child: historyPm25.isEmpty
                ? Center(
                    child: Text('Chưa có dữ liệu',
                        style: GoogleFonts.outfit(color: AppTheme.textSecondary)))
                : LineChart(
                    LineChartData(
                      backgroundColor: Colors.transparent,
                      minY: 0,
                      maxY: maxY,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppTheme.surface,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final idx = spot.x.toInt();
                              final offsetHours = idx - (historyPm25.length - 1);
                              final dt = base.add(Duration(hours: offsetHours));
                              final tag = offsetHours <= 0 ? 'Thực tế' : 'Dự báo';
                              final lvl = _air.getAqiLabel(spot.y);
                              return LineTooltipItem(
                                '$tag ${DateFormat("HH:00").format(dt)}\n${spot.y.toStringAsFixed(1)} ug/m3 ($lvl)',
                                GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        horizontalInterval: 15,
                        getDrawingHorizontalLine: (v) {
                          Color c = AppTheme.border;
                          if (v == 15) c = AppTheme.good.withValues(alpha: 0.4);
                          if (v == 25) c = AppTheme.moderate.withValues(alpha: 0.4);
                          if (v == 50) c = AppTheme.poor.withValues(alpha: 0.4);
                          return FlLine(color: c, strokeWidth: 0.7);
                        },
                        getDrawingVerticalLine: (_) =>
                            const FlLine(color: Colors.transparent),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 15,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: GoogleFonts.outfit(
                                  fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 12,
                            getTitlesWidget: (v, _) {
                              final idx = v.toInt();
                              final offset = idx - (historyPm25.length - 1);
                              String label = '';
                              if (offset == -23 || offset == -24) {
                                label = '-24h';
                              } else if (offset == -12) {
                                label = '-12h';
                              } else if (offset == 0) {
                                label = 'Nay';
                              } else if (offset == 12) {
                                label = '+12h';
                              } else if (offset == 24) {
                                label = '+24h';
                              }
                              if (label.isEmpty) return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  label,
                                  style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: histSpots,
                          isCurved: true,
                          color: AppTheme.primary,
                          barWidth: 2.2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primary.withValues(alpha: 0.08),
                          ),
                        ),
                        if (forecastSpots.isNotEmpty)
                          LineChartBarData(
                            spots: forecastSpots,
                            isCurved: true,
                            color: AppTheme.poor,
                            barWidth: 2.2,
                            dotData: const FlDotData(show: false),
                            dashArray: [6, 4],
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppTheme.poor.withValues(alpha: 0.07),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _legend(AppTheme.primary, 'Thực tế 24h qua'),
              if (forecastList.isNotEmpty) _legend(AppTheme.poor, 'Dự báo 24h tới'),
              _legend(AppTheme.good, 'Tốt (<=15)'),
              _legend(AppTheme.moderate, 'Trung bình (<=25)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('all', 'Tất cả 24 giờ'),
      ('6h', '6 giờ tới'),
      ('12h', '12 giờ tới'),
      ('good', 'Tốt / TB (<=25)'),
      ('warn', 'Kém (>25)'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((f) {
        final active = _hourFilter == f.$1;
        return GestureDetector(
          onTap: () => setState(() => _hourFilter = f.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primary.withValues(alpha: 0.18)
                  : AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: active ? AppTheme.primary : AppTheme.border),
            ),
            child: Text(
              f.$2,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _periodLabel(int hour) {
    if (hour >= 5 && hour < 11) return 'Buổi sáng';
    if (hour >= 11 && hour < 18) return 'Buổi chiều';
    return 'Ban đêm';
  }

  Widget _buildHourlyList() {
    final list = (_forecast?['forecast_pm2_5'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          'Dự báo theo giờ chưa khả dụng. Vui lòng kiểm tra AI Service.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
        ),
      );
    }

    final base = _baseHour();
    final maxVal = list.reduce((a, b) => a > b ? a : b);
    final minVal = list.reduce((a, b) => a < b ? a : b);
    final peakIdx = list.indexOf(maxVal);
    final bestIdx = list.indexOf(minVal);

    final filtered = list.asMap().entries.where((e) {
      if (_hourFilter == '6h') return e.key < 6;
      if (_hourFilter == '12h') return e.key < 12;
      if (_hourFilter == 'good') return e.value <= 25;
      if (_hourFilter == 'warn') return e.value > 25;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          'Không có khung giờ nào thuộc bộ lọc này trong 24 giờ tới.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: filtered.asMap().entries.map((entry) {
          final rowPos = entry.key;
          final idx = entry.value.key;
          final v = entry.value.value;
          final t = base.add(Duration(hours: idx + 1));
          final level = _air.getAqiLevel(v);
          final label = _air.getAqiLabel(v);
          final color = AppTheme.levelColor(level);
          final isPeak = idx == peakIdx;
          final isBest = idx == bestIdx;

          String badgeText = label;
          if (isBest) badgeText = 'Tốt nhất';
          if (isPeak) badgeText = 'Đỉnh 24h';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: (isPeak || isBest) ? color.withValues(alpha: 0.07) : null,
              border: rowPos < filtered.length - 1
                  ? const Border(
                      bottom: BorderSide(color: AppTheme.border, width: 0.5))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('HH:00').format(t),
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _periodLabel(t.hour),
                        style: GoogleFonts.outfit(
                            fontSize: 10.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (v / 60).clamp(0.0, 1.0),
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation(color),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 7,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 68,
                  child: Text(
                    '${v.toStringAsFixed(1)} ug',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: color,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 66,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.outfit(
                        fontSize: 10, color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModelTrustCard() {
    final eval = _metrics?['evaluation'] as Map<String, dynamic>?;
    final mae = (eval?['mae'] as num?)?.toDouble() ??
        (_forecast?['mae'] as num?)?.toDouble();
    final rmse = (eval?['rmse'] as num?)?.toDouble() ??
        (_forecast?['rmse'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
            ),
            child: Text('AI',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.secondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nguồn dự báo: Mô hình học sâu 1D-CNN + LSTM',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  mae != null && rmse != null
                      ? 'Sai số trung bình MAE: ±${mae.toStringAsFixed(1)} ug/m3 | RMSE: ${rmse.toStringAsFixed(1)} | QCVN 05:2023/BTNMT'
                      : 'Đối chiếu theo quy chuẩn QCVN 05:2023/BTNMT và dữ liệu Open-Meteo',
                  style: GoogleFonts.outfit(
                      fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 16,
            height: 3,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildSectionTitle(String t) => Text(t,
      style: GoogleFonts.outfit(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary));
}
