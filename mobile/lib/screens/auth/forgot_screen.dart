import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _obscure = true;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => _countdown--);
    });
  }

  void _show(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: error ? AppTheme.bad : AppTheme.good,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _translate(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('error sending')) {
      return 'Hệ thống chưa gửi được email. Vui lòng thử lại sau hoặc liên hệ quản trị viên.';
    }
    if (m.contains('rate limit') || m.contains('seconds')) {
      return 'Bạn thao tác quá nhanh. Vui lòng chờ một lát rồi thử lại.';
    }
    if (m.contains('expired') || m.contains('invalid')) {
      return 'Mã OTP không đúng hoặc đã hết hạn.';
    }
    if (m.contains('same') || m.contains('different')) {
      return 'Mật khẩu mới phải khác mật khẩu cũ.';
    }
    if (m.contains('password')) {
      return 'Mật khẩu chưa hợp lệ. Cần tối thiểu 6 ký tự.';
    }
    return raw;
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _show('Vui lòng nhập email hợp lệ.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.sendResetOtp(email);
      if (!mounted) return;
      _otpCtrl.clear();
      setState(() => _step = 1);
      _startCountdown();
      _show('Đã gửi mã OTP đến email của bạn.', error: false);
    } on AuthException catch (e) {
      if (mounted) _show(_translate(e.message));
    } catch (_) {
      if (mounted) _show('Lỗi kết nối. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      _show('Vui lòng nhập đủ 6 số OTP.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.verifyResetOtp(_emailCtrl.text.trim(), otp);
      if (mounted) setState(() => _step = 2);
    } on AuthException catch (e) {
      if (mounted) _show(_translate(e.message));
    } catch (_) {
      if (mounted) _show('Lỗi kết nối. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final pass = _passCtrl.text;
    if (pass.length < 6) {
      _show('Mật khẩu tối thiểu 6 ký tự.');
      return;
    }
    if (pass != _confirmCtrl.text) {
      _show('Mật khẩu xác nhận không khớp.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.setNewPassword(pass);
      if (!mounted) return;
      _show('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.', error: false);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      if (mounted) _show(_translate(e.message));
    } catch (_) {
      if (mounted) _show('Lỗi kết nối. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: AppTheme.textPrimary, size: 20),
                ),
                const SizedBox(height: 24),
                Text(_title(),
                    style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(_subtitle(),
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.5)),
                const SizedBox(height: 32),
                if (_step == 0) _emailStep(),
                if (_step == 1) _otpStep(),
                if (_step == 2) _passStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title() {
    if (_step == 0) return 'Quên mật khẩu';
    if (_step == 1) return 'Nhập mã OTP';
    return 'Mật khẩu mới';
  }

  String _subtitle() {
    if (_step == 0) {
      return 'Nhập email đã đăng ký. Chúng tôi sẽ gửi mã OTP gồm 6 số để xác minh danh tính.';
    }
    if (_step == 1) {
      return 'Mã OTP gồm 6 số đã được gửi đến ${_emailCtrl.text.trim()}. Mã có hiệu lực trong thời gian ngắn.';
    }
    return 'Tạo mật khẩu mới cho tài khoản của bạn.';
  }

  Widget _emailStep() {
    return Column(
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined,
                color: AppTheme.textSecondary, size: 20),
          ),
        ),
        const SizedBox(height: 24),
        _button('Gửi mã OTP', _sendOtp),
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      children: [
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
              fontSize: 28,
              letterSpacing: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
          decoration: const InputDecoration(counterText: '', hintText: '000000'),
        ),
        const SizedBox(height: 24),
        _button('Xác nhận', _verifyOtp),
        const SizedBox(height: 20),
        Center(
          child: _countdown > 0
              ? Text('Gửi lại mã sau ${_countdown}s',
                  style: GoogleFonts.outfit(color: AppTheme.textSecondary))
              : GestureDetector(
                  onTap: _loading ? null : _sendOtp,
                  child: Text('Gửi lại mã OTP',
                      style: GoogleFonts.outfit(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                ),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: () => setState(() => _step = 0),
            child: Text('Đổi email khác',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
        ),
      ],
    );
  }

  Widget _passStep() {
    return Column(
      children: [
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Mật khẩu mới',
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppTheme.textSecondary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary,
                  size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmCtrl,
          obscureText: _obscure,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Xác nhận mật khẩu mới',
            prefixIcon: Icon(Icons.lock_outline,
                color: AppTheme.textSecondary, size: 20),
          ),
        ),
        const SizedBox(height: 24),
        _button('Đổi mật khẩu', _resetPassword),
      ],
    );
  }

  Widget _button(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFF0099CC)]),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(label,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.bg)),
        ),
      ),
    );
  }
}
