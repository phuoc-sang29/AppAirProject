import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../admin/admin_screen.dart';
import 'rating_screen.dart';
import 'notify_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String _selectedGroup = 'binh_thuong';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _auth.getUserProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        _selectedGroup = AppConstants.normalizeHealthGroup(
          p?['health_group']?.toString(),
        );
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Đăng xuất',
            style: GoogleFonts.outfit(color: AppTheme.textPrimary)),
        content: Text('Bạn có chắc muốn đăng xuất?',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Đăng xuất',
                style: GoogleFonts.outfit(color: AppTheme.bad)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _auth.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hồ sơ cá nhân',
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: [
                _buildAvatar(),
                if (_profile?['role'] == 'admin') ...[
                  const SizedBox(height: 18),
                  _buildAdminBanner(),
                ],
                const SizedBox(height: 20),
                _buildInfoCard(),
                const SizedBox(height: 20),
                _buildQuickLinks(),
                const SizedBox(height: 24),
                _buildLogoutBtn(),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildAvatar() {
    final name = _profile?['full_name']?.toString() ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final isAdmin = _profile?['role'] == 'admin';
    return Center(
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary]),
            ),
            child: Center(
              child: Text(initial,
                  style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.secondary.withValues(alpha: 0.6)),
                  ),
                  child: Text('Admin',
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondary)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _profile?['email']?.toString() ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AdminScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.secondary.withValues(alpha: 0.28),
              AppTheme.primary.withValues(alpha: 0.22),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.secondary.withValues(alpha: 0.65), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text('QT',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mở Bảng điều khiển Quản trị (Admin)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Quản lý tài khoản, bản tin, thông báo và hệ thống',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Mở ngay',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final isAdmin = _profile?['role'] == 'admin';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _infoRow('Email', _profile?['email']?.toString() ?? '--'),
          const Divider(color: AppTheme.border, height: 20),
          _infoRow('Vai trò', isAdmin ? 'Quản trị viên (Admin)' : 'Người dùng'),
          const Divider(color: AppTheme.border, height: 20),
          _infoRow('Nhóm sức khỏe',
              AppConstants.healthGroupLabels[_selectedGroup] ?? _selectedGroup),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickLinks() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _linkTile(
            tag: 'TB',
            label: 'Thông báo',
            sub: 'Hộp thư cảnh báo và tin từ quản trị viên',
            color: AppTheme.good,
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const NotifyScreen())),
          ),
          const Divider(color: AppTheme.border, height: 1),
          _linkTile(
            tag: 'CĐ',
            label: 'Cài đặt',
            sub: 'Cảnh báo không khí, nhóm sức khỏe và chuông báo',
            color: const Color(0xFF38BDF8),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _load();
            },
          ),
          const Divider(color: AppTheme.border, height: 1),
          _linkTile(
            tag: 'ĐG',
            label: 'Đánh giá ứng dụng',
            sub: 'Góp ý để cải thiện AppAir',
            color: const Color(0xFFFFD740),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const RatingScreen())),
          ),
        ],
      ),
    );
  }

  Widget _linkTile({
    required String tag,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Text(tag,
              style: GoogleFonts.outfit(
                  color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ),
      title: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
      subtitle: Text(sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Text('Xem',
          style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _buildLogoutBtn() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _logout,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.bad),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text('Đăng xuất',
            style: GoogleFonts.outfit(
                color: AppTheme.bad, fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }
}
