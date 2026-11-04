import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../services/air_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';

class AdminNotifyTab extends StatefulWidget {
  const AdminNotifyTab({super.key});

  @override
  State<AdminNotifyTab> createState() => _AdminNotifyTabState();
}

class _AdminNotifyTabState extends State<AdminNotifyTab> {
  final _db = Supabase.instance.client;
  final _air = AirService();
  final _auth = AuthService();
  final _msgCtrl = TextEditingController();
  String _group = 'all';
  String _level = 'info';
  bool _sending = false;
  bool _generatingSmart = false;
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  String _mode = 'smart';
  String _sound = 'ting_gentle';
  int _maxDaily = 3;
  int _sentToday = 0;
  Set<String> _enabledPeriods = {'morning', 'afternoon', 'night'};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final mode = await NotificationService.getMode();
    final sound = await NotificationService.getSound();
    final maxDaily = await NotificationService.getMaxDaily();
    final sentToday = await NotificationService.getTodaySentCount();
    final periods = await NotificationService.getEnabledPeriods();
    if (mounted) {
      setState(() {
        _mode = mode;
        _sound = sound;
        _maxDaily = maxDaily;
        _sentToday = sentToday;
        _enabledPeriods = periods;
      });
    }
  }

  Future<void> _reschedulePeriods() async {
    final cur = await _air.getCurrent();
    final forecastData = await _air.getForecast();
    final profile = await _auth.getUserProfile();
    final pm25 = (cur?['pm2_5'] as num?)?.toDouble() ?? 28.0;
    final group = profile?['health_group']?.toString() ?? 'binh_thuong';
    final forecastList = (forecastData?['forecast_pm2_5'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [pm25];
    await NotificationService.scheduleDailyPeriods(
      forecastList,
      pm25,
      healthGroup: group,
    );
  }

  Future<void> _togglePeriod(String key) async {
    final next = Set<String>.from(_enabledPeriods);
    if (next.contains(key)) {
      if (next.length <= 1) return;
      next.remove(key);
    } else {
      next.add(key);
    }
    setState(() => _enabledPeriods = next);
    await NotificationService.setEnabledPeriods(next);
    await _reschedulePeriods();
  }

  Future<void> _testPush({String? periodKey}) async {
    final cur = await _air.getCurrent();
    final fc = await _air.getForecast();
    final profile = await _auth.getUserProfile();
    final pm25 = (cur?['pm2_5'] as num?)?.toDouble() ?? 29.7;
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

    final genz = NotificationService.buildGenZMessage(
      pm25: pm25,
      healthGroup: group,
      periodKey: periodKey,
      minPm25: minVal,
      maxPm25: maxVal,
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

  Future<void> _loadHistory() async {
    try {
      final rows = await _db
          .from('notifications')
          .select('id, user_id, message, level, is_read, created_at')
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        final deduped = <Map<String, dynamic>>[];
        final seen = <String>{};
        for (final r in rows) {
          final msg = r['message']?.toString() ?? '';
          final lvl = r['level']?.toString() ?? 'info';
          final ts = (r['created_at']?.toString() ?? '').substring(
              0,
              (r['created_at']?.toString() ?? '').length >= 16
                  ? 16
                  : (r['created_at']?.toString() ?? '').length);
          final key = '$lvl|$msg|$ts';
          if (!seen.contains(key)) {
            seen.add(key);
            deduped.add(Map<String, dynamic>.from(r));
          }
        }
        setState(() {
          _history = deduped;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _show(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: error ? AppTheme.bad : AppTheme.good,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fillSmartGenZContent() async {
    setState(() => _generatingSmart = true);
    try {
      final cur = await _air.getCurrent();
      final pm25 = (cur?['pm2_5'] as num?)?.toDouble() ?? 29.7;
      final groupKey = _group == 'all' ? 'binh_thuong' : _group;
      final genz = NotificationService.buildGenZMessage(
        pm25: pm25,
        healthGroup: groupKey,
      );
      String autoLevel = 'info';
      if (pm25 > 50) {
        autoLevel = 'danger';
      } else if (pm25 > 15) {
        autoLevel = 'warning';
      }
      if (mounted) {
        setState(() {
          _level = autoLevel;
          _msgCtrl.text = '${genz['body']} (${genz['tip']})';
          _generatingSmart = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _generatingSmart = false);
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) {
      _show('Vui lòng nhập nội dung thông báo.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      var query = _db.from('users').select('id').eq('is_blocked', false);
      if (_group != 'all') {
        query = query.eq('health_group', _group);
      }
      final users = await query;
      if (users.isEmpty) {
        _show('Không có người dùng nào thuộc nhóm này.', error: true);
        return;
      }
      final rows = users
          .map((u) => {
                'user_id': u['id'],
                'message': text,
                'level': _level,
              })
          .toList();
      await _db.from('notifications').insert(rows);
      _msgCtrl.clear();
      _show('Đã gửi thông báo đến ${rows.length} người dùng.');
      await _loadHistory();
    } catch (_) {
      _show('Gửi thất bại. Kiểm tra quyền admin và kết nối.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Color _levelColor(String level) {
    if (level == 'danger') return AppTheme.bad;
    if (level == 'warning') return AppTheme.poor;
    return AppTheme.primary;
  }

  String _levelLabel(String level) {
    if (level == 'danger') return 'Khẩn cấp';
    if (level == 'warning') return 'Cảnh báo';
    return 'Thông tin';
  }

  Widget _buildEngineConfigCard() {
    final showPeriods = _mode == 'smart' || _mode == 'periods';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('CẤU HÌNH THUẬT TOÁN & CHUÔNG BÁO HỆ THỐNG',
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppTheme.primary)),
              ),
              const Spacer(),
              Text('Đã báo hôm nay: $_sentToday/$_maxDaily lần',
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.good)),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_mode),
            initialValue: _mode,
            isExpanded: true,
            dropdownColor: AppTheme.surface,
            style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 12.5),
            decoration: const InputDecoration(
              labelText: 'Thuật toán lập lịch thông báo tự động',
            ),
            items: NotificationService.modeLabels.entries
                .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) async {
              final next = v ?? 'smart';
              setState(() => _mode = next);
              await NotificationService.setMode(next);
              await _reschedulePeriods();
            },
          ),
          if (showPeriods) ...[
            const SizedBox(height: 14),
            Text(
              'Khung giờ điểm tin theo 3 buổi sinh hoạt (Sáng - Chiều - Tối):',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            ...NotificationService.dailyPeriods.map((p) {
              final key = p['key']!;
              final label = p['label']!;
              final subtitle = p['subtitle']!;
              final active = _enabledPeriods.contains(key);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.primary.withValues(alpha: 0.12)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? AppTheme.primary : AppTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _togglePeriod(key),
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: active
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            width: 1.5,
                          ),
                        ),
                        child: active
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.bg,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _togglePeriod(key),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _testPush(periodKey: key),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Nghe thử',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_sound),
            initialValue: _sound,
            isExpanded: true,
            dropdownColor: AppTheme.surface,
            style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Âm thanh chuông báo mặc định (Dịu nhẹ, không ồn)',
            ),
            items: NotificationService.soundLabels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) async {
              final next = v ?? 'ting_gentle';
              setState(() => _sound = next);
              await NotificationService.setSound(next);
              await NotificationService.playGentleChime(next);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Giới hạn số thông báo tự động mỗi ngày:',
                    style: GoogleFonts.outfit(
                        fontSize: 12.5, color: AppTheme.textSecondary)),
              ),
              ...[1, 2, 3, 5].map((cnt) {
                final sel = _maxDaily == cnt;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () async {
                      setState(() => _maxDaily = cnt);
                      await NotificationService.setMaxDaily(cnt);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppTheme.primary.withValues(alpha: 0.2)
                            : AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: sel ? AppTheme.primary : AppTheme.border),
                      ),
                      child: Text(
                        '$cnt lần',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: sel ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _testPush(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Nghe thử tiếng Ting và Xem thẻ thông báo động Gen Z',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => NotificationService.scheduleBackgroundDemo(
                    context,
                    simulatedPm25: 21.5,
                    healthGroup: _group == 'all' ? 'binh_thuong' : _group,
                    delaySeconds: 5,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.moderate),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Hẹn 5s báo nền Mức Khá',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.moderate,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => NotificationService.scheduleBackgroundDemo(
                    context,
                    simulatedPm25: 56.8,
                    healthGroup: _group == 'all' ? 'binh_thuong' : _group,
                    delaySeconds: 5,
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.bad),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Hẹn 5s báo nền Mức Cao',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.bad,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = {
      'all': 'Tất cả người dùng',
      for (final k in AppConstants.healthGroups)
        k: AppConstants.healthGroupLabels[k]!,
    };
    final levels = {
      'info': 'Thông tin',
      'warning': 'Cảnh báo',
      'danger': 'Khẩn cấp',
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEngineConfigCard(),
        const SizedBox(height: 22),
        Text('Phát thông báo thủ công hoặc tự động phán đoán theo AQI',
            style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Text(
            'Bạn có thể tự nhập nội dung hoặc bấm nút Phán đoán theo chất lượng không khí hiện tại để soạn nhanh thông điệp phong cách trẻ trung kèm lời khuyên sức khỏe.',
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(_group),
          initialValue: _group,
          dropdownColor: AppTheme.card,
          style: GoogleFonts.outfit(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Đối tượng nhận'),
          items: groups.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _group = v ?? 'all'),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(_level),
          initialValue: _level,
          dropdownColor: AppTheme.card,
          style: GoogleFonts.outfit(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Mức độ'),
          items: levels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _level = v ?? 'info'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _generatingSmart ? null : _fillSmartGenZContent,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.secondary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _generatingSmart
                  ? 'Đang phân tích PM2.5 hiện tại...'
                  : 'Tự phán đoán AQI và Tạo nội dung Gen Z kèm lời khuyên',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppTheme.secondary),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _msgCtrl,
          maxLines: 4,
          maxLength: 300,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Nội dung thông báo',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text('Gửi thông báo',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.bg)),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lịch sử đợt gửi gần đây (${_history.length})',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            TextButton(
              onPressed: _loadHistory,
              child: Text('Làm mới',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          )
        else if (_history.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text('Chưa có thông báo nào được gửi.',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppTheme.textSecondary)),
          )
        else
          ..._history.map((n) {
            final level = n['level']?.toString() ?? 'info';
            final color = _levelColor(level);
            final dt = DateTime.tryParse(n['created_at']?.toString() ?? '')?.toLocal();
            final dateStr = dt == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(dt);
            final read = n['is_read'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_levelLabel(level),
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                      const SizedBox(width: 8),
                      Text(read ? 'Đã đọc' : 'Chưa đọc',
                          style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: read ? AppTheme.good : AppTheme.textSecondary)),
                      const Spacer(),
                      Text(dateStr,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(n['message']?.toString() ?? '',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.5)),
                ],
              ),
            );
          }),
      ],
    );
  }
}
