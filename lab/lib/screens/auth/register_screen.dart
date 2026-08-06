import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _kelasController = TextEditingController();
  final _nimController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedProdi;
  final List<String> _prodiList = [
    "D-IV Teknologi Rekayasa Komputer Jaringan",
    "D-IV Teknik Informatika",
    "D-IV Teknologi Rekayasa Multimedia",
  ];

  bool _loading = false;
  bool _obscure = true;

  static const primaryPurple = Color(0xFFA020F0);
  static const softPurple = Color(0xFFF3E8FF);

  //////////////////////////////////////////////////////////
  /// SNACKBAR
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
  /// REGISTER
  //////////////////////////////////////////////////////////
  Future<void> _register() async {
    final nama = _namaController.text.trim();
    final username = _usernameController.text.trim();
    final kelas = _kelasController.text.trim();
    final nim = _nimController.text.trim();
    final password = _passwordController.text.trim();

    if (nama.isEmpty ||
        username.isEmpty ||
        kelas.isEmpty ||
        nim.isEmpty ||
        password.isEmpty) {
      _showCustomSnackBar(
        message: 'Semua field wajib diisi',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    if (_selectedProdi == null) {
      _showCustomSnackBar(
        message: 'Pilih prodi terlebih dahulu',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    if (!RegExp(r'^\d{10,15}$').hasMatch(nim)) {
      _showCustomSnackBar(
        message: 'NIM harus berupa angka 10–15 digit',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    if (password.length < 6) {
      _showCustomSnackBar(
        message: 'Password minimal 6 karakter',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    // ==================== VALIDASI KELAS ====================
    final kelasInput = _kelasController.text.trim().toUpperCase();
    if (!RegExp(r'^\d+[A-Z]$').hasMatch(kelasInput)) {
      _showCustomSnackBar(
        message: 'Format Kelas tidak valid!\nContoh: 1B, 2A, 3C, 4B',
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
        duration: const Duration(milliseconds: 4000),
      );
      return;
    }
    // ========================================================

    setState(() => _loading = true);

    final error = await _authService.register(
      namaLengkap: nama,
      username: username,
      kelas: kelas,
      nim: nim,
      password: password,
      prodi: _selectedProdi!,
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

    // Registrasi berhasil
    _showCustomSnackBar(
      message: 'Registrasi berhasil! Silakan login',
      icon: Icons.check_circle_rounded,
      bgColor: primaryPurple,
    );
    Navigator.pop(context);
  }

  //////////////////////////////////////////////////////////
  /// CLEANUP
  //////////////////////////////////////////////////////////
  @override
  void dispose() {
    _namaController.dispose();
    _usernameController.dispose();
    _kelasController.dispose();
    _nimController.dispose();
    _passwordController.dispose();
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
          'Register Mahasiswa',
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
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: softPurple,
            borderRadius: BorderRadius.circular(18),
            // ✅ FIX: withOpacity → withValues
            border: Border.all(
              color: primaryPurple.withValues(alpha: 0.5),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buat Akun',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryPurple,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Isi data diri kamu dengan benar',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),

              _buildField(_namaController, 'Nama Lengkap', Icons.person),
              const SizedBox(height: 16),
              _buildField(_usernameController, 'Username', Icons.account_circle),
              const SizedBox(height: 16),

              // Dropdown Prodi
              DropdownButtonFormField<String>(
                initialValue: _selectedProdi,
                isExpanded: true,
                isDense: false,
                items: _prodiList.map((prodi) {
                  return DropdownMenuItem(
                    value: prodi,
                    child: AutoSizeText(
                      prodi,
                      maxLines: 2,
                      minFontSize: 13,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedProdi = value);
                },
                decoration: InputDecoration(
                  labelText: 'Prodi',
                  labelStyle: const TextStyle(
                    color: primaryPurple,
                    fontWeight: FontWeight.w500,
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: const Icon(Icons.school, color: primaryPurple),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
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
                ),
              ),
              const SizedBox(height: 16),

              // Field Kelas dengan auto uppercase
              _buildField(
                _kelasController,
                'Kelas (contoh: 1B, 2A, 3C, 4B)',
                Icons.class_,
                onChanged: (value) {
                  final upper = value.toUpperCase();
                  if (upper != value) {
                    _kelasController.value = TextEditingValue(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                },
              ),

              const SizedBox(height: 16),
              _buildField(
                _nimController,
                'NIM',
                Icons.badge,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildField(
                _passwordController,
                'Password',
                Icons.lock,
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: primaryPurple,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Register (Style sama seperti screen lainnya)
              _mainButton(
                title: "REGISTER",
                onTap: _register,
                loading: _loading,
              ),
            ],
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
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(
            color: primaryPurple, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(
            color: primaryPurple, fontWeight: FontWeight.w600),
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
            horizontal: 16, vertical: 14),
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// MAIN BUTTON STYLE (SAMA PERSIS DENGAN screen lainnya)
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