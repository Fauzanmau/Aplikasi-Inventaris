import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _auth = AuthService();
  
  bool _loading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  
  static const primaryPurple = Color(0xFFA020F0);
  static const softPurple = Color(0xFFF3E8FF);

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
  /// GANTI PASSWORD LOGIC
  //////////////////////////////////////////////////////////
  Future<void> _change() async {
    final oldPass = _oldController.text.trim();
    final newPass = _newController.text.trim();
    
    if (oldPass.isEmpty || newPass.isEmpty) {
      _showCustomSnackBar(
        message: 'Semua field wajib diisi',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }
    
    if (newPass.length < 6) {
      _showCustomSnackBar(
        message: 'Password baru minimal 6 karakter',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }
    
    if (oldPass == newPass) {
      _showCustomSnackBar(
        message: 'Password baru tidak boleh sama dengan password lama',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    setState(() => _loading = true);
    
    final err = await _auth.changePassword(
      oldPassword: oldPass,
      newPassword: newPass,
    );
    
    if (!mounted) return;
    setState(() => _loading = false);
    
    if (err != null) {
      _showCustomSnackBar(
        message: err,
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
    } else {
      _showCustomSnackBar(
        message: 'Password berhasil diganti',
        icon: Icons.check_circle_rounded,
        bgColor: primaryPurple,
      );
      _oldController.clear();
      _newController.clear();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
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
          'Ganti Password',
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
              // ✅ FIX: withOpacity → withValues
              border: Border.all(color: primaryPurple.withValues(alpha: 0.5)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ganti Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryPurple,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Masukkan password lama dan password baru Anda',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Password Lama Field
                _buildField(
                  _oldController,
                  'Password Lama',
                  Icons.lock,
                  obscure: _obscureOld,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureOld ? Icons.visibility_off : Icons.visibility,
                      color: primaryPurple,
                    ),
                    onPressed: () => setState(() => _obscureOld = !_obscureOld),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Baru Field
                _buildField(
                  _newController,
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

                const SizedBox(height: 32),

                // Submit Button (Style sama seperti peminjaman_screen)
                _mainButton(
                  title: "Simpan Perubahan",
                  onTap: _change,
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
    bool autoCapitalize = false,
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
          // ✅ FIX: withOpacity → withValues
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
                overflow: TextOverflow.ellipsis, // ✅ Tambahan: sama seperti peminjaman_screen
              ),
      ),
    );
  }
}