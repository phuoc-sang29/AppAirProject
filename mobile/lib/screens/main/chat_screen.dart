import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/air_service.dart';
import '../../services/auth_service.dart';

String _buildSystemPrompt({
  Map<String, dynamic>? current,
  String? aqiLabel,
  String? aqiLevel,
  List<double>? forecast,
  double? rmse,
  double? mae,
  String? userHealthGroup,
}) {
  final nowDt = DateTime.now();
  final now = DateFormat('HH:mm dd/MM/yyyy').format(nowDt);
  final pm25 = (current?['pm2_5'] as num?)?.toDouble();
  final pm10 = (current?['pm10'] as num?)?.toDouble();
  final co = (current?['carbon_monoxide'] as num?)?.toDouble();
  final no2 = (current?['nitrogen_dioxide'] as num?)?.toDouble();
  final so2 = (current?['sulphur_dioxide'] as num?)?.toDouble();
  final o3 = (current?['ozone'] as num?)?.toDouble();

  String dataBlock;
  if (pm25 != null) {
    double? peak;
    double? lowest;
    int? peakIdx;
    int? lowestIdx;
    final hourlyLines = <String>[];

    if (forecast != null && forecast.isNotEmpty) {
      peak = forecast.first;
      lowest = forecast.first;
      peakIdx = 0;
      lowestIdx = 0;
      for (int i = 0; i < forecast.length; i++) {
        final v = forecast[i];
        if (v > peak!) {
          peak = v;
          peakIdx = i;
        }
        if (v < lowest!) {
          lowest = v;
          lowestIdx = i;
        }
        final slotDt = nowDt.add(Duration(hours: i + 1));
        final slotStr = DateFormat('HH:00 dd/MM').format(slotDt);
        hourlyLines.add('$slotStr: ${v.toStringAsFixed(1)} µg/m³');
      }
    }

    final peakTimeStr = peakIdx != null
        ? DateFormat('HH:00 dd/MM').format(nowDt.add(Duration(hours: peakIdx + 1)))
        : '';
    final lowestTimeStr = lowestIdx != null
        ? DateFormat('HH:00 dd/MM').format(nowDt.add(Duration(hours: lowestIdx + 1)))
        : '';
    final trend = (forecast != null && forecast.isNotEmpty)
        ? (forecast.last > pm25 ? 'có xu hướng tăng' : 'có xu hướng giảm')
        : '';
    final groupLabel = userHealthGroup != null
        ? (AppConstants.healthGroupLabels[userHealthGroup] ?? userHealthGroup)
        : 'Chưa xác định';

    dataBlock = '''

=== DỮ LIỆU THỰC TẾ TẠI THỦ DẦU MỘT (thời điểm hiện tại: $now) ===
- Nhóm sức khỏe của người dùng đang hỏi: $groupLabel
- Chỉ số hiện tại:
  + PM2.5: ${pm25.toStringAsFixed(1)} µg/m³ (Mức AQI: $aqiLabel)
  + PM10: ${pm10?.toStringAsFixed(1) ?? 'N/A'} µg/m³
  + CO: ${co?.toStringAsFixed(1) ?? 'N/A'} µg/m³ | NO2: ${no2?.toStringAsFixed(1) ?? 'N/A'} µg/m³
  + SO2: ${so2?.toStringAsFixed(1) ?? 'N/A'} µg/m³ | O3: ${o3?.toStringAsFixed(1) ?? 'N/A'} µg/m³
- Tổng quan dự báo 24h tới (Mô hình 1D-CNN + LSTM):
  + Xu hướng chung: $trend
  ${peak != null ? '+ Giờ ô nhiễm cao nhất: ${peak.toStringAsFixed(1)} µg/m³ lúc $peakTimeStr (+${peakIdx! + 1}h)' : ''}
  ${lowest != null ? '+ Giờ không khí sạch nhất: ${lowest.toStringAsFixed(1)} µg/m³ lúc $lowestTimeStr (+${lowestIdx! + 1}h)' : ''}
  ${rmse != null ? '+ Sai số mô hình trên tập kiểm thử: RMSE = ${rmse.toStringAsFixed(2)} µg/m³${mae != null ? ', MAE = ${mae.toStringAsFixed(2)} µg/m³' : ''}' : ''}
- Chi tiết dự báo PM2.5 từng giờ trong 24 giờ tới:
  ${hourlyLines.join(' | ')}
===''';
  } else {
    dataBlock =
        '\n(Chú ý: Hiện không lấy được dữ liệu thời gian thực. Hãy trả lời theo kiến thức chung.)';
  }

  return '''
Bạn là trợ lý AI chuyên gia của ứng dụng AppAir — hệ thống giám sát và dự báo chất lượng không khí tại TP. Thủ Dầu Một, Bình Dương.
$dataBlock

Ngưỡng phân loại PM2.5 áp dụng trong AppAir & tiêu chuẩn đối chiếu:
- Thang AppAir: Tốt (0–12 µg/m³), Trung bình (12–35 µg/m³), Kém (35–55 µg/m³ - nhóm nhạy cảm hạn chế ra ngoài), Xấu (55–150 µg/m³ - tránh ra ngoài), Rất xấu (>150 µg/m³ - nguy hiểm).
- Quy chuẩn Việt Nam QCVN 05:2023/BTNMT: trung bình 24 giờ của PM2.5 không vượt 50 µg/m³ (trung bình năm 25 µg/m³); PM10 trung bình 24 giờ không vượt 100 µg/m³.
- Khuyến nghị WHO (2021): PM2.5 trung bình 24 giờ không vượt 15 µg/m³ (trung bình năm 5 µg/m³).

Bạn có thể trả lời sâu các nhóm câu hỏi sau:
1. TÌNH TRẠNG HIỆN TẠI: Phân tích cả 6 chất (PM2.5, PM10, CO, NO2, SO2, O3), mức độ an toàn, so sánh với ngưỡng QCVN 05:2023 và WHO.
2. DỰ BÁO THEO GIỜ CỤ THỂ: Khi người dùng hỏi một giờ cụ thể (ví dụ 7h sáng mai, chiều tối nay, khung giờ tập thể dục), hãy tra cứu chính xác mốc giờ đó trong danh sách 24 giờ dự báo ở trên để nêu con số PM2.5 dự báo, mức cảnh báo và gợi ý khung giờ sạch nhất thay thế nếu giờ đó ô nhiễm cao.
3. SỨC KHỎE CÁ NHÂN HÓA: Tư vấn chi tiết cho từng nhóm (trẻ em, người cao tuổi, người bệnh hô hấp/hen suyễn/COPD, tim mạch, người tập thể thao ngoài trời) như loại khẩu trang (N95/KN95 hay y tế), thuốc dự phòng mang theo, cường độ vận động, thời gian mở cửa sổ thông gió.
4. NGUỒN Ô NHIỄM & ĐẶC THÙ BÌNH DƯƠNG: Hoạt động khu công nghiệp (VSIP, Sóng Thần, Đại Đăng...), mật độ giao thông Quốc lộ 13, Mỹ Phước - Tân Vạn, hiện tượng nghịch nhiệt sáng sớm và chiều tối.
5. MÔ HÌNH AI & ỨNG DỤNG APPAIR: Giải thích cách mô hình 1D-CNN + LSTM học từ 24 giờ lịch sử (6 thông số) để dự báo 24 giờ kế tiếp, ý nghĩa sai số RMSE/MAE.

Quy tắc phản hồi:
- Luôn trả lời tiếng Việt có dấu đầy đủ, rõ ràng, súc tích, chia ý dễ đọc.
- Bắt buộc trích dẫn con số PM2.5 thực tế hoặc con số tại đúng mốc giờ dự báo khi dữ liệu có sẵn.
- Với câu hỏi liên quan đến bệnh lý (hô hấp, hen suyễn, tim mạch): luôn kèm câu lưu ý "Thông tin chỉ mang tính tham khảo, người bệnh nên tuân thủ chỉ định của bác sĩ."
- Câu hỏi hoàn toàn ngoài chủ đề không khí, môi trường, sức khỏe hoặc ứng dụng AppAir: từ chối lịch sự và hướng người dùng quay lại chủ đề chất lượng không khí.
''';
}


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageInput = TextEditingController();
  final scrollController = ScrollController();
  final List<ChatMessage> chatList = [];
  bool isLoading = false;
  bool keyIsValid = true;
  ChatSession? chatSession;
  String? _cachedPrompt;
  final _air = AirService();
  final _auth = AuthService();

  static int _keyIndex = 0;
  static int _modelIndex = 0;

  static List<String> get _allKeys {
    final keys = <String>[];
    for (int i = 1; i <= 4; i++) {
      final k = dotenv.env['GEMINI_API_KEY_$i']?.trim() ?? '';
      if (k.isNotEmpty) keys.add(k);
    }
    if (keys.isEmpty) {
      final legacy = dotenv.env['GEMINI_API_KEY'] ?? '';
      keys.addAll(legacy.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    }
    return keys;
  }

  @override
  void initState() {
    super.initState();
    _initWithContext();
    addWelcomeMessage();
  }

  Future<void> _initWithContext() async {
    Map<String, dynamic>? current;
    Map<String, dynamic>? forecast;
    Map<String, dynamic>? profile;
    try {
      final res = await Future.wait([
        _air.getCurrent(),
        _air.getForecast(),
        _auth.getUserProfile(),
      ]).timeout(const Duration(seconds: 5));
      current = res[0];
      forecast = res[1];
      profile = res[2];
    } catch (_) {}

    final pm25 = (current?['pm2_5'] as num?)?.toDouble();
    final forecastList = (forecast?['forecast_pm2_5'] as List?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    final rmse = (forecast?['rmse'] as num?)?.toDouble();
    final mae = (forecast?['mae'] as num?)?.toDouble();
    final healthGroup = profile?['health_group']?.toString();

    _cachedPrompt = _buildSystemPrompt(
      current: current,
      aqiLabel: pm25 != null ? _air.getAqiLabel(pm25) : null,
      aqiLevel: pm25 != null ? _air.getAqiLevel(pm25) : null,
      forecast: forecastList,
      rmse: rmse,
      mae: mae,
      userHealthGroup: healthGroup,
    );
    setupGemini(promptOverride: _cachedPrompt);
  }

  static const _models = [
    'gemini-2.5-flash',
    'gemini-flash-latest',
    'gemini-flash-lite-latest',
  ];

  void setupGemini({int keyIdx = 0, int modelIdx = 0, String? promptOverride}) {
    final keys = _allKeys;
    if (keys.isEmpty) {
      setState(() => keyIsValid = false);
      return;
    }
    _keyIndex = keyIdx.clamp(0, keys.length - 1);
    _modelIndex = modelIdx.clamp(0, _models.length - 1);
    try {
      final prompt = promptOverride ?? _cachedPrompt ?? _buildSystemPrompt();
      final model = GenerativeModel(
        model: _models[_modelIndex],
        apiKey: keys[_keyIndex],
        systemInstruction: Content.system(prompt),
      );
      chatSession = model.startChat();
      debugPrint('[ChatAI] model=${_models[_modelIndex]} key#${_keyIndex + 1}');
      if (mounted) setState(() => keyIsValid = true);
    } catch (_) {
      if (mounted) setState(() => keyIsValid = false);
    }
  }

  bool _isQuotaError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('429') ||
        msg.contains('quota') ||
        msg.contains('resource_exhausted') ||
        msg.contains('api_key_invalid') ||
        msg.contains('permission_denied') ||
        msg.contains('404') ||
        msg.contains('not_found') ||
        msg.contains('not found') ||
        msg.contains('model') && msg.contains('not');
  }

  void addWelcomeMessage() {
    chatList.add(ChatMessage(
      text: 'Xin chào! Tôi là trợ lý AI về chất lượng không khí tại Thủ Dầu Một. Hãy hỏi tôi về PM2.5, PM10, tác hại ô nhiễm và cách bảo vệ sức khỏe.',
      isUser: false,
      time: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    messageInput.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = messageInput.text.trim();
    if (text.isEmpty || isLoading) return;

    if (!keyIsValid || chatSession == null) {
      showError('Chưa cài đặt Gemini API key. Kiểm tra file .env');
      return;
    }

    messageInput.clear();
    setState(() {
      chatList.add(ChatMessage(text: text, isUser: true, time: DateTime.now()));
      isLoading = true;
    });
    scrollToBottom();

    final botMessage = ChatMessage(text: '', isUser: false, time: DateTime.now());
    chatList.add(botMessage);

    bool success = false;
    final keys = _allKeys;
    int tried = 0;
    final totalAttempts = keys.length * _models.length;

    while (!success && tried < totalAttempts) {
      try {
        final stream = chatSession!.sendMessageStream(Content.text(text));
        await for (final chunk in stream) {
          final token = chunk.text ?? '';
          if (mounted) {
            setState(() => botMessage.text += token);
            scrollToBottom();
          }
        }
        success = true;
      } catch (error) {
        tried++;
        final isNotFound = error.toString().toLowerCase().contains('404') ||
            error.toString().toLowerCase().contains('not_found') ||
            error.toString().toLowerCase().contains('not found');

        if (_isQuotaError(error) && tried < totalAttempts) {
          if (isNotFound) {
            final nextModel = (_modelIndex + 1) % _models.length;
            setupGemini(keyIdx: _keyIndex, modelIdx: nextModel);
          } else {
            final nextKey = (_keyIndex + 1) % keys.length;
            setupGemini(keyIdx: nextKey, modelIdx: _modelIndex);
          }
          if (mounted) setState(() => botMessage.text = '');
        } else {
          if (mounted) {
            final msg = tried >= totalAttempts
                ? 'Tất cả API key đã hết quota. Vui lòng thử lại sau.'
                : 'Lỗi kết nối. Kiểm tra internet và thử lại.';
            setState(() => botMessage.text = msg);
          }
          break;
        }
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: AppTheme.bad,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void clearChat() {
    setState(() {
      chatList.clear();
      addWelcomeMessage();
    });
    _initWithContext();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat AI',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
            Text('Chuyên gia không khí',
                style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.primary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary),
            onPressed: clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!keyIsValid) buildKeyWarning(),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: chatList.length,
              itemBuilder: (context, index) => buildChatBubble(chatList[index]),
            ),
          ),
          if (isLoading) buildTypingIndicator(),
          buildInputBar(),
        ],
      ),
    );
  }

  Widget buildKeyWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppTheme.bad.withValues(alpha: 0.15),
      child: Text(
        'Chưa có Gemini API key. Mở file mobile/.env và điền GEMINI_API_KEY',
        style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.bad),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget buildChatBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!msg.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
              ),
              child: const Icon(Icons.air, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: msg.isUser ? AppTheme.primary : AppTheme.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                      bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                    ),
                    border: msg.isUser ? null : Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    msg.text.isEmpty ? '...' : msg.text,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: msg.isUser ? Colors.white : AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(msg.time),
                  style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (msg.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
            ),
            child: const Icon(Icons.air, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border),
            ),
            child: const TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: messageInput,
                style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 14),
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Hỏi về chất lượng không khí...',
                  hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with TickerProviderStateMixin {
  late AnimationController dot1;
  late AnimationController dot2;
  late AnimationController dot3;

  @override
  void initState() {
    super.initState();
    dot1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    dot2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    dot3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    Future.delayed(const Duration(milliseconds: 170), () {
      if (mounted) dot2.repeat(reverse: true);
    });
    Future.delayed(const Duration(milliseconds: 340), () {
      if (mounted) dot3.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    dot1.dispose();
    dot2.dispose();
    dot3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDot(dot1),
        const SizedBox(width: 4),
        buildDot(dot2),
        const SizedBox(width: 4),
        buildDot(dot3),
      ],
    );
  }

  Widget buildDot(AnimationController controller) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.4 + controller.value * 0.6),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class ChatMessage {
  String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({required this.text, required this.isUser, required this.time});
}
