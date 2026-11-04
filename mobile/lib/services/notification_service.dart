import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../config/theme.dart';
import '../services/air_service.dart';
import 'sound_player.dart';

class NotificationService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static bool isReady = false;
  static RealtimeChannel? _realtimeChannel;
  static String? _listeningUid;

  static const String prefModeKey = 'notif_mode';
  static const String prefSoundKey = 'notif_sound';
  static const String prefMaxDailyKey = 'notif_max_daily';
  static const String prefPeriodsKey = 'notif_periods';
  static const String prefSentDateKey = 'notif_sent_date';
  static const String prefSentCountKey = 'notif_sent_count';

  static const Map<String, String> modeLabels = {
    'smart': 'Tự động thông minh (Báo từ mức Khá > 15 ug/m3 đến mức Cao)',
    'periods': 'Báo theo 3 buổi sinh hoạt (Sáng, Chiều, Tối)',
    'aqi_only': 'Chỉ báo theo ngưỡng ô nhiễm (Từ mức Khá đến mức Cao)',
  };

  static const Map<String, String> periodLabels = {
    'morning': 'Buổi sáng (07:00 - Trước giờ đi học / đi làm)',
    'afternoon': 'Buổi chiều (17:00 - Giờ tan tầm / thể thao)',
    'night': 'Buổi tối (21:00 - Cảnh báo nghịch nhiệt đêm & dự báo mai)',
  };

  static const List<Map<String, String>> dailyPeriods = [
    {
      'key': 'morning',
      'label': 'Buổi sáng (07:00)',
      'subtitle': 'Trước giờ đi học, đi làm - Kiểm tra sương mù tích tụ bụi sáng sớm',
    },
    {
      'key': 'afternoon',
      'label': 'Buổi chiều (17:00)',
      'subtitle': 'Giờ tan tầm và thể thao - Gợi ý khung giờ chạy bộ hoặc đeo khẩu trang',
    },
    {
      'key': 'night',
      'label': 'Buổi tối (21:00)',
      'subtitle': 'Trước giờ nghỉ ngơi - Cảnh báo nghịch nhiệt đêm và dự báo sáng mai',
    },
  ];

  static const Map<String, String> soundLabels = {
    'ting_gentle': 'Tiếng Ting dịu nhẹ (Chuẩn Gen Z)',
    'chime_breeze': 'Chuông gió thanh mát (Breeze Chime)',
    'crystal_drop': 'Giọt sương trong trẻo (Crystal Drop)',
    'silent': 'Im lặng (Chỉ hiện ảnh động, không kêu)',
  };

  static Future<void> init() async {
    if (kIsWeb) {
      isReady = true;
      return;
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidImpl = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    isReady = true;
  }

  static Future<String> getMode() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(prefModeKey) ?? 'smart';
    if (!modeLabels.containsKey(saved)) return 'smart';
    return saved;
  }

  static Future<void> setMode(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(prefModeKey, mode);
  }

  static Future<Set<String>> getEnabledPeriods() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(prefPeriodsKey);
    if (list == null || list.isEmpty) {
      return {'morning', 'afternoon', 'night'};
    }
    return list.toSet();
  }

  static Future<void> setEnabledPeriods(Set<String> periods) async {
    final p = await SharedPreferences.getInstance();
    final safe = periods.isEmpty ? {'morning'} : periods;
    await p.setStringList(prefPeriodsKey, safe.toList());
  }

  static Future<String> getSound() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(prefSoundKey) ?? 'ting_gentle';
  }

  static Future<void> setSound(String sound) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(prefSoundKey, sound);
  }

  static Future<int> getMaxDaily() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(prefMaxDailyKey) ?? 3;
  }

  static Future<void> setMaxDaily(int maxCount) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(prefMaxDailyKey, maxCount.clamp(1, 5));
  }

  static Future<int> getTodaySentCount() async {
    final p = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = p.getString(prefSentDateKey) ?? '';
    if (savedDate != today) {
      await p.setString(prefSentDateKey, today);
      await p.setInt(prefSentCountKey, 0);
      return 0;
    }
    return p.getInt(prefSentCountKey) ?? 0;
  }

  static Future<bool> _canSendAutoNotification() async {
    final sent = await getTodaySentCount();
    final maxCount = await getMaxDaily();
    return sent < maxCount;
  }

  static Future<void> _incrementSentCount() async {
    final p = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final current = await getTodaySentCount();
    await p.setString(prefSentDateKey, today);
    await p.setInt(prefSentCountKey, current + 1);
  }

  static Future<void> playGentleChime([String? soundKey]) async {
    final key = soundKey ?? await getSound();
    await SoundPlayer.play(key);
  }

  static String currentPeriodKey() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'morning';
    if (h >= 12 && h < 18) return 'afternoon';
    return 'night';
  }

  static Map<String, String> buildGenZMessage({
    required double pm25,
    required String healthGroup,
    String? periodKey,
    String? customMessage,
    String? customLevel,
    double? minPm25,
    double? maxPm25,
    String? timeLabel,
  }) {
    final air = AirService();
    final lvl = customLevel ?? air.getAqiLevel(pm25);
    final pKey = periodKey ?? currentPeriodKey();
    final isResp = healthGroup == 'benh_ho_hap' || healthGroup == 'hen_suyen';
    final isAge = healthGroup == 'tre_em';
    final isOutdoor = healthGroup == 'van_dong';
    final sensitive = isResp || isAge;

    final lowVal = minPm25 ?? math.max(6.0, pm25 * 0.78);
    final highVal = maxPm25 ?? math.max(pm25 * 1.18, pm25 + 4.0);
    final rangeStr = '${lowVal.round()} - ${highVal.round()}';
    final dateStr = DateFormat('dd/MM').format(DateTime.now());
    final dateMeta = '$dateStr (Thủ Dầu Một - QCVN)';

    String periodTimeTag = timeLabel ?? 'Vừa xong';
    if (timeLabel == null) {
      if (pKey == 'morning') periodTimeTag = '07:00 Sáng';
      if (pKey == 'afternoon') periodTimeTag = '17:00 Chiều';
      if (pKey == 'night') periodTimeTag = '21:00 Tối';
    }

    String statusText = 'Không khí Tốt';
    if (lvl == 'trung_binh' || lvl == 'info') {
      statusText = lvl == 'info' && pm25 <= 15 ? 'Không khí Tốt' : 'Mức Khá (Trung bình)';
    } else if (lvl == 'kem' || lvl == 'warning') {
      statusText = 'Ô nhiễm Kém';
    } else if (lvl == 'xau' || lvl == 'danger') {
      statusText = 'Ô nhiễm Mức Cao';
    }

    String greetingPrefix = 'Chào ngày mới, chất lượng không khí TP. Thủ Dầu Một';
    if (pKey == 'afternoon') {
      greetingPrefix = 'Bản tin chiều, chất lượng không khí TP. Thủ Dầu Một';
    } else if (pKey == 'night') {
      greetingPrefix = 'Bản tin tối, chất lượng không khí TP. Thủ Dầu Một';
    }

    if (customMessage != null && customMessage.isNotEmpty) {
      String tip =
          'Ghi chú nhỏ: Mở mục Bản tin hoặc Dự báo để xem biểu đồ chi tiết 24h tại Thủ Dầu Một nhé.';
      if (lvl == 'danger' || lvl == 'xau') {
        tip =
            'Lời khuyên: Đeo ngay khẩu trang KN95/N95 và hạn chế ra đường nếu không gấp nha.';
      } else if (lvl == 'warning' || lvl == 'kem') {
        tip =
            'Lời khuyên: Ra đường nhớ trang bị khẩu trang lọc bụi mịn để bảo vệ hệ hô hấp nhé.';
      }
      return {
        'title': customMessage,
        'body': customMessage,
        'tip': tip,
        'level': lvl,
        'period': pKey,
        'range': rangeStr,
        'unit': 'ug/m3',
        'status_text': statusText,
        'date_meta': dateMeta,
        'time_tag': periodTimeTag,
      };
    }

    if (lvl == 'tot') {
      final summary =
          '$greetingPrefix đang ở mức Tốt (${pm25.toStringAsFixed(1)} ug/m3), bầu trời thoáng sạch.';
      final body = pKey == 'morning'
          ? 'Chào ngày mới, không khí TP. Thủ Dầu Một rất trong lành (${pm25.toStringAsFixed(1)} ug/m3). Thời điểm lý tưởng để mở cửa đón gió sớm, đi học và đi làm!'
          : pKey == 'afternoon'
              ? 'Chiều mát lành tại TP. Thủ Dầu Một! Chỉ số bụi mịn thấp (${pm25.toStringAsFixed(1)} ug/m3), rất thuận lợi để chạy bộ và dạo phố.'
              : 'Tối nay không khí TP. Thủ Dầu Một thoáng đãng (${pm25.toStringAsFixed(1)} ug/m3), dễ chịu để nghỉ ngơi.';
      return {
        'title': summary,
        'body': body,
        'tip': 'Khuyến nghị: Tranh thủ vận động ngoài trời và thông gió tự nhiên cho nhà cửa trong khung giờ sạch này nhé.',
        'level': 'tot',
        'period': pKey,
        'range': rangeStr,
        'unit': 'ug/m3',
        'status_text': 'Không khí Tốt',
        'date_meta': dateMeta,
        'time_tag': periodTimeTag,
      };
    }

    if (lvl == 'trung_binh') {
      final summary =
          '$greetingPrefix ở ngưỡng Mức Khá (${pm25.toStringAsFixed(1)} ug/m3), cần lưu ý nhẹ.';
      final body = pKey == 'morning'
          ? 'Thông báo mức Khá: Không khí TP. Thủ Dầu Một ở ngưỡng trung bình khá (${pm25.toStringAsFixed(1)} ug/m3), thuận lợi đi học, đi làm nhưng nhóm nhạy cảm nên chú ý.'
          : pKey == 'afternoon'
              ? 'Thông báo mức Khá: Chiều nay tại TP. Thủ Dầu Một PM2.5 ở mức trung bình khá (${pm25.toStringAsFixed(1)} ug/m3).'
              : 'Thông báo mức Khá: Tối nay tại TP. Thủ Dầu Một không khí ở ngưỡng trung bình khá (${pm25.toStringAsFixed(1)} ug/m3).';
      return {
        'title': summary,
        'body': body,
        'tip': isOutdoor
            ? 'Lời khuyên vận động: Bạn có thể tập thể thao bình thường nhưng nên ưu tiên công viên cây xanh, tránh chạy sát quốc lộ lớn.'
            : sensitive
                ? 'Lời khuyên sức khỏe: Nhóm nhạy cảm nên đem theo nước ấm, thuốc dự phòng và hạn chế đứng lâu ở ngã tư đông xe.'
                : 'Lời khuyên: Đeo khẩu trang nhẹ khi di chuyển qua các trục đường đông xe giờ cao điểm.',
        'level': 'trung_binh',
        'period': pKey,
        'range': rangeStr,
        'unit': 'ug/m3',
        'status_text': 'Mức Khá (Trung bình)',
        'date_meta': dateMeta,
        'time_tag': periodTimeTag,
      };
    }

    if (lvl == 'kem') {
      final summary =
          '$greetingPrefix chuyển sang Ô nhiễm Kém (${pm25.toStringAsFixed(1)} ug/m3), nhớ đeo khẩu trang.';
      final body = pKey == 'morning'
          ? 'Cảnh báo ô nhiễm: Sáng sớm tại TP. Thủ Dầu Một có lớp sương giữ bụi mịn ở mức Kém (${pm25.toStringAsFixed(1)} ug/m3). Ra đường sáng nay nhớ che chắn kỹ!'
          : pKey == 'afternoon'
              ? 'Cảnh báo ô nhiễm: Giờ tan tầm chiều tại TP. Thủ Dầu Một mật độ giao thông cao làm PM2.5 tăng lên mức Kém (${pm25.toStringAsFixed(1)} ug/m3).'
              : 'Cảnh báo ô nhiễm: Tối nay tại TP. Thủ Dầu Một hiện tượng nghịch nhiệt giữ bụi mịn ở mức Kém (${pm25.toStringAsFixed(1)} ug/m3), nên đóng bớt cửa sổ hướng ra đường lớn.';
      return {
        'title': summary,
        'body': body,
        'tip': isOutdoor
            ? 'Lời khuyên vận động: Khi chạy bộ lượng khí hít vào tăng gấp 3-5 lần, hãy giảm cường độ ngoài trời hoặc chuyển vào phòng tập.'
            : isResp
                ? 'Lời khuyên hô hấp: Người có bệnh hô hấp và hen suyễn cần mang sẵn thuốc dự phòng và đeo khẩu trang KN95 khi ra đường.'
                : isAge
                    ? 'Lời khuyên gia đình: Hạn chế để trẻ nhỏ và người cao tuổi hoạt động ngoài trời lúc sáng sớm hoặc tối muộn.'
                    : 'Lời khuyên: Đeo khẩu trang chống bụi mịn KN95 khi đi đường và vệ sinh mũi họng bằng nước muối sinh lý.',
        'level': 'kem',
        'period': pKey,
        'range': rangeStr,
        'unit': 'ug/m3',
        'status_text': 'Ô nhiễm Kém',
        'date_meta': dateMeta,
        'time_tag': periodTimeTag,
      };
    }

    final summary =
        'Cảnh báo tại TP. Thủ Dầu Một: Bụi mịn vượt ngưỡng Ô nhiễm Mức Cao (${pm25.toStringAsFixed(1)} ug/m3)!';
    return {
      'title': summary,
      'body': 'Cảnh báo Ô nhiễm Mức Cao: Chất lượng không khí tại TP. Thủ Dầu Một đang ở mức Xấu (${pm25.toStringAsFixed(1)} ug/m3). Ưu tiên sinh hoạt trong nhà và đóng kín cửa sổ.',
      'tip': 'Khuyến nghị khẩn: Bật máy lọc không khí nếu có và bắt buộc đeo khẩu trang N95/KN95 khi phải di chuyển ngoài đường.',
      'level': 'xau',
      'period': pKey,
      'range': rangeStr,
      'unit': 'ug/m3',
      'status_text': 'Ô nhiễm Mức Cao',
      'date_meta': dateMeta,
      'time_tag': periodTimeTag,
    };
  }

  static void listenAdminNotifications([BuildContext? context]) {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    if (_listeningUid == uid && _realtimeChannel != null) return;

    _realtimeChannel?.unsubscribe();
    _listeningUid = uid;

    _realtimeChannel = client
        .channel('user_notifications_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            final msg = row['message']?.toString() ?? '';
            final level = row['level']?.toString() ?? 'info';
            if (msg.isEmpty) return;

            final genz = buildGenZMessage(
              pm25: 28.0,
              healthGroup: 'binh_thuong',
              customMessage: msg,
              customLevel: level,
            );

            await playGentleChime();
            await show(
              id: DateTime.now().millisecondsSinceEpoch % 100000,
              title: '${genz['range']} ug/m3 | ${genz['status_text']}',
              body: '${genz['body']!} ${genz['tip']!}',
            );
          },
        )
        .subscribe();
  }

  static Future<void> schedule12hNoon(List<double> forecast, double currentPm25) async {
    await scheduleDailyPeriods(forecast, currentPm25);
  }

  static Future<void> scheduleDailyPeriods(
    List<double> forecast,
    double currentPm25, {
    String healthGroup = 'binh_thuong',
  }) async {
    if (kIsWeb || !isReady) return;
    final mode = await getMode();
    await plugin.cancel(3);
    await plugin.cancel(4);
    await plugin.cancel(5);

    if (mode == 'aqi_only') return;

    final enabled = await getEnabledPeriods();
    final soundKey = await getSound();
    final playSound = soundKey != 'silent';
    final now = tz.TZDateTime.now(tz.local);

    final minFc = forecast.isNotEmpty ? forecast.reduce(math.min) : currentPm25 * 0.8;
    final maxFc = forecast.isNotEmpty ? forecast.reduce(math.max) : currentPm25 * 1.2;

    final slots = [
      (3, 'morning', 7),
      (4, 'afternoon', 17),
      (5, 'night', 21),
    ];

    for (final s in slots) {
      if (!enabled.contains(s.$2)) continue;
      tz.TZDateTime target =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, s.$3, 0);
      if (now.isAfter(target)) {
        target = target.add(const Duration(days: 1));
      }
      final diffHours = target.difference(now).inHours.clamp(0, 23);
      final predictedPm =
          (forecast.isNotEmpty && diffHours < forecast.length)
              ? forecast[diffHours]
              : currentPm25;
      final genz = buildGenZMessage(
        pm25: predictedPm,
        healthGroup: healthGroup,
        periodKey: s.$2,
        minPm25: minFc,
        maxPm25: maxFc,
      );

      final notifTitle =
          '${genz['range']} ug/m3 | ${genz['status_text']} - ${genz['date_meta']}';

      try {
        await plugin.zonedSchedule(
          s.$1,
          notifTitle,
          '${genz['body']!} ${genz['tip']!}',
          target,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'appair_period_$soundKey',
              'Thông báo 3 buổi Sáng - Chiều - Tối',
              channelDescription: 'Báo cáo chất lượng không khí theo buổi sinh hoạt',
              importance: Importance.high,
              priority: Priority.high,
              playSound: playSound,
              sound:
                  playSound ? RawResourceAndroidNotificationSound(soundKey) : null,
              styleInformation:
                  BigTextStyleInformation('${genz['body']!} ${genz['tip']!}'),
            ),
            iOS: DarwinNotificationDetails(presentSound: playSound),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (_) {}
    }
  }

  static Future<void> checkAndNotify(double pm25, String healthGroup, [BuildContext? context]) async {
    final mode = await getMode();
    if (mode == 'periods') return;

    final p = await SharedPreferences.getInstance();
    final thresholdKey = p.getString('user_pm_threshold') ?? 'tb_15';
    if (thresholdKey == 'off') return;

    double minPm = 15.0;
    if (thresholdKey == 'kem_25') minPm = 25.0;
    if (thresholdKey == 'xau_50') minPm = 50.0;
    if (pm25 <= minPm) return;

    if (!await _canSendAutoNotification()) return;
    await _incrementSentCount();

    final genz = buildGenZMessage(pm25: pm25, healthGroup: healthGroup);
    await playGentleChime();
    await show(
      id: 1,
      title: '${genz['range']} ug/m3 | ${genz['status_text']} - ${genz['date_meta']}',
      body: '${genz['body']!} ${genz['tip']!}',
    );
  }

  static Future<void> forecastNotify(List<double> forecast) async {
    if (!isReady) return;
    final mode = await getMode();
    if (mode == 'periods') return;

    final p = await SharedPreferences.getInstance();
    final peakEnabled = p.getBool('user_forecast_peak_alert') ?? true;
    if (!peakEnabled) return;

    final air = AirService();
    int alertHours = 0;
    int firstAlertIndex = -1;
    double maxVal = 0;

    for (int i = 0; i < forecast.length; i++) {
      if (forecast[i] > maxVal) maxVal = forecast[i];
      final lv = air.getAqiLevel(forecast[i]);
      if (lv == 'trung_binh' || lv == 'kem' || lv == 'xau') {
        alertHours++;
        if (firstAlertIndex == -1) firstAlertIndex = i;
      }
    }

    if (alertHours == 0 || firstAlertIndex == -1) return;
    if (!await _canSendAutoNotification()) return;
    await _incrementSentCount();

    final minFc = forecast.reduce(math.min);
    final maxFc = forecast.reduce(math.max);
    final alertDt = DateTime.now().add(Duration(hours: firstAlertIndex + 1));
    final hour = alertDt.hour.toString().padLeft(2, '0');
    final dateStr = DateFormat('dd/MM').format(DateTime.now());
    final statusLbl = maxVal > 50
        ? 'Ô nhiễm Mức Cao'
        : (maxVal > 25 ? 'Ô nhiễm Kém' : 'Mức Khá (Trung bình)');

    await show(
      id: 2,
      title: '${minFc.round()} - ${maxFc.round()} ug/m3 | Dự báo $statusLbl - $dateStr',
      body: 'Dự kiến từ khoảng $hour:00 tại TP. Thủ Dầu Một, PM2.5 ở ngưỡng $statusLbl (${maxVal.toStringAsFixed(1)} ug/m3). Nhớ chủ động bảo vệ hô hấp nhé.',
    );
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      await SoundPlayer.showWebNotification(title, body);
      return;
    }
    if (!isReady) return;
    final soundKey = await getSound();
    final playSound = soundKey != 'silent';

    final android = AndroidNotificationDetails(
      'appair_channel_$soundKey',
      'AppAir Cảnh báo Thông minh',
      channelDescription: 'Thông báo chất lượng không khí từ mức Khá đến mức Cao',
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      sound: playSound ? RawResourceAndroidNotificationSound(soundKey) : null,
      styleInformation: BigTextStyleInformation(body),
    );
    final ios = DarwinNotificationDetails(presentSound: playSound);
    await plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: android, iOS: ios),
    );
  }

  static Future<void> scheduleBackgroundDemo(
    BuildContext context, {
    required double simulatedPm25,
    required String healthGroup,
    int delaySeconds = 5,
  }) async {
    await SoundPlayer.requestWebPermission();
    final soundKey = await getSound();
    final soundName = soundLabels[soundKey] ?? 'Tiếng Ting dịu nhẹ';
    final genz = buildGenZMessage(
      pm25: simulatedPm25,
      healthGroup: healthGroup,
      minPm25: math.max(10.0, simulatedPm25 * 0.78),
      maxPm25: simulatedPm25 * 1.18,
      timeLabel: 'Chạy ngầm',
    );
    final notifTitle =
        '${genz['range']} ug/m3 | ${genz['status_text']} - ${genz['date_meta']}';
    final notifBody = '${genz['body']!} ${genz['tip']!}';

    if (!kIsWeb && isReady) {
      try {
        final playSound = soundKey != 'silent';
        final target =
            tz.TZDateTime.now(tz.local).add(Duration(seconds: delaySeconds));
        await plugin.zonedSchedule(
          888,
          notifTitle,
          notifBody,
          target,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'appair_bg_demo_$soundKey',
              'Cảnh báo nền khi đóng ứng dụng',
              channelDescription:
                  'Thông báo tự động từ mức Khá đến mức Cao khi chưa mở ứng dụng',
              importance: Importance.max,
              priority: Priority.high,
              playSound: playSound,
              sound:
                  playSound ? RawResourceAndroidNotificationSound(soundKey) : null,
              styleInformation: BigTextStyleInformation(notifBody),
            ),
            iOS: DarwinNotificationDetails(presentSound: playSound),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: delaySeconds),
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(
            'Đã hẹn thông báo nền sau $delaySeconds giây (${genz['status_text']} - ${simulatedPm25.toStringAsFixed(1)} ug/m3). Hãy thu nhỏ hoặc ẩn ứng dụng ngay để kiểm tra!',
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    Timer(Duration(seconds: delaySeconds), () async {
      await playGentleChime(soundKey);
      await show(
        id: 889,
        title: notifTitle,
        body: notifBody,
      );
      if (context.mounted) {
        showAnimatedPopup(
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
          timeTag: 'Báo nền tự động',
        );
      }
    });
  }

  static void showAnimatedPopup(
    BuildContext context, {
    required String title,
    required String body,
    required String tip,
    required String level,
    required String soundName,
    String? periodKey,
    String? rangeText,
    String? statusText,
    String? dateMeta,
    String? timeTag,
  }) {
    playGentleChime();
    final fallback = buildGenZMessage(
      pm25: level == 'xau' || level == 'danger'
          ? 56.0
          : (level == 'kem' || level == 'warning'
              ? 34.0
              : (level == 'trung_binh' ? 21.0 : 12.0)),
      healthGroup: 'binh_thuong',
      periodKey: periodKey,
      customMessage: body,
      customLevel: level,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 44, 14, 0),
            child: Material(
              color: Colors.transparent,
              child: AppAirNotificationCard(
                title: title,
                body: body,
                tip: tip,
                level: level,
                periodKey: periodKey ?? currentPeriodKey(),
                rangeText: rangeText ?? fallback['range']!,
                statusText: statusText ?? fallback['status_text']!,
                dateMeta: dateMeta ?? fallback['date_meta']!,
                timeTag: timeTag ?? fallback['time_tag']!,
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.8),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }
}

class AppAirNotificationCard extends StatefulWidget {
  final String title;
  final String body;
  final String tip;
  final String level;
  final String periodKey;
  final String rangeText;
  final String statusText;
  final String dateMeta;
  final String timeTag;
  final VoidCallback? onClose;
  final bool initiallyExpanded;

  const AppAirNotificationCard({
    super.key,
    required this.title,
    required this.body,
    required this.tip,
    required this.level,
    required this.periodKey,
    required this.rangeText,
    required this.statusText,
    required this.dateMeta,
    required this.timeTag,
    this.onClose,
    this.initiallyExpanded = false,
  });

  @override
  State<AppAirNotificationCard> createState() => _AppAirNotificationCardState();
}

class _AppAirNotificationCardState extends State<AppAirNotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _accent {
    if (widget.level == 'xau' || widget.level == 'danger') return AppTheme.bad;
    if (widget.level == 'kem' || widget.level == 'warning') return AppTheme.poor;
    if (widget.level == 'trung_binh') return AppTheme.moderate;
    return AppTheme.good;
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final c = _accent;
    return GestureDetector(
      onTap: _toggleExpand,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF242936),
              Color(0xFF1A1E29),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: c.withValues(alpha: _expanded ? 0.65 : 0.32),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 22,
              offset: const Offset(0, 8),
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
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Air',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'AppAir',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD1D5DB),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9CA3AF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.timeTag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      CustomPaint(
                        size: const Size(11, 12),
                        painter: _MiniBellPainter(
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    size: const Size(10, 6),
                    painter: _TriangleTogglePainter(
                      expanded: _expanded,
                      color: const Color(0xFFD1D5DB),
                    ),
                  ),
                ),
                if (widget.onClose != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Đóng',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD1D5DB),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 66,
                  height: 52,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _ctrl,
                          builder: (_, __) => CustomPaint(
                            painter: _AirWeatherGraphicPainter(
                              progress: _ctrl.value,
                              accent: c,
                              periodKey: widget.periodKey,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: -1,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            'Air',
                            style: GoogleFonts.outfit(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.rangeText,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ug/m3',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1.2,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 11),
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.dateMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Text(
                widget.body,
                maxLines: _expanded ? 4 : 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFFE5E7EB),
                  height: 1.4,
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.withValues(alpha: 0.38)),
                  ),
                  child: Text(
                    widget.tip,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriangleTogglePainter extends CustomPainter {
  final bool expanded;
  final Color color;

  const _TriangleTogglePainter({
    required this.expanded,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (expanded) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TriangleTogglePainter oldDelegate) =>
      oldDelegate.expanded != expanded || oldDelegate.color != color;
}

class _MiniBellPainter extends CustomPainter {
  final Color color;
  const _MiniBellPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final bellPath = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..cubicTo(w * 0.22, h * 0.08, w * 0.18, h * 0.42, w * 0.18, h * 0.65)
      ..lineTo(w * 0.08, h * 0.78)
      ..lineTo(w * 0.92, h * 0.78)
      ..lineTo(w * 0.82, h * 0.65)
      ..cubicTo(w * 0.82, h * 0.42, w * 0.78, h * 0.08, w * 0.5, h * 0.08)
      ..close();
    canvas.drawPath(bellPath, p);
    canvas.drawCircle(Offset(w * 0.5, h * 0.89), w * 0.13, p);
  }

  @override
  bool shouldRepaint(covariant _MiniBellPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _AirWeatherGraphicPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final String periodKey;

  const _AirWeatherGraphicPainter({
    required this.progress,
    required this.accent,
    required this.periodKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sunCenter = Offset(
      size.width * 0.62,
      size.height * 0.44 + math.sin(progress * math.pi * 2) * 1.5,
    );
    final sunRadius = size.height * 0.36;

    final glowPaint = Paint()
      ..color = (periodKey == 'night'
              ? const Color(0xFF60A5FA)
              : const Color(0xFFFBBF24))
          .withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(sunCenter, sunRadius * 1.15, glowPaint);

    final sunShader = RadialGradient(
      colors: periodKey == 'night'
          ? [const Color(0xFFFEF08A), const Color(0xFFF59E0B)]
          : [const Color(0xFFFDE047), const Color(0xFFF59E0B)],
    ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));
    canvas.drawCircle(sunCenter, sunRadius, Paint()..shader = sunShader);

    final cloudPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.48,
        size.width * 0.62,
        size.height * 0.36,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(baseRect, cloudPaint);
    canvas.drawCircle(
      Offset(size.width * 0.26, size.height * 0.48),
      size.height * 0.24,
      cloudPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.46, size.height * 0.52),
      size.height * 0.20,
      cloudPaint,
    );

    final wavePaint = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final waveY = size.height * 0.90;
    final path = Path()
      ..moveTo(size.width * 0.10, waveY)
      ..quadraticBezierTo(
        size.width * 0.28,
        waveY - 3.0 * math.sin(progress * math.pi * 2),
        size.width * 0.45,
        waveY,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        waveY + 3.0 * math.sin(progress * math.pi * 2),
        size.width * 0.68,
        waveY,
      );
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _AirWeatherGraphicPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
