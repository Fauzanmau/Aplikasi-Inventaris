import 'package:flutter/material.dart';
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

  String? _selectedProdi; // 🔥 TAMBAHAN

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
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
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
        icon: Icons.warning,
        bgColor: Colors.orange,
      );
      return;
    }

    if (_selectedProdi == null) {
      _showCustomSnackBar(
        message: 'Pilih prodi dulu',
        icon: Icons.warning,
        bgColor: Colors.orange,
      );
      return;
    }

    if (!RegExp(r'^\d{10,15}$').hasMatch(nim)) {
      _showCustomSnackBar(
        message: 'NIM harus angka 10–15 digit',
        icon: Icons.warning,
        bgColor: Colors.orange,
      );
      return;
    }

    if (password.length < 6) {
      _showCustomSnackBar(
        message: 'Password minimal 6 karakter',
        icon: Icons.warning,
        bgColor: Colors.orange,
      );
      return;
    }

    setState(() => _loading = true);

    final error = await _authService.register(
      namaLengkap: nama,
      username: username,
      kelas: kelas,
      nim: nim,
      password: password,
      prodi: _selectedProdi!, // 🔥 KIRIM PRODI
    );

    setState(() => _loading = false);

    if (error != null) {
      _showCustomSnackBar(
        message: error,
        icon: Icons.error,
        bgColor: Colors.red,
      );
      return;
    }

    _showCustomSnackBar(
      message: 'Registrasi berhasil',
      icon: Icons.check,
      bgColor: primaryPurple,
    );

    // ignore: use_build_context_synchronously
    Navigator.pop(context);
  }

  //////////////////////////////////////////////////////////
  /// UI
  //////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryPurple,
        title: const Text("Register Mahasiswa"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: softPurple,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              _buildField(_namaController, "Nama Lengkap", Icons.person),
              const SizedBox(height: 16),

              _buildField(_usernameController, "Username", Icons.person_outline),
              const SizedBox(height: 16),

              /// 🔥 DROPDOWN PRODI
              DropdownButtonFormField<String>(
                initialValue: _selectedProdi,
                items: _prodiList.map((prodi) {
                  return DropdownMenuItem(
                    value: prodi,
                    child: Text(prodi),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedProdi = value);
                },
                decoration: InputDecoration(
                  labelText: "Prodi",
                  prefixIcon: const Icon(Icons.school, color: primaryPurple),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _buildField(_kelasController, "Kelas", Icons.class_),
              const SizedBox(height: 16),

              _buildField(_nimController, "NIM", Icons.badge,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),

              _buildField(
                _passwordController,
                "Password",
                Icons.lock,
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("REGISTER"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// FIELD
  //////////////////////////////////////////////////////////
  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: primaryPurple),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}