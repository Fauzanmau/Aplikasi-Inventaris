import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/auth_service.dart';
import '../../core/routes.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final bool isForAdmin;
  
  const ForgotPasswordScreen({
    super.key,
    this.isForAdmin = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _authService = AuthService();
  
  final _usernameController = TextEditingController();
  final _nimController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  
  static const primaryPurple = Color(0xFFA020F0);
  static const softPurple = Color(0xFFF3E8FF);

  //////////////////////////////////////////////////////////
  /// CUSTOM SNACKBAR
  //////////////////////////////////////////////////////////
  void _showCustomSnackBar({
    required String message,
    required IconData icon,
    required Color bgColor,
    Duration duration = const Duration(milliseconds: 3500),
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
  /// RESET PASSWORD LOGIC
  //////////////////////////////////////////////////////////
  Future<void> _resetPassword() async {
    final username = _usernameController.text.trim();
    final nim = _nimController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (username.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showCustomSnackBar(
        message: 'Semua field wajib diisi',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    if (!widget.isForAdmin && nim.isEmpty) {
      _showCustomSnackBar(
        message: 'NIM wajib diisi',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    if (newPass.length < 6) {
      _showCustomSnackBar(
        message: 'Password minimal 6 karakter',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    if (newPass != confirmPass) {
      _showCustomSnackBar(
        message: 'Konfirmasi password tidak cocok',
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
      return;
    }

    setState(() => _loading = true);

    final error = await _authService.forgotPassword(
      username: username,
      nim: widget.isForAdmin ? null : nim,
      newPassword: newPass,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _showCustomSnackBar(
        message: error,
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
      return;
    }

    _showCustomSnackBar(
      message: 'Password berhasil direset!\nSilakan login dengan password baru.',
      icon: Icons.check_circle_rounded,
      bgColor: primaryPurple,
      duration: const Duration(milliseconds: 4500),
    );

    _usernameController.clear();
    _nimController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    // 🔥 REDIRECT AMAN & SPESIFIK PER ROLE
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      
      if (widget.isForAdmin) {
        Navigator.pushReplacementNamed(context, '/admin-login');
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nimController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  //////////////////////////////////////////////////////////
  /// UI BUILD
  //////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryPurple,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: AutoSizeText(
          'Lupa Password',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          minFontSize: 17,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: softPurple,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primaryPurple.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isForAdmin
                      ? 'Masukkan username admin untuk reset password'
                      : 'Verifikasi identitas Anda untuk membuat password baru',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),

                _buildField(
                  _usernameController,
                  'Username',
                  Icons.account_circle,
                  keyboardType: TextInputType.text,
                  autoCapitalize: false,
                ),
                const SizedBox(height: 16),

                if (!widget.isForAdmin) ...[
                  _buildField(
                    _nimController,
                    'NIM',
                    Icons.badge,
                    keyboardType: TextInputType.number,
                    autoCapitalize: false,
                  ),
                  const SizedBox(height: 16),
                ],

                const Divider(),
                const SizedBox(height: 16),

                const Text(
                  'Password Baru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryPurple,
                  ),
                ),
                const SizedBox(height: 16),

                _buildField(
                  _newPasswordController,
                  'Password Baru',
                  Icons.lock,
                  obscure: _obscureNew,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: primaryPurple,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                const SizedBox(height: 16),

                _buildField(
                  _confirmPasswordController,
                  'Konfirmasi Password',
                  Icons.lock_outline,
                  obscure: _obscureConfirm,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: primaryPurple,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),

                const SizedBox(height: 32),

                // Submit Button (Style sama seperti peminjaman_screen & change_password_screen)
                _mainButton(
                  title: "RESET PASSWORD",
                  onTap: _resetPassword,
                  loading: _loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// FIELD BUILDER
  //////////////////////////////////////////////////////////
  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
    bool autoCapitalize = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: autoCapitalize 
          ? TextCapitalization.words 
          : TextCapitalization.none,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(
          color: primaryPurple,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: primaryPurple,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: primaryPurple),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPurple),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPurple),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryPurple.withValues(alpha: 1.0), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// MAIN BUTTON STYLE (SAMA PERSIS DENGAN peminjaman_screen.dart)
  //////////////////////////////////////////////////////////
  Widget _mainButton({
    required String title,
    required VoidCallback onTap,
    required bool loading,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: loading ? Colors.grey : primaryPurple,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: primaryPurple.withValues(alpha: 0.3),
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
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : AutoSizeText(
                title,
                style: const TextStyle(
                  color: Colors.white,
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