import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../services/air_service.dart';
import 'notify_screen.dart';
import 'rating_screen.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final _db = Supabase.instance.client;
  final _air = AirService();

  bool _loading = true;
  String _selectedCat = 'Tất cả';
  Map<String, dynamic>? _current;
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _forecast;
  List<Map<String, dynamic>> _articles = [];
  List<Map<String, dynamic>> _notices = [];

  static const _categories = [
    'Tất cả',
    'Cảnh báo hôm nay',
    'Sức khỏe hô hấp',
    'Tiêu chuẩn QCVN',
    'Phân tích khoa học',
  ];

  static final _fallbackArticles = [
    {
      'title': 'Vì sao chất lượng không khí tại Thủ Dầu Một thường giảm về đêm và rạng sáng?',
      'category': 'Phân tích khoa học',
      'summary':
          'Hiện tượng nghịch nhiệt bức xạ ban đêm giữ các hạt bụi mịn PM2.5 tích tụ sát mặt đất dù lưu lượng giao thông đã giảm mạnh.',
      'content':
          'Ban ngày, mặt trời chiếu sáng làm mặt đất nóng lên, tạo luồng khí ấm bốc lên cao tới 1.000 - 1.500 mét giúp khuếch tán bụi mịn.\n\nBan đêm, mặt đất nguội nhanh khiến lớp không khí sát mặt đất lạnh hơn lớp không khí phía trên, tạo thành một vòm chắn ở độ cao chỉ 100 - 300 mét giữ lại bụi mịn từ khu công nghiệp và dân sinh.\n\nKhuyến nghị: Người tập thể dục buổi sáng nên ra ngoài sau 07:30 khi mặt trời đã làm tan lớp nghịch nhiệt.',
      'author': 'Trung tâm Phân tích AppAir',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Hướng dẫn bảo vệ hệ hô hấp cho trẻ em và người có bệnh nền theo từng ngưỡng PM2.5',
      'category': 'Sức khỏe hô hấp',
      'summary':
          'Trẻ em và người mắc bệnh hen suyễn cần chế độ bảo vệ sớm ngay từ ngưỡng PM2.5 vượt 15 ug/m3.',
      'content':
          'Các ngưỡng hành động theo QCVN 05:2023/BTNMT:\n- Ngưỡng Tốt (0 - 15 ug/m3): An toàn cho mọi hoạt động ngoài trời.\n- Ngưỡng Trung bình (15.1 - 25 ug/m3): Trẻ nhỏ và người có tiền sử hen suyễn nên giảm vận động quá sức ngoài trời.\n- Ngưỡng Kém (25.1 - 50 ug/m3): Đeo khẩu trang chống bụi mịn KN95/N95 khi ra đường.\n- Ngưỡng Xấu (trên 50 ug/m3): Hạn chế tối đa hoạt động ngoài trời.',
      'author': 'Bác sĩ Tư vấn Sức khỏe Cộng đồng',
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final curF = _air.getCurrent();
    final histF = _air.getHistory(hours: 24);
    final fcF = _air.getForecast();

    List<Map<String, dynamic>> dbArticles = [];
    try {
      final rows = await _db
          .from('news_articles')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false);
      dbArticles = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}

    List<Map<String, dynamic>> dbNotices = [];
    final uid = _db.auth.currentUser?.id;
    if (uid != null) {
      try {
        final rows = await _db
            .from('notifications')
            .select('id, message, level, created_at')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(3);
        dbNotices = List<Map<String, dynamic>>.from(rows);
      } catch (_) {}
    }

    final res = await Future.wait([curF, histF, fcF]);
    if (!mounted) return;
    setState(() {
      _current = res[0] as Map<String, dynamic>?;
      _history = res[1] as List<Map<String, dynamic>>;
      _forecast = res[2] as Map<String, dynamic>?;
      _articles = dbArticles.isNotEmpty ? dbArticles : _fallbackArticles;
      _notices = dbNotices;
      _loading = false;
    });
  }

  void _openArticleDetail(Map<String, dynamic> a) {
    final dt = DateTime.tryParse(a['created_at']?.toString() ?? '')?.toLocal();
    final dateStr = dt == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(dt);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(22),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a['category']?.toString() ?? 'Bản tin',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Đóng',
                      style: GoogleFonts.outfit(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              a['title']?.toString() ?? '',
              style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              '${a['author'] ?? 'Ban biên tập AppAir'}${dateStr.isNotEmpty ? '  |  $dateStr' : ''}',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            const Divider(color: AppTheme.border, height: 28),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                a['summary']?.toString() ?? '',
                style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              a['content']?.toString() ?? '',
              style: GoogleFonts.outfit(
                  fontSize: 14, color: AppTheme.textPrimary, height: 1.65),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedCat == 'Tất cả'
        ? _articles
        : _articles.where((a) => a['category'] == _selectedCat).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Bản tin và Cẩm nang Không khí',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.surface,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  _buildLiveBulletin(),
                  const SizedBox(height: 22),
                  _buildAdminAlertSection(),
                  Text('Chuyên mục Điểm báo và Phân tích',
                      style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  _buildCategoryFilter(),
                  const SizedBox(height: 14),
                  ...filtered.map(_buildArticleCard),
                  const SizedBox(height: 18),
                  _buildQcvnCard(),
                  const SizedBox(height: 18),
                  _buildRatingBanner(),
                ],
              ),
            ),
    );
  }

  Widget _buildLiveBulletin() {
    final pm25 = (_current?['pm2_5'] as num?)?.toDouble() ?? 0.0;
    final pm10 = (_current?['pm10'] as num?)?.toDouble() ?? 0.0;
    final avg24 = _history.isEmpty
        ? pm25
        : _history
                .map((r) => (r['pm2_5'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) /
            _history.length;
    final fcList = (_forecast?['forecast_pm2_5'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final next12Avg = fcList.isEmpty
        ? pm25
        : fcList.take(12).reduce((a, b) => a + b) /
            (fcList.length < 12 ? fcList.length : 12);

    final lvl = _air.getAqiLevel(pm25);
    final label = _air.getAqiLabel(pm25);
    final color = AppTheme.levelColor(lvl);
    final diffPct = avg24 > 0 ? ((pm25 - avg24) / avg24 * 100) : 0.0;
    final trendStr = diffPct >= 0
        ? 'Cao hơn TB 24h ${diffPct.abs().toStringAsFixed(0)}%'
        : 'Thấp hơn TB 24h ${diffPct.abs().toStringAsFixed(0)}%';

    final nowHour = DateTime.now().hour;
    final meteoNote = (nowHour >= 20 || nowHour <= 6)
        ? 'Nhận định khí tượng: Đang trong khung giờ đêm và rạng sáng, hiện tượng nghịch nhiệt bức xạ làm hạn chế khuếch tán bụi mịn sát mặt đất.'
        : 'Nhận định khí tượng: Nhiệt độ ban ngày giúp lớp biên khí quyển mở rộng, hỗ trợ khuếch tán bụi mịn tốt hơn.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            AppTheme.card,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('BẢN TIN TRỰC TIẾP HÔM NAY',
                    style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: color)),
              ),
              const Spacer(),
              Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Thủ Dầu Một: Không khí hiện ở mức $label (${pm25.toStringAsFixed(1)} ug/m3)',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox('Hiện tại', '${pm25.toStringAsFixed(1)} ug', color),
              const SizedBox(width: 8),
              _statBox('TB 24h qua', '${avg24.toStringAsFixed(1)} ug', AppTheme.primary),
              const SizedBox(width: 8),
              _statBox('Dự báo 12h', '${next12Avg.toStringAsFixed(1)} ug', AppTheme.secondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$trendStr  |  PM10: ${pm10.toStringAsFixed(1)} ug/m3',
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            meteoNote,
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppTheme.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String val, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 3),
            Text(val,
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w800, color: c)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminAlertSection() {
    if (_notices.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Thông báo từ Quản trị viên',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const NotifyScreen())),
                child: Text('Xem tất cả',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._notices.map((n) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '- ${n['message'] ?? ''}',
                style: GoogleFonts.outfit(
                    fontSize: 12.5, color: AppTheme.textPrimary, height: 1.4),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((c) {
        final active = _selectedCat == c;
        return GestureDetector(
          onTap: () => setState(() => _selectedCat = c),
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
              c,
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

  Widget _buildArticleCard(Map<String, dynamic> a) {
    final dt = DateTime.tryParse(a['created_at']?.toString() ?? '')?.toLocal();
    final dateStr = dt == null ? '' : DateFormat('dd/MM/yyyy').format(dt);
    return GestureDetector(
      onTap: () => _openArticleDetail(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    a['category']?.toString() ?? 'Bản tin',
                    style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                  ),
                ),
                const Spacer(),
                Text(dateStr,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              a['title']?.toString() ?? '',
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.35),
            ),
            const SizedBox(height: 6),
            Text(
              a['summary']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                  height: 1.45),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    a['author']?.toString() ?? 'Ban biên tập AppAir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Đọc chi tiết',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQcvnCard() {
    final rows = [
      ('Tốt', '0 - 15 ug/m3', 'Sinh hoạt ngoài trời bình thường', AppTheme.good),
      ('Trung bình', '15.1 - 25 ug/m3', 'Nhóm nhạy cảm lưu ý theo dõi', AppTheme.moderate),
      ('Kém', '25.1 - 50 ug/m3', 'Đeo khẩu trang chống bụi mịn', AppTheme.poor),
      ('Xấu', 'Trên 50 ug/m3', 'Hạn chế tối đa ra ngoài', AppTheme.bad),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bảng phân cấp chất lượng không khí (QCVN 05:2023/BTNMT)',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary)),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: r.$4, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 78,
                      child: Text(r.$1,
                          style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              color: r.$4,
                              fontWeight: FontWeight.w700)),
                    ),
                    SizedBox(
                      width: 95,
                      child: Text(r.$2,
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppTheme.textPrimary)),
                    ),
                    Expanded(
                      child: Text(r.$3,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.outfit(
                              fontSize: 11.5, color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRatingBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const RatingScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.secondary.withValues(alpha: 0.2),
              AppTheme.primary.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đánh giá và Góp ý cho AppAir',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Ý kiến của bạn giúp nâng cao chất lượng bản tin và dự báo',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Text('Gửi đánh giá',
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondary)),
          ],
        ),
      ),
    );
  }
}
