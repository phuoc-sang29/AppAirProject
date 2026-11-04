import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  bool _loading = false;
  bool _obscure = true;
  String _selectedGroup = 'binh_thuong';
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _auth.register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        fullName: _nameCtrl.text.trim(),
        healthGroup: _selectedGroup,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tài khoản đã tạo. Vui lòng đăng nhập.',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: AppTheme.good,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (!mounted) return;
      if (msg.contains('already registered')) {
        _showError('Email này đã được đăng ký. Hãy đăng nhập hoặc dùng email khác.');
      } else if (msg.contains('password')) {
        _showError('Mật khẩu chưa hợp lệ. Cần tối thiểu 6 ký tự.');
      } else {
        _showError(e.message);
      }
    } catch (_) {
      if (mounted) _showError('Lỗi kết nối. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.bad,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050810), Color(0xFF0A0E1A), Color(0xFF0D1528)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildForm(),
                  const SizedBox(height: 20),
                  _buildHealthGroup(),
                  const SizedBox(height: 28),
                  _buildRegisterButton(),
                  const SizedBox(height: 24),
                  _buildLoginLink(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSecondary, size: 22),
        ),
        const SizedBox(height: 24),
        Text('Tạo tài khoản',
            style: GoogleFonts.outfit(
                fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Text('Điền thông tin để bắt đầu giám sát không khí',
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _field(controller: _nameCtrl, label: 'Họ và tên', icon: Icons.person_outline,
              validator: (v) => (v == null || v.isEmpty) ? 'Nhập họ tên' : null),
          const SizedBox(height: 14),
          _field(controller: _emailCtrl, label: 'Email', icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nhập email';
                if (!v.contains('@')) return 'Email không hợp lệ';
                return null;
              }),
          const SizedBox(height: 14),
          _field(controller: _passCtrl, label: 'Mật khẩu', icon: Icons.lock_outline,
              obscure: _obscure, suffixToggle: true,
              validator: (v) => (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null),
          const SizedBox(height: 14),
          _field(controller: _confirmCtrl, label: 'Xác nhận mật khẩu', icon: Icons.lock_outline,
              obscure: _obscure,
              validator: (v) => v != _passCtrl.text ? 'Mật khẩu không khớp' : null),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    bool suffixToggle = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        suffixIcon: suffixToggle
            ? IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppTheme.textSecondary, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
      validator: validator,
    );
  }

  Widget _buildHealthGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nhóm sức khỏe của bạn',
            style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppConstants.healthGroups.map((g) {
            final selected = _selectedGroup == g;
            return GestureDetector(
              onTap: () => setState(() => _selectedGroup = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  AppConstants.healthGroupLabels[g] ?? g,
                  style: GoogleFonts.outfit(
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [AppTheme.secondary, Color(0xFF5B3BCC)]),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text('Đăng ký',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Đã có tài khoản? ',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14)),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('Đăng nhập',
              style: GoogleFonts.outfit(
                  color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
