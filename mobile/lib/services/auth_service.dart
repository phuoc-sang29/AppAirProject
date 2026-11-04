import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final client = Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    required String healthGroup,
  }) async {
    final res = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'health_group': healthGroup},
    );

    if (res.user != null && res.session != null) {
      await saveProfile(res.user!.id, email, fullName, healthGroup);
    }

    return res;
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final res = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (await _isBlocked(res.user?.id)) {
      await client.auth.signOut();
      throw const AuthException('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên.');
    }
    return res;
  }

  Future<bool> _isBlocked(String? uid) async {
    if (uid == null) return false;
    try {
      final row = await client
          .from('users')
          .select('is_blocked')
          .eq('id', uid)
          .maybeSingle();
      return row?['is_blocked'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await client.auth.signOut();
  }

  Future<void> sendResetOtp(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  Future<void> verifyResetOtp(String email, String otp) async {
    await client.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType.recovery,
    );
  }

  Future<void> setNewPassword(String password) async {
    await client.auth.updateUser(UserAttributes(password: password));
    await client.auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await client.from('users').select().eq('id', uid).maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateHealthGroup(String group) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await client.from('users').update({'health_group': group}).eq('id', uid);
    } catch (_) {}
  }

  Future<void> saveProfile(
    String uid,
    String email,
    String fullName,
    String healthGroup,
  ) async {
    try {
      await client.from('users').upsert({
        'id': uid,
        'email': email,
        'full_name': fullName,
        'health_group': healthGroup,
      });
    } catch (_) {}
  }
}
