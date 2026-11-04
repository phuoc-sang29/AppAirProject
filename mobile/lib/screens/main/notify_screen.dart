import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../services/air_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import 'settings_screen.dart';

class NotifyScreen extends StatefulWidget {
  const NotifyScreen({super.key});

  @override
  State<NotifyScreen> createState() => _NotifyScreenState();
}

class _NotifyScreenState extends State<NotifyScreen> {
  final _db = Supabase.instance.client;
  final _air = AirService();
  final _auth = AuthService();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _sound = 'ting_gentle';
  String _healthGroup = 'binh_thuong';
  double _curPm25 = 25.0;
  double _minFc = 18.0;
  double _maxFc = 32.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sound = await NotificationService.getSound();
    final cur = await _air.getCurrent();
    final fc = await _air.getForecast();
    final profile = await _auth.getUserProfile();

    final pm25 = (cur?['pm2_5'] as num?)?.toDouble() ?? 25.0;
    final group = profile?['health_group']?.toString() ?? 'binh_thuong';
    final fcList = (fc?['forecast_pm2_5'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final minVal = fcList.isNotEmpty
        ? math.min(pm25, fcList.reduce(math.min))
        : math.max(6.0, pm25 * 0.78);
    final maxVal = fcList.isNotEmpty
        ? math.max(pm25, fcList.reduce(math.max))
        : pm25 * 1.18;

    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _sound = sound;
          _healthGroup = group;
          _curPm25 = pm25;
          _minFc = minVal;
          _maxFc = maxVal;
          _loading = false;
        });
      }
      return;
    }
    try {
      final rows = await _db
          .from('notifications')
          .select('id, message, level, is_read, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _sound = sound;
          _healthGroup = group;
          _curPm25 = pm25;
          _minFc = minVal;
          _maxFc = maxVal;
          _items = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sound = sound;
          _healthGroup = group;
          _curPm25 = pm25;
          _minFc = minVal;
          _maxFc = maxVal;
          _loading = false;
        });
      }
    }
  }

  Future<void> _testPush([String? periodKey]) async {
    final genz = NotificationService.buildGenZMessage(
      pm25: _curPm25,
      healthGroup: _healthGroup,
      periodKey: periodKey,
      minPm25: _minFc,
      maxPm25: _maxFc,
    );
    final soundName =
        NotificationService.soundLabels[_sound] ?? 'Tiếng Ting dịu nhẹ';

    await NotificationService.show(
      id: 999,
      title: '${genz['range']} ug/m3 | ${genz['status_text']} - ${genz['date_meta']}',
      body: '${genz['body']!} ${genz['tip']!}',
    );
    if (!mounted) return;
    NotificationService.showAnimatedPopup(
      context,
      title: genz['title']!,
      body: genz['body']!,
      tip: genz['tip']!,
      level: genz['level']!,
      soundName: soundName,
      periodKey: genz['period'],
      rangeText: genz['range'],
      statusText: genz['status_text'],
      dateMeta: genz['date_meta'],
      timeTag: genz['time_tag'],
    );
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return 'Vừa xong';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final liveMsg = NotificationService.buildGenZMessage(
      pm25: _curPm25,
      healthGroup: _healthGroup,
      minPm25: _minFc,
      maxPm25: _maxFc,
      timeLabel: 'Trực tiếp',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thông báo',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => _testPush(),
            child: Text(
              'Xem thử',
              style: GoogleFonts.outfit(
                color: AppTheme.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _load();
            },
            child: Text(
              'Cài đặt',
              style: GoogleFonts.outfit(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: Text(
              'Làm mới',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bản tin nhanh hôm nay (Chạm thẻ để mở rộng)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _testPush(),
                      child: Text(
                        'Bật popup',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppAirNotificationCard(
                  title: liveMsg['title']!,
                  body: liveMsg['body']!,
                  tip: liveMsg['tip']!,
                  level: liveMsg['level']!,
                  periodKey: liveMsg['period']!,
                  rangeText: liveMsg['range']!,
                  statusText: liveMsg['status_text']!,
                  dateMeta: liveMsg['date_meta']!,
                  timeTag: liveMsg['time_tag']!,
                  initiallyExpanded: false,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mô phỏng thông báo nền khi chưa mở ứng dụng (Hẹn 5 giây)',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bấm nút bên dưới rồi ẩn trình duyệt hoặc thoát ra màn hình chính. Sau 5 giây hệ thống sẽ đẩy thông báo từ mức Khá đến mức Cao.',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  NotificationService.scheduleBackgroundDemo(
                                context,
                                simulatedPm25: 21.5,
                                healthGroup: _healthGroup,
                                delaySeconds: 5,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.moderate,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Hẹn 5s Mức Khá (21.5)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  NotificationService.scheduleBackgroundDemo(
                                context,
                                simulatedPm25: 56.8,
                                healthGroup: _healthGroup,
                                delaySeconds: 5,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.bad,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Hẹn 5s Mức Cao (56.8)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Hộp thư thông báo của bạn (${_items.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'Chưa có thông báo nào trong hộp thư',
                      style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                    ),
                  )
                else
                  ..._items.map(_buildInboxCard),
              ],
            ),
    );
  }

  Widget _buildInboxCard(Map<String, dynamic> n) {
    final level = n['level']?.toString() ?? 'info';
    final dt = DateTime.tryParse(n['created_at']?.toString() ?? '')?.toLocal();
    final relTime = _relativeTime(dt);
    final dateStr = dt == null
        ? DateFormat('dd/MM').format(DateTime.now())
        : DateFormat('dd/MM').format(dt);
    final msg = n['message']?.toString() ?? '';

    final genz = NotificationService.buildGenZMessage(
      pm25: _curPm25,
      healthGroup: _healthGroup,
      customMessage: msg,
      customLevel: level,
      minPm25: _minFc,
      maxPm25: _maxFc,
      timeLabel: relTime,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppAirNotificationCard(
        title: genz['title']!,
        body: genz['body']!,
        tip: genz['tip']!,
        level: level,
        periodKey: genz['period']!,
        rangeText: genz['range']!,
        statusText: genz['status_text']!,
        dateMeta: '$dateStr (Thủ Dầu Một - QCVN)',
        timeTag: relTime,
      ),
    );
  }
}
