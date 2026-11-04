import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../services/air_service.dart';

class AdminNewsTab extends StatefulWidget {
  const AdminNewsTab({super.key});

  @override
  State<AdminNewsTab> createState() => _AdminNewsTabState();
}

class _AdminNewsTabState extends State<AdminNewsTab> {
  final _db = Supabase.instance.client;
  final _air = AirService();

  List<Map<String, dynamic>> _articles = [];
  bool _loading = true;
  bool _generatingAi = false;

  static const _categories = [
    'Cảnh báo hôm nay',
    'Sức khỏe hô hấp',
    'Tiêu chuẩn QCVN',
    'Phân tích khoa học',
  ];

  static const _angleOrder = [
    'angle_1',
    'angle_2',
    'angle_3',
    'angle_4',
    'angle_5',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _db
          .from('news_articles')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _articles = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: error ? AppTheme.bad : AppTheme.good,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createFromAi({String angle = 'auto'}) async {
    setState(() => _generatingAi = true);
    final draft = await _air.getAiNewsDraft(angle: angle);
    if (!mounted) return;
    setState(() => _generatingAi = false);
    if (draft == null) {
      _showMsg('Không lấy được bản nháp AI. Hãy kiểm tra AI Service.', error: true);
      return;
    }
    await _openEditor(initial: draft);
  }

  Future<void> _togglePublish(Map<String, dynamic> item) async {
    final current = item['is_published'] == true;
    try {
      await _db.from('news_articles').update({
        'is_published': !current,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', item['id']);
      await _load();
      _showMsg(!current ? 'Đã xuất bản bản tin.' : 'Đã ẩn bản tin.');
    } catch (_) {
      _showMsg('Không thể cập nhật trạng thái bản tin.', error: true);
    }
  }

  Future<void> _deleteArticle(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Xóa bản tin',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text('Bạn có chắc muốn xóa bản tin "${item['title']}"?',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Xóa', style: GoogleFonts.outfit(color: AppTheme.bad))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('news_articles').delete().eq('id', item['id']);
      await _load();
      _showMsg('Đã xóa bản tin.');
    } catch (_) {
      _showMsg('Không thể xóa bản tin.', error: true);
    }
  }

  bool _isDuplicateTitle(String title, {dynamic excludeId}) {
    final norm = title.trim().toLowerCase();
    for (final a in _articles) {
      if (excludeId != null && a['id'] == excludeId) continue;
      final existingTitle = (a['title']?.toString() ?? '').trim().toLowerCase();
      if (existingTitle == norm) return true;
    }
    return false;
  }

  Future<void> _openEditor({Map<String, dynamic>? existing, Map<String, dynamic>? initial}) async {
    final source = existing ?? initial;
    final titleCtrl = TextEditingController(text: source?['title']?.toString() ?? '');
    final summaryCtrl = TextEditingController(text: source?['summary']?.toString() ?? '');
    final contentCtrl = TextEditingController(text: source?['content']?.toString() ?? '');
    final authorCtrl = TextEditingController(
        text: source?['author']?.toString() ?? 'Ban biên tập AppAir');
    String category = source?['category']?.toString() ?? _categories.first;
    if (!_categories.contains(category)) {
      category = _categories.first;
    }
    bool published = source?['is_published'] != false;
    String? angleId = source?['angle_id']?.toString();
    String? angleLabel = source?['angle_label']?.toString();
    int? uniquenessScore = (source?['uniqueness_score'] as num?)?.toInt();
    String? sourceMode = source?['source_mode']?.toString();
    bool switchingAngle = false;
    String? modalError;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.card,
          title: Text(
              existing != null ? 'Chỉnh sửa bản tin' : 'Đăng bản tin mới',
              style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (angleLabel != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.good.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Độ mới văn bản: ${uniquenessScore ?? 95}%',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.good),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (sourceMode != null)
                                Expanded(
                                  child: Text(
                                    sourceMode!,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Góc khai thác: $angleLabel',
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: switchingAngle
                                  ? null
                                  : () async {
                                      setModalState(() {
                                        switchingAngle = true;
                                        modalError = null;
                                      });
                                      final curIdx = angleId != null
                                          ? _angleOrder.indexOf(angleId!)
                                          : -1;
                                      final nextAngle = _angleOrder[
                                          (curIdx + 1) % _angleOrder.length];
                                      final newDraft = await _air
                                          .getAiNewsDraft(angle: nextAngle);
                                      if (newDraft != null) {
                                        final newCat = newDraft['category']?.toString() ??
                                            _categories.first;
                                        setModalState(() {
                                          titleCtrl.text =
                                              newDraft['title']?.toString() ?? '';
                                          summaryCtrl.text =
                                              newDraft['summary']?.toString() ?? '';
                                          contentCtrl.text =
                                              newDraft['content']?.toString() ?? '';
                                          authorCtrl.text =
                                              newDraft['author']?.toString() ??
                                                  'Ban biên tập AppAir';
                                          if (_categories.contains(newCat)) {
                                            category = newCat;
                                          }
                                          angleId = newDraft['angle_id']?.toString();
                                          angleLabel =
                                              newDraft['angle_label']?.toString();
                                          uniquenessScore =
                                              (newDraft['uniqueness_score'] as num?)
                                                  ?.toInt();
                                          sourceMode =
                                              newDraft['source_mode']?.toString();
                                          switchingAngle = false;
                                        });
                                      } else {
                                        setModalState(() => switchingAngle = false);
                                      }
                                    },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.secondary),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                              child: Text(
                                switchingAngle
                                    ? 'Đang đổi góc viết...'
                                    : 'Đổi góc khai thác khác',
                                style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.secondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (modalError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bad.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.bad.withValues(alpha: 0.5)),
                      ),
                      child: Text(modalError!,
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.bad)),
                    ),
                  ],
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(category),
                    initialValue: category,
                    dropdownColor: AppTheme.surface,
                    style: GoogleFonts.outfit(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Chuyên mục'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => category = v ?? _categories.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Tiêu đề bản tin'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Tóm tắt ngắn'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 7,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Nội dung chi tiết',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authorCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(labelText: 'Tác giả / Nguồn'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Xuất bản hiển thị cho người dùng',
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: AppTheme.textPrimary)),
                    value: published,
                    activeTrackColor: AppTheme.primary,
                    onChanged: (v) => setModalState(() => published = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Hủy',
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final summary = summaryCtrl.text.trim();
                final content = contentCtrl.text.trim();
                final author = authorCtrl.text.trim();
                if (title.isEmpty || summary.isEmpty || content.isEmpty) {
                  setModalState(() =>
                      modalError = 'Vui lòng nhập đầy đủ tiêu đề, tóm tắt và nội dung.');
                  return;
                }
                if (_isDuplicateTitle(title, excludeId: existing?['id'])) {
                  setModalState(() => modalError =
                      'Tiêu đề này đã tồn tại trong danh sách bản tin. Hãy đổi góc viết hoặc chỉnh tiêu đề.');
                  return;
                }
                final payload = {
                  'title': title,
                  'category': category,
                  'summary': summary,
                  'content': content,
                  'author': author.isEmpty ? 'Ban biên tập AppAir' : author,
                  'is_published': published,
                  'updated_at': DateTime.now().toIso8601String(),
                };
                try {
                  if (existing != null) {
                    await _db
                        .from('news_articles')
                        .update(payload)
                        .eq('id', existing['id']);
                  } else {
                    await _db.from('news_articles').insert(payload);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (_) {
                  if (ctx.mounted) Navigator.pop(ctx, false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text('Lưu bản tin',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, color: AppTheme.bg)),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      await _load();
      _showMsg(existing != null ? 'Đã cập nhật bản tin.' : 'Đã thêm bản tin mới.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quản lý Bản tin Môi trường và Cẩm nang (CRUD)',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text(
                  'Thêm mới, chỉnh sửa, ẩn/hiện hoặc xóa bản tin. Khi dùng AI soạn từ dữ liệu DB, hệ thống tự động đối chiếu 15 bài gần nhất và xoay vòng 5 góc khai thác để không trùng lặp nội dung cũ.',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openEditor(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Viết bản tin mới',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.bg)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _generatingAi ? null : () => _createFromAi(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                          _generatingAi
                              ? 'AI đang phân tích DB...'
                              : 'AI soạn từ dữ liệu DB',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.secondary)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Danh sách bản tin (${_articles.length})',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            TextButton(
              onPressed: _load,
              child: Text('Làm mới',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          )
        else if (_articles.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text('Chưa có bản tin nào.',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          )
        else
          ..._articles.map((a) {
            final published = a['is_published'] == true;
            final dt = DateTime.tryParse(a['created_at']?.toString() ?? '')?.toLocal();
            final dateStr = dt == null ? '' : fmt.format(dt);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: published
                      ? AppTheme.border
                      : AppTheme.poor.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(a['category']?.toString() ?? 'Bản tin',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (published ? AppTheme.good : AppTheme.poor)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(published ? 'Đang hiển thị' : 'Đang ẩn',
                            style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: published ? AppTheme.good : AppTheme.poor)),
                      ),
                      const Spacer(),
                      Text(dateStr,
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(a['title']?.toString() ?? '',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Text(a['summary']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(a['author']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: AppTheme.textSecondary)),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => _togglePublish(a),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(published ? 'Ẩn bài' : 'Hiện bài',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.moderate)),
                      ),
                      TextButton(
                        onPressed: () => _openEditor(existing: a),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Sửa',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary)),
                      ),
                      TextButton(
                        onPressed: () => _deleteArticle(a),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Xóa',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.bad)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
