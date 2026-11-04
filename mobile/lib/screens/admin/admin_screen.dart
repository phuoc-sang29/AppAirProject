import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import 'admin_news.dart';
import 'admin_notify.dart';
import 'admin_system.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController tabController;

  List<Map<String, dynamic>> userList = [];
  List<Map<String, dynamic>> ratingList = [];
  List<Map<String, dynamic>> searchList = [];
  bool isLoading = true;

  double avgStars = 0;
  int totalUsers = 0;
  int totalRatings = 0;
  int totalSearches = 0;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 6, vsync: this);
    loadData();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);
    try {
      final users = await supabase
          .from('users')
          .select('id, full_name, email, health_group, created_at, role, is_blocked')
          .order('created_at', ascending: false);

      final ratings = await supabase
          .from('ratings')
          .select('stars, feedback, created_at, user_id')
          .order('created_at', ascending: false);

      final searches = await supabase
          .from('map_searches')
          .select('address, pm25, searched_at, user_id')
          .order('searched_at', ascending: false)
          .limit(50);

      double total = 0;
      for (final r in ratings) {
        total += (r['stars'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          userList = List<Map<String, dynamic>>.from(users);
          ratingList = List<Map<String, dynamic>>.from(ratings);
          searchList = List<Map<String, dynamic>>.from(searches);
          totalUsers = userList.length;
          totalRatings = ratingList.length;
          totalSearches = searchList.length;
          avgStars = ratingList.isEmpty ? 0 : total / ratingList.length;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> toggleBlock(Map<String, dynamic> user) async {
    final blocked = user['is_blocked'] == true;
    final name = user['full_name']?.toString() ?? 'tài khoản này';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(blocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text(
            blocked
                ? 'Cho phép $name đăng nhập trở lại?'
                : '$name sẽ không thể đăng nhập cho đến khi được mở khóa.',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(blocked ? 'Mở khóa' : 'Khóa')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase
          .from('users')
          .update({'is_blocked': !blocked}).eq('id', user['id']);
      await loadData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể cập nhật. Kiểm tra quyền admin.')),
        );
      }
    }
  }

  Future<void> toggleRole(Map<String, dynamic> user) async {
    final currentRole = user['role']?.toString() ?? 'user';
    final newRole = currentRole == 'admin' ? 'user' : 'admin';
    final name = user['full_name']?.toString() ?? 'tài khoản này';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text(newRole == 'admin' ? 'Cấp quyền Admin' : 'Gỡ quyền Admin',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text(
            newRole == 'admin'
                ? 'Cấp quyền quản trị viên cho $name?'
                : 'Chuyển $name về quyền người dùng thông thường?',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase
          .from('users')
          .update({'role': newRole}).eq('id', user['id']);
      await loadData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể đổi quyền. Kiểm tra quyền admin.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản trị hệ thống',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: loadData,
            child: Text('Làm mới',
                style: GoogleFonts.outfit(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tài khoản'),
            Tab(text: 'Bản tin'),
            Tab(text: 'Đánh giá'),
            Tab(text: 'Hành vi'),
            Tab(text: 'Thông báo'),
            Tab(text: 'Hệ thống'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                buildStatBar(),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      buildUserTab(),
                      const AdminNewsTab(),
                      buildRatingTab(),
                      buildSearchTab(),
                      const AdminNotifyTab(),
                      const AdminSystemTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget buildStatBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppTheme.surface,
      child: Row(
        children: [
          buildStatItem('Người dùng', totalUsers.toString(), AppTheme.primary),
          const SizedBox(width: 8),
          buildStatItem('Đánh giá', totalRatings.toString(), AppTheme.secondary),
          const SizedBox(width: 8),
          buildStatItem('Sao TB', avgStars.toStringAsFixed(1), const Color(0xFFFFD740)),
          const SizedBox(width: 8),
          buildStatItem('Tìm kiếm', totalSearches.toString(), AppTheme.good),
        ],
      ),
    );
  }

  Widget buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget buildUserTab() {
    if (userList.isEmpty) {
      return Center(
        child: Text('Chưa có người dùng',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
      );
    }

    final groupCount = <String, int>{};
    for (final u in userList) {
      final g = AppConstants.normalizeHealthGroup(u['health_group']?.toString());
      groupCount[g] = (groupCount[g] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        buildGroupChart(groupCount),
        const SizedBox(height: 16),
        Text('Danh sách tài khoản (${userList.length})',
            style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        ...userList.map(buildUserCard),
      ],
    );
  }

  Widget buildGroupChart(Map<String, int> groupCount) {
    final labels = AppConstants.healthGroupLabels;
    final colors = [AppTheme.good, AppTheme.primary, AppTheme.poor, AppTheme.bad];
    final keys = AppConstants.healthGroups;

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
          Text('Nhóm sức khỏe người dùng',
              style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          const SizedBox(height: 12),
          ...List.generate(keys.length, (i) {
            final key = keys[i];
            final count = groupCount[key] ?? 0;
            final total = userList.isEmpty ? 1 : userList.length;
            final pct = count / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(labels[key] ?? key,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: AppTheme.border,
                        color: colors[i],
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors[i])),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildUserCard(Map<String, dynamic> user) {
    final name = user['full_name']?.toString() ?? 'Không tên';
    final email = user['email']?.toString() ?? '';
    final groupKey = user['health_group']?.toString() ?? 'binh_thuong';
    final groupLabel = AppConstants.healthGroupLabels[groupKey] ?? groupKey;
    final role = user['role']?.toString() ?? 'user';
    final blocked = user['is_blocked'] == true;
    final isSelf = user['id']?.toString() == supabase.auth.currentUser?.id;
    final createdAt = user['created_at']?.toString() ?? '';
    String dateStr = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      dateStr = DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: blocked ? AppTheme.bad.withValues(alpha: 0.45) : AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.15),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name,
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    if (role == 'admin')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.5)),
                        ),
                        child: Text('Admin',
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.w700)),
                      ),
                    if (blocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.bad.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.bad.withValues(alpha: 0.5)),
                        ),
                        child: Text('Đã khóa',
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: AppTheme.bad,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                Text(email,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppTheme.textSecondary)),
                Row(
                  children: [
                    Text(groupLabel,
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppTheme.moderate)),
                    const Spacer(),
                    Text(dateStr,
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          if (!isSelf)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => toggleRole(user),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(role == 'admin' ? 'Hạ quyền' : 'Cấp Admin',
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondary)),
                ),
                if (role != 'admin')
                  TextButton(
                    onPressed: () => toggleBlock(user),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(blocked ? 'Mở khóa' : 'Khóa',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: blocked ? AppTheme.good : AppTheme.bad)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget buildRatingTab() {
    if (ratingList.isEmpty) {
      return Center(
        child: Text('Chưa có đánh giá nào',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
      );
    }

    final starCount = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in ratingList) {
      final s = (r['stars'] as num).toInt();
      starCount[s] = (starCount[s] ?? 0) + 1;
    }

    final userById = <String, Map<String, dynamic>>{};
    for (final u in userList) {
      final id = u['id']?.toString();
      if (id != null) userById[id] = u;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        buildStarSummary(starCount),
        const SizedBox(height: 16),
        Text('Góp ý từ người dùng (${ratingList.length})',
            style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        ...ratingList.map((r) => buildRatingCard(r, userById)),
      ],
    );
  }

  Widget buildStarSummary(Map<int, int> starCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(avgStars.toStringAsFixed(1),
                  style: GoogleFonts.outfit(
                      fontSize: 40, fontWeight: FontWeight.w900, color: const Color(0xFFFFD740))),
              const SizedBox(width: 6),
              Text('/ 5 sao',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = starCount[star] ?? 0;
            final pct = totalRatings == 0 ? 0.0 : count / totalRatings;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text('$star sao',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: AppTheme.border,
                        color: const Color(0xFFFFD740),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget buildRatingCard(Map<String, dynamic> r, Map<String, Map<String, dynamic>> userById) {
    final stars = (r['stars'] as num).toInt();
    final feedback = r['feedback']?.toString().trim() ?? '';
    final uid = r['user_id']?.toString() ?? '';
    final u = userById[uid];
    final author = u?['full_name']?.toString() ?? u?['email']?.toString() ?? 'Người dùng';
    final createdAt = r['created_at']?.toString() ?? '';
    String dateStr = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      dateStr = DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
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
                  color: const Color(0xFFFFD740).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$stars / 5 sao',
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFD740))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(author,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
              Text(dateStr,
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            feedback.isNotEmpty ? feedback : 'Không có nhận xét chi tiết.',
            style: GoogleFonts.outfit(
                fontSize: 13,
                color: feedback.isNotEmpty ? AppTheme.textPrimary : AppTheme.textSecondary,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget buildSearchTab() {
    if (searchList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chưa có dữ liệu tìm kiếm',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Text('Dữ liệu sẽ xuất hiện khi người dùng tra cứu địa chỉ trên bản đồ',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    final addressCount = <String, int>{};
    final latestPm25 = <String, double>{};
    for (final s in searchList) {
      final addr = s['address']?.toString() ?? '';
      addressCount[addr] = (addressCount[addr] ?? 0) + 1;
      if (!latestPm25.containsKey(addr) && s['pm25'] != null) {
        latestPm25[addr] = (s['pm25'] as num).toDouble();
      }
    }
    final sorted = addressCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.good.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.good.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Top địa chỉ được tra cứu nhiều nhất giúp xác định vùng người dùng quan tâm',
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
        ...sorted.take(20).map((e) {
          final pct = e.value / searchList.length;
          final pm = latestPm25[e.key];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                    ),
                    if (pm != null) ...[
                      Text('PM2.5: ${pm.toStringAsFixed(1)}  |  ',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                    Text('${e.value} lần',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppTheme.border,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Text('${searchList.length} lượt tìm kiếm gần nhất',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
