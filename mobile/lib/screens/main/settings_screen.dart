import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../services/air_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _air = AirService();
  final _auth = AuthService();

  bool _loading = true;
  String _pmAlertThreshold = 'tb_15';
  bool _forecastPeakAlert = true;
  bool _dailyForecastAlert = true;

  String _healthGroup = 'binh_thuong';
  String _aqiStandard = 'vn_qcvn';
  String _primaryPollutant = 'pm2_5';
  String _skyThemeMode = 'auto';
  String _forecastRange = 'all';
  String _soundKey = 'ting_gentle';

  static const Map<String, String> _thresholdOptions = {
    'off': 'Tắt',
    'tb_15': 'Từ mức Khá / Trung bình (>15 ug/m3)',
    'kem_25': 'Từ mức Kém (>25 ug/m3)',
    'xau_50': 'Từ mức Cao / Xấu (>50 ug/m3)',
  };

  static const Map<String, String> _aqiStandardOptions = {
    'vn_qcvn': 'QCVN 05:2023/BTNMT (Việt Nam)',
    'who': 'Khuyến nghị WHO (Quốc tế)',
  };

  static const Map<String, String> _pollutantOptions = {
    'pm2_5': 'Bụi siêu mịn PM2.5 (ug/m3)',
    'pm10': 'Bụi mịn PM10 (ug/m3)',
    'co_no2': 'Khí giao thông CO & NO2',
    'so2_o3': 'Khí công nghiệp SO2 & O3',
  };

  static const Map<String, String> _skyOptions = {
    'auto': 'Tự động theo giờ thực tế',
    'morning': 'Giao diện Buổi sáng',
    'afternoon': 'Giao diện Buổi chiều',
    'night': 'Giao diện Buổi tối',
  };

  static const Map<String, String> _forecastRangeOptions = {
    'all': 'Toàn bộ 24 giờ tới',
    '6h': '6 giờ gần nhất',
    '12h': '12 giờ tới',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final mode = await NotificationService.getMode();
    final sound = await NotificationService.getSound();
    final profile = await _auth.getUserProfile();
    if (mounted) {
      setState(() {
        _pmAlertThreshold = p.getString('user_pm_threshold') ?? 'tb_15';
        _forecastPeakAlert = p.getBool('user_forecast_peak_alert') ?? true;
        _dailyForecastAlert = mode == 'smart' || mode == 'periods';
        final rawGroup = profile?['health_group']?.toString() ??
            (p.getString('user_health_group') ?? 'binh_thuong');
        _healthGroup = AppConstants.normalizeHealthGroup(rawGroup);
        final savedStd = p.getString('app_aqi_standard') ?? 'vn_qcvn';
        _aqiStandard = _aqiStandardOptions.containsKey(savedStd) ? savedStd : 'vn_qcvn';
        _primaryPollutant = p.getString('app_primary_pollutant') ?? 'pm2_5';
        _skyThemeMode = p.getString('app_sky_mode') ?? 'auto';
        _forecastRange = p.getString('app_forecast_range') ?? 'all';
        _soundKey = sound;
        _loading = false;
      });
    }
  }

  Future<void> _savePref(String key, String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, value);
  }

  Future<void> _toggleForecastPeakAlert(bool v) async {
    setState(() => _forecastPeakAlert = v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('user_forecast_peak_alert', v);
  }

  Future<void> _toggleDailyForecast(bool v) async {
    setState(() => _dailyForecastAlert = v);
    final nextMode = v ? 'smart' : 'aqi_only';
    await NotificationService.setMode(nextMode);
    final cur = await _air.getCurrent();
    final forecastData = await _air.getForecast();
    final pm25 = (cur?['pm2_5'] as num?)?.toDouble() ?? 28.0;
    final forecastList = (forecastData?['forecast_pm2_5'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [pm25];
    await NotificationService.scheduleDailyPeriods(
      forecastList,
      pm25,
      healthGroup: _healthGroup,
    );
  }

  Future<void> _showFloatingSelector({
    required Offset tapPosition,
    required Map<String, String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      color: const Color(0xFF232B3E),
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(tapPosition.dx, tapPosition.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: options.entries.map((e) {
        final selected = e.key == currentValue;
        return PopupMenuItem<String>(
          value: e.key,
          height: 46,
          child: SizedBox(
            width: 245,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e.value,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppTheme.primary : Colors.white,
                    ),
                  ),
                ),
                if (selected)
                  CustomPaint(
                    size: const Size(14, 10),
                    painter: _CheckmarkPainter(color: AppTheme.primary),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );

    if (result != null && result != currentValue) {
      onSelected(result);
    }
  }

  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Giới thiệu về AppAir',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hệ thống quan trắc 6 chỉ số ô nhiễm (PM2.5, PM10, CO, NO2, SO2, O3), cảnh báo sức khỏe cá nhân hóa và dự báo AI 24 giờ cho Thành phố Thủ Dầu Một.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _aboutInfoRow('Phiên bản ứng dụng', '1.0.0'),
            const Divider(color: AppTheme.border, height: 20),
            _aboutInfoRow('Mô hình trí tuệ nhân tạo', '1D-CNN + BiLSTM (24h)'),
            const Divider(color: AppTheme.border, height: 20),
            _aboutInfoRow('Quy chuẩn đối chiếu', 'QCVN 05:2023/BTNMT & WHO'),
            const Divider(color: AppTheme.border, height: 20),
            _aboutInfoRow('Nguồn dữ liệu khí quyển', 'Open-Meteo & Copernicus CAMS'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Đóng',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
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

  Widget _aboutInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(
          'Cài đặt',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 8),
                  child: Text(
                    'Cảnh báo chất lượng không khí',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _showFloatingSelector(
                          tapPosition: d.globalPosition,
                          options: _thresholdOptions,
                          currentValue: _pmAlertThreshold,
                          onSelected: (v) async {
                            setState(() => _pmAlertThreshold = v);
                            await _savePref('user_pm_threshold', v);
                          },
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Ngưỡng cảnh báo bụi mịn PM2.5',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _thresholdOptions[_pmAlertThreshold] ?? 'Tắt',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CustomPaint(
                                size: const Size(6, 11),
                                painter: _RightChevronPainter(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Cảnh báo đỉnh ô nhiễm dự báo 24h',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Switch(
                              value: _forecastPeakAlert,
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppTheme.primary,
                              onChanged: _toggleForecastPeakAlert,
                            ),
                          ],
                        ),
                      ),
                      _divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bản tin không khí hằng ngày',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Nhận thông tin cập nhật về chất lượng không khí và lời khuyên sức khỏe tại Thủ Dầu Một theo các buổi Sáng, Chiều và Tối trong ngày.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      color: AppTheme.textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Switch(
                              value: _dailyForecastAlert,
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppTheme.primary,
                              onChanged: _toggleDailyForecast,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 8),
                  child: Text(
                    'Cá nhân hóa & Hiển thị AppAir',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _selectorRow(
                        label: 'Nhóm sức khỏe của bạn',
                        valueText:
                            AppConstants.healthGroupLabels[_healthGroup] ?? '',
                        options: {
                          for (final k in AppConstants.healthGroups)
                            k: AppConstants.healthGroupLabels[k]!,
                        },
                        currentValue: _healthGroup,
                        onSelected: (v) async {
                          setState(() => _healthGroup = v);
                          await _savePref('user_health_group', v);
                          await _auth.updateHealthGroup(v);
                        },
                      ),
                      _divider(),
                      _selectorRow(
                        label: 'Quy chuẩn đánh giá AQI',
                        valueText: _aqiStandardOptions[_aqiStandard] ?? '',
                        options: _aqiStandardOptions,
                        currentValue: _aqiStandard,
                        onSelected: (v) async {
                          setState(() => _aqiStandard = v);
                          await _savePref('app_aqi_standard', v);
                        },
                      ),
                      _divider(),
                      _selectorRow(
                        label: 'Chỉ số ưu tiên theo dõi',
                        valueText: _pollutantOptions[_primaryPollutant] ?? '',
                        options: _pollutantOptions,
                        currentValue: _primaryPollutant,
                        onSelected: (v) async {
                          setState(() => _primaryPollutant = v);
                          await _savePref('app_primary_pollutant', v);
                        },
                      ),
                      _divider(),
                      _selectorRow(
                        label: 'Nền bầu trời Trang chủ',
                        valueText: _skyOptions[_skyThemeMode] ?? '',
                        options: _skyOptions,
                        currentValue: _skyThemeMode,
                        onSelected: (v) async {
                          setState(() => _skyThemeMode = v);
                          await _savePref('app_sky_mode', v);
                        },
                      ),
                      _divider(),
                      _selectorRow(
                        label: 'Khung giờ mặc định Dự báo',
                        valueText: _forecastRangeOptions[_forecastRange] ?? '',
                        options: _forecastRangeOptions,
                        currentValue: _forecastRange,
                        onSelected: (v) async {
                          setState(() => _forecastRange = v);
                          await _savePref('app_forecast_range', v);
                        },
                      ),
                      _divider(),
                      _selectorRow(
                        label: 'Âm thanh chuông báo',
                        valueText:
                            NotificationService.soundLabels[_soundKey] ?? '',
                        options: NotificationService.soundLabels,
                        currentValue: _soundKey,
                        onSelected: (v) async {
                          setState(() => _soundKey = v);
                          await NotificationService.setSound(v);
                          await NotificationService.playGentleChime(v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _showAboutSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 17),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Giới thiệu về AppAir',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: const Size(6, 11),
                          painter: _RightChevronPainter(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _divider() {
    return Divider(
      color: AppTheme.border.withValues(alpha: 0.7),
      height: 1,
      indent: 18,
      endIndent: 18,
    );
  }

  Widget _selectorRow({
    required String label,
    required String valueText,
    required Map<String, String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _showFloatingSelector(
        tapPosition: d.globalPosition,
        options: options,
        currentValue: currentValue,
        onSelected: onSelected,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Text(
                valueText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CustomPaint(
              size: const Size(8, 12),
              painter: _UpDownChevronPainter(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightChevronPainter extends CustomPainter {
  final Color color;

  const _RightChevronPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RightChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _UpDownChevronPainter extends CustomPainter {
  final Color color;

  const _UpDownChevronPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final top = Path()
      ..moveTo(0, size.height * 0.36)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.36);

    final bottom = Path()
      ..moveTo(0, size.height * 0.64)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, size.height * 0.64);

    canvas.drawPath(top, paint);
    canvas.drawPath(bottom, paint);
  }

  @override
  bool shouldRepaint(covariant _UpDownChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CheckmarkPainter extends CustomPainter {
  final Color color;

  const _CheckmarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width * 0.36, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
