import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/auth_service.dart';
import '../../main.dart'; // untuk RoleGate
import '../../core/routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  static const primaryPurple = Color(0xFFA020F0);
  static const secondaryPurple = Color(0xFF8B00E0);

  //////////////////////////////////////////////////////////
  /// CUSTOM SNACKBAR
  //////////////////////////////////////////////////////////
  void _showCustomSnackBar({
    required String message,
    required IconData icon,
    required Color bgColor,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: duration,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// LOGIN LOGIC
  //////////////////////////////////////////////////////////
  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showCustomSnackBar(
        message: 'Username dan password wajib diisi',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    setState(() => _loading = true);

    await _authService.logout();

    final role = await _authService.getRoleByUsername(username);

    if (role == null) {
      setState(() => _loading = false);
      _showCustomSnackBar(
        message: 'User tidak ditemukan',
        icon: Icons.error_outline,
        bgColor: Colors.red.shade700,
      );
      return;
    }

    if (role != 'mahasiswa') {
      setState(() => _loading = false);
      _showCustomSnackBar(
        message:
            'Akun ini bukan mahasiswa.\nSilakan login melalui halaman administrator.',
        icon: Icons.admin_panel_settings,
        bgColor: Colors.red.shade700,
      );
      return;
    }

    final error = await _authService.login(
      username: username,
      password: password,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _loading = false);
      _showCustomSnackBar(
        message: error,
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
      return;
    }

    setState(() => _loading = false);

    _showCustomSnackBar(
      message: 'Login berhasil',
      icon: Icons.check_circle_rounded,
      bgColor: primaryPurple,
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGate()),
      (route) => false,
    );
  }

  //////////////////////////////////////////////////////////
  /// CLEANUP
  //////////////////////////////////////////////////////////
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  //////////////////////////////////////////////////////////
  /// UI BUILD
  //////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.white30,
          selectionHandleColor: Colors.white,
        ),
      ),
      child: Scaffold(
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryPurple, secondaryPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'logo',
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 140,
                          height: 140,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'LOGIN',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 🔥 LOGIN CARD
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Username Field
                            _buildField(
                              controller: _usernameController,
                              hint: 'Username',
                              icon: Icons.account_circle,
                              keyboardType: TextInputType.text,
                            ),
                            const SizedBox(height: 16),
                            
                            // Password Field
                            _buildField(
                              controller: _passwordController,
                              hint: 'Password',
                              icon: Icons.lock,
                              obscure: _obscure,
                              keyboardType: TextInputType.visiblePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            
                            // 🔥 TOMBOL LUPA PASSWORD
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading 
                                    ? null 
                                    : () => Navigator.pushNamed(
                                          context, 
                                          AppRoutes.forgotPassword,
                                        ),
                                child: const Text(
                                  'Lupa Password?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Login Button (PUTIH dengan teks UNGU, bentuk pill + shadow)
                            _mainButton(
                              title: "LOGIN",
                              onTap: _login,
                              loading: _loading,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Register Link
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.register),
                        child: RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Belum punya akun? ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(
                                text: 'Register sekarang',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔥 FIX: Admin Login Button
                      OutlinedButton.icon(
                        onPressed: () {
                          // ✅ Langsung replace ke admin login, stack tetap bersih & konsisten
                          Navigator.pushReplacementNamed(context, '/admin-login');
                        },
                        icon: const Icon(Icons.admin_panel_settings,
                            color: Colors.white, size: 20),
                        label: const Text(
                          'Administrator',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 🔥 FOOTER COPYRIGHT (DIPINDAH KE PALING BAWAH)
                      const Column(
                        children: [
                          Text(
                            "© 2026",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Fauzan Maulana, S.Tr.T.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// FIELD BUILDER
  //////////////////////////////////////////////////////////
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// MAIN BUTTON STYLE (PUTIH dengan teks UNGU, bentuk pill + shadow)
  //////////////////////////////////////////////////////////
  Widget _mainButton({
    required String title,
    required VoidCallback onTap,
    required bool loading,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(30), // ✅ Pill shape
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          // ✅ Background putih (seperti sebelumnya)
          color: loading ? Colors.grey.shade300 : Colors.white,
          borderRadius: BorderRadius.circular(30), // ✅ Pill shape
          // ✅ Shadow ungu untuk konsistensi visual
          boxShadow: [
            BoxShadow(
              color: primaryPurple.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: primaryPurple, // ✅ Loading indicator ungu
                  strokeWidth: 3,
                ),
              )
            : AutoSizeText(
                title,
                style: const TextStyle(
                  // ✅ Teks ungu (seperti sebelumnya)
                  color: primaryPurple,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                minFontSize: 14,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}