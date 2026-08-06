import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import 'change_password_screen.dart';

const Color primaryPurple = Color(0xFFA020F0);
const Color softPurple = Color(0xFFF3E8FF);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final CloudinaryService _cloudinary = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  bool _isEdit = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isDataLoaded = false;

  final _namaController = TextEditingController();
  final _kelasController = TextEditingController();
  final _nimController = TextEditingController();
  String? _selectedProdi;
  String? _photoUrl;
  String? _photoPublicId;

  final List<String> _prodiList = [
    "D-IV Teknologi Rekayasa Komputer Jaringan",
    "D-IV Teknik Informatika",
    "D-IV Teknologi Rekayasa Multimedia",
  ];

  final Map<String, String> _prodiShort = {
    "D-IV Teknologi Rekayasa Komputer Jaringan": "D-IV Teknologi Rekayasa",
    "D-IV Teknik Informatika": "D-IV Teknik Informatika",
    "D-IV Teknologi Rekayasa Multimedia": "D-IV Teknologi Rekayasa Multimedia",
  };

  // ==================== CUSTOM SNACKBAR ====================
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
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UPLOAD FOTO PROFIL ====================
  Future<void> _uploadProfilePhoto() async {
    final XFile? pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryPurple),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: primaryPurple),
              title: const Text('Ambil Foto Kamera'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final file = File(pickedFile.path);

      final result = await _cloudinary.uploadAndReplaceImage(
        file: file,
        folder: 'profiles',
        publicId: 'profile_${_auth.currentUser!.uid}',
        oldPublicId: _photoPublicId,
      );

      if (result != null) {
        await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).update({
          'photoUrl': result['url'],
          'photoPublicId': result['publicId'],
        });

        setState(() {
          _photoUrl = result['url'];
          _photoPublicId = result['publicId'];
        });

        _showCustomSnackBar(
          message: 'Foto profil berhasil diperbarui!',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      } else {
        throw Exception('Gagal mengupload foto');
      }
    } catch (e) {
      _showCustomSnackBar(
        message: 'Gagal upload foto',
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ==================== HAPUS FOTO PROFIL ====================
  Future<void> _deleteProfilePhoto() async {
    if (_photoPublicId == null || _photoPublicId!.isEmpty) {
      await _deleteOnlyFromFirestore();
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Foto Profil?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: const Text('Apakah Anda yakin ingin menghapus foto profil.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final success = await _cloudinary.deleteImage(_photoPublicId!);
      if (success) {
        await _deleteOnlyFromFirestore();

        _showCustomSnackBar(
          message: 'Foto berhasil dihapus permanen',
          icon: Icons.delete_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    } catch (e) {
      _showCustomSnackBar(
        message: 'Gagal hapus foto',
        icon: Icons.error_outline_rounded,
        bgColor: Colors.orange.shade700,
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deleteOnlyFromFirestore() async {
    await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).update({
      'photoUrl': FieldValue.delete(),
      'photoPublicId': FieldValue.delete(),
    });
    setState(() {
      _photoUrl = null;
      _photoPublicId = null;
    });
  }

  void _viewFullPhoto() {
    if (_photoUrl == null || _photoUrl!.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: Hero(
              tag: 'profile_photo',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  _photoUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    final error = await _auth.updateProfile(
      nama: _namaController.text.trim(),
      nim: _nimController.text.trim(),
      kelas: _kelasController.text.trim(),
      prodi: _selectedProdi ?? '',
    );

    if (error != null) {
      _showCustomSnackBar(
        message: error,
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      await _firestoreService.updateUserInfoInAllRiwayat(
        _auth.currentUser!.uid,
        _namaController.text.trim(),
        _nimController.text.trim(),
        _kelasController.text.trim(),
        _selectedProdi ?? '',
      );
    } catch (e) {
      // print('Gagal update riwayat: $e');
    }

    setState(() {
      _isEdit = false;
      _isSaving = false;
    });

    _showCustomSnackBar(
      message: 'Profil berhasil diperbarui',
      icon: Icons.check_circle_rounded,
      bgColor: primaryPurple,
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _kelasController.dispose();
    _nimController.dispose();
    super.dispose();
  }

  // ==================== WIDGET HELPER ====================
  Widget _prodiField(Map<String, dynamic> userData) {
    String getShortProdi(String? fullProdi) {
      if (fullProdi == null) return '';
      return _prodiShort[fullProdi] ?? fullProdi;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 90, child: Text("Prodi")),
          const Text(" : "),
          Expanded(
            child: _isEdit
                ? DropdownButtonFormField<String>(
                    initialValue: _selectedProdi,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: primaryPurple),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black87, fontSize: 15),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.only(bottom: 6),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: primaryPurple.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: primaryPurple)),
                    ),
                    selectedItemBuilder: (context) => _prodiList.map((prodi) {
                      return Text(getShortProdi(prodi),
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                          overflow: TextOverflow.ellipsis);
                    }).toList(),
                    items: _prodiList
                        .map((prodi) => DropdownMenuItem(value: prodi, child: Text(prodi)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedProdi = val),
                  )
                : AutoSizeText(
                    userData['prodi'] ?? '',
                    style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.3),
                    maxLines: 2,
                    minFontSize: 13,
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== EDITABLE ROW DENGAN AUTO UPPERCASE UNTUK KELAS ====================
  Widget _editableRow(
    String title,
    TextEditingController controller,
    String currentValue, {
    TextInputType keyboard = TextInputType.text,
    bool isKelas = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(title)),
          const Text(" : "),
          Expanded(
            child: _isEdit
                ? TextField(
                    controller: controller,
                    keyboardType: keyboard,
                    cursorColor: primaryPurple,
                    style: const TextStyle(fontSize: 15),
                    onChanged: isKelas
                        ? (value) {
                            final upper = value.toUpperCase();
                            if (upper != value) {
                              controller.value = TextEditingValue(
                                text: upper,
                                selection: TextSelection.collapsed(offset: upper.length),
                              );
                            }
                          }
                        : null,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.only(bottom: 6),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: primaryPurple.withValues(alpha: 0.5))),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: primaryPurple)),
                    ),
                  )
                : AutoSizeText(
                    currentValue,
                    style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.3),
                    maxLines: 2,
                    minFontSize: 13,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(title)),
          const Text(" : "),
          Expanded(
            child: AutoSizeText(
              value,
              style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.3),
              maxLines: 2,
              minFontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainButton({
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8)
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: const Center(
        child: Icon(Icons.person_rounded, size: 65, color: primaryPurple),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('User tidak ditemukan')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Terjadi kesalahan'));
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          _photoUrl = userData['photoUrl'];
          _photoPublicId = userData['photoPublicId'];

          if (!_isDataLoaded) {
            _namaController.text = userData['namaLengkap'] ?? '';
            _kelasController.text = userData['kelas'] ?? '';
            _nimController.text = userData['nim'] ?? '';
            _selectedProdi = userData['prodi'];
            _isDataLoaded = true;
          }

          final bool isMahasiswa = userData['role'] == 'mahasiswa';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  if (isMahasiswa)
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _photoUrl != null && _photoUrl!.isNotEmpty ? _viewFullPhoto : null,
                            child: Hero(
                              tag: 'profile_photo',
                              child: Container(
                                width: 128,
                                height: 128,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: primaryPurple, width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5))
                                  ],
                                ),
                                child: ClipOval(
                                  child: _photoUrl != null && _photoUrl!.isNotEmpty
                                      ? Image.network(
                                          _photoUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                                child: CircularProgressIndicator(color: primaryPurple));
                                          },
                                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                                        )
                                      : _defaultAvatar(),
                                ),
                              ),
                            ),
                          ),
                          // Tombol Upload
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: _isUploadingPhoto ? null : _uploadProfilePhoto,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                    color: primaryPurple,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          blurRadius: 8)
                                    ]),
                                child: _isUploadingPhoto
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            color: Colors.white, strokeWidth: 2.5))
                                    : const Icon(Icons.camera_alt,
                                        color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          // Tombol Hapus
                          if (_photoUrl != null && _photoUrl!.isNotEmpty)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: GestureDetector(
                                onTap: _isUploadingPhoto ? null : _deleteProfilePhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                      color: Colors.red.shade700,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.25),
                                            blurRadius: 8)
                                      ]),
                                  child: const Icon(Icons.delete_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  if (isMahasiswa) const SizedBox(height: 24) else const SizedBox(height: 16),

                  // Card Informasi Akun
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: softPurple,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Informasi Akun",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            if (isMahasiswa)
                              IconButton(
                                icon: Icon(_isEdit ? Icons.close : Icons.edit,
                                    color: primaryPurple),
                                onPressed: () => setState(() => _isEdit = !_isEdit),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _editableRow("Nama", _namaController, userData['namaLengkap'] ?? ''),
                        _infoRow("Username", "@${userData['username'] ?? ''}"),
                        if (isMahasiswa) ...[
                          _editableRow("NIM", _nimController, userData['nim'] ?? '',
                              keyboard: TextInputType.number),
                          _editableRow("Kelas", _kelasController, userData['kelas'] ?? '',
                              isKelas: true),   // ← Auto Uppercase aktif di sini
                          _prodiField(userData),
                          _infoRow("Jurusan", userData['jurusan'] ?? ''),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (isMahasiswa && _isEdit)
                    _mainButton(
                      title: "Simpan Perubahan",
                      color: primaryPurple,
                      onTap: _isSaving ? () {} : _saveProfile,
                      isLoading: _isSaving,
                    )
                  else
                    _mainButton(
                      title: "Ganti Password",
                      color: Colors.red.shade700,
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                      icon: Icons.lock_reset_rounded,
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}