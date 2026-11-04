import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  final _feedbackCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  final _db = Supabase.instance.client;

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng chọn số sao', style: GoogleFonts.outfit()),
          backgroundColor: AppTheme.poor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = _db.auth.currentUser;
      await _db.from('ratings').insert({
        'user_id': user?.id,
        'stars': _stars,
        'feedback': _feedbackCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi gửi đánh giá', style: GoogleFonts.outfit()),
            backgroundColor: AppTheme.bad,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Đánh giá ứng dụng',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _submitted ? _buildThankYou() : _buildForm(),
    );
  }

  Widget _buildThankYou() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.good.withValues(alpha: 0.15),
              border: Border.all(color: AppTheme.good, width: 2),
            ),
            child: const Icon(Icons.check_rounded, color: AppTheme.good, size: 40),
          ),
          const SizedBox(height: 24),
          Text('Cảm ơn bạn đã đánh giá!',
              style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Text('Phản hồi của bạn giúp cải thiện ứng dụng.',
              style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Quay lại',
                style: GoogleFonts.outfit(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Text('Bạn hài lòng với AppAir không?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 32),
        _buildStars(),
        const SizedBox(height: 32),
        Text('Góp ý thêm (không bắt buộc)',
            style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 10),
        TextField(
          controller: _feedbackCtrl,
          maxLines: 4,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nhập ý kiến của bạn về ứng dụng...',
            hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary]),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Gửi đánh giá',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < _stars;
        return GestureDetector(
          onTap: () => setState(() => _stars = i + 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              size: 48,
              color: filled ? const Color(0xFFFFD740) : AppTheme.border,
            ),
          ),
        );
      }),
    );
  }
}
