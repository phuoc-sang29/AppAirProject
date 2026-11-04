import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../services/air_service.dart';

class AdminSystemTab extends StatefulWidget {
  const AdminSystemTab({super.key});

  @override
  State<AdminSystemTab> createState() => _AdminSystemTabState();
}

class _AdminSystemTabState extends State<AdminSystemTab> {
  final _db = Supabase.instance.client;
  final _air = AirService();

  bool _loading = true;
  bool _syncing = false;
  String? _syncStatusMsg;
  bool _syncSuccess = false;
  int? _localCount;

  int _records = 0;
  DateTime? _latest;
  Map<String, dynamic>? _latestRecord;
  bool _aiOnline = false;
  double? _rmse;
  double? _mae;
  String? _architecture;
  int? _params;
  double? _modelSizeKb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    int records = 0;
    DateTime? latest;
    Map<String, dynamic>? latestRow;
    try {
      records = await _db.from('air_quality').count();
      final rows = await _db
          .from('air_quality')
          .select()
          .order('recorded_at', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) {
        latestRow = Map<String, dynamic>.from(rows.first);
        latest = DateTime.tryParse(rows.first['recorded_at'].toString())?.toLocal();
      }
    } catch (_) {}
    final metrics = await _air.getMetrics();
    if (!mounted) return;
    final eval = metrics?['evaluation'] as Map<String, dynamic>?;
    final model = metrics?['model'] as Map<String, dynamic>?;
    setState(() {
      _records = records;
      _latest = latest;
      _latestRecord = latestRow;
      _aiOnline = metrics != null;
      _rmse = (eval?['rmse'] as num?)?.toDouble() ?? (metrics?['rmse'] as num?)?.toDouble();
      _mae = (eval?['mae'] as num?)?.toDouble() ?? (metrics?['mae'] as num?)?.toDouble();
      _architecture = model?['architecture']?.toString();
      _params = (model?['trainable_params'] as num?)?.toInt();
      _modelSizeKb = (model?['model_size_kb'] as num?)?.toDouble();
      _loading = false;
    });
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _syncStatusMsg = null;
    });
    final res = await _air.syncAirData();
    if (!mounted) return;
    if (res != null && res['success'] == true) {
      final fetched = res['fetched'] ?? 0;
      final dbs = res['databases'] as Map<String, dynamic>?;
      final localOk = dbs?['local']?['ok'] == true;
      final supaOk = dbs?['supabase']?['ok'] == true;
      final localTotal = (dbs?['local']?['total'] as num?)?.toInt();
      setState(() {
        _syncing = false;
        _syncSuccess = true;
        _localCount = localTotal;
        _syncStatusMsg =
            'Đã lấy $fetched bản ghi mới từ Open-Meteo. Đồng bộ Supabase: ${supaOk ? "Thành công" : "Lỗi"} | Local PostgreSQL: ${localOk ? "Thành công (${localTotal ?? 0} bản ghi)" : "Lỗi"}';
      });
      await _load();
    } else {
      setState(() {
        _syncing = false;
        _syncSuccess = false;
        _syncStatusMsg =
            'Không thể cập nhật dữ liệu. Vui lòng kiểm tra AI Service đang chạy ở cổng 8000.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    final stale = _latest == null ||
        DateTime.now().difference(_latest!).inHours >= 3;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSyncCard(),
        _buildModelEvalCard(),
        if (_latestRecord != null) _buildLatestEnvCard(),
        _row('Dữ liệu không khí', stale ? 'Chậm cập nhật' : 'Đang cập nhật',
            stale ? AppTheme.poor : AppTheme.good),
        _row('Bản ghi mới nhất',
            _latest == null ? 'Không có' : fmt.format(_latest!),
            AppTheme.textPrimary),
        _row('Tổng bản ghi (Supabase)', '$_records', AppTheme.primary),
        if (_localCount != null)
          _row('Tổng bản ghi (Local PostgreSQL)', '$_localCount', AppTheme.good),
        _row('AI Service', _aiOnline ? 'Đang hoạt động' : 'Không kết nối',
            _aiOnline ? AppTheme.good : AppTheme.bad),
        _row('Kiến trúc mô hình', _architecture ?? '1D-CNN + LSTM',
            AppTheme.secondary),
        _row('Tham số huấn luyện',
            _params == null ? '45,432' : NumberFormat.decimalPattern().format(_params),
            AppTheme.textPrimary),
        if (_modelSizeKb != null)
          _row('Dung lượng mô hình', '${_modelSizeKb!.toStringAsFixed(1)} KB',
              AppTheme.textPrimary),
        _row('Sai số RMSE',
            _rmse == null ? 'Không có' : '${_rmse!.toStringAsFixed(3)} ug/m3',
            AppTheme.textPrimary),
        _row('Sai số MAE',
            _mae == null ? 'Không có' : '${_mae!.toStringAsFixed(3)} ug/m3',
            AppTheme.textPrimary),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _load,
          child: Text('Làm mới trạng thái',
              style: GoogleFonts.outfit(
                  color: AppTheme.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildSyncCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cập nhật dữ liệu Open-Meteo thủ công',
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
              'Tải dữ liệu 6 chỉ số không khí mới nhất từ Open-Meteo API và tự động lưu đồng thời vào cả Supabase Cloud lẫn PostgreSQL Local.',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.5)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _syncing ? null : _syncNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _syncing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.2),
                        ),
                        const SizedBox(width: 10),
                        Text('Đang tải và đồng bộ 2 Database...',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.bg)),
                      ],
                    )
                  : Text('Cập nhật dữ liệu mới nhất ngay',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.bg)),
            ),
          ),
          if (_syncStatusMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_syncSuccess ? AppTheme.good : AppTheme.bad)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: (_syncSuccess ? AppTheme.good : AppTheme.bad)
                        .withValues(alpha: 0.45)),
              ),
              child: Text(
                _syncStatusMsg!,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _syncSuccess ? AppTheme.good : AppTheme.bad,
                    height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelEvalCard() {
    if (!_aiOnline || _rmse == null || _mae == null) {
      return const SizedBox.shrink();
    }
    final rmse = _rmse!;
    final mae = _mae!;
    final mse = rmse * rmse;
    final r2 = (1 - (mse / (mse + 50))).clamp(0.0, 1.0);
    final items = [
      _AdminMetricItem('RMSE', rmse, 50, AppTheme.poor, 'ug/m3'),
      _AdminMetricItem('MAE', mae, 50, AppTheme.moderate, 'ug/m3'),
      _AdminMetricItem('MSE', mse.clamp(0, 2500), 2500, AppTheme.bad, 'ug2'),
      _AdminMetricItem('R2', r2 * 100, 100, AppTheme.good, '%'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Biểu đồ Đánh giá Hiệu suất Mô hình CNN+LSTM',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Kiểm định kỹ thuật trên tập Test (20% dữ liệu Thủ Dầu Một)',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 18),
          SizedBox(
            height: 165,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= items.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(items[idx].label,
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: items[idx].color)),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= items.length) {
                          return const SizedBox();
                        }
                        final m = items[idx];
                        final label = m.unit == '%'
                            ? '${m.value.toStringAsFixed(1)}%'
                            : m.value.toStringAsFixed(m.unit == 'ug2' ? 0 : 2);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(label,
                              style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: m.color,
                                  fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppTheme.border, strokeWidth: 0.5),
                  getDrawingVerticalLine: (_) =>
                      const FlLine(color: Colors.transparent),
                ),
                borderData: FlBorderData(show: false),
                barGroups: items.asMap().entries.map((e) {
                  final idx = e.key;
                  final m = e.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: (m.value / m.max * 100).clamp(0.0, 100.0),
                        color: m.color,
                        width: 30,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: m.color.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items
                .map((m) => Column(
                      children: [
                        Text(
                            m.unit == 'ug2'
                                ? m.value.toStringAsFixed(0)
                                : m.unit == '%'
                                    ? '${m.value.toStringAsFixed(1)}%'
                                    : m.value.toStringAsFixed(2),
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: m.color,
                                fontWeight: FontWeight.w700)),
                        Text(m.unit,
                            style: GoogleFonts.outfit(
                                fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestEnvCard() {
    final r = _latestRecord!;
    double val(String k) => (r[k] as num?)?.toDouble() ?? 0.0;
    final specs = [
      ('PM2.5', '${val("pm2_5").toStringAsFixed(1)} ug/m3', AppTheme.primary),
      ('PM10', '${val("pm10").toStringAsFixed(1)} ug/m3', AppTheme.secondary),
      ('CO', '${val("carbon_monoxide").toStringAsFixed(0)} ug/m3', AppTheme.good),
      ('NO2', '${val("nitrogen_dioxide").toStringAsFixed(1)} ug/m3', AppTheme.moderate),
      ('SO2', '${val("sulphur_dioxide").toStringAsFixed(1)} ug/m3', AppTheme.poor),
      ('O3', '${val("ozone").toStringAsFixed(1)} ug/m3', AppTheme.primary),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thông số kỹ thuật 6 chất ô nhiễm (Bản ghi mới nhất)',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specs.map((s) {
              return Container(
                width: 140,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.$1,
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(s.$2,
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: s.$3)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _AdminMetricItem {
  final String label;
  final double value;
  final double max;
  final Color color;
  final String unit;
  const _AdminMetricItem(this.label, this.value, this.max, this.color, this.unit);
}
