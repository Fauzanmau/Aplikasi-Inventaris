import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';

class TambahKategoriScreen extends StatefulWidget {
  final String labId;
  const TambahKategoriScreen({
    super.key,
    required this.labId,
  });

  @override
  State<TambahKategoriScreen> createState() => _TambahKategoriScreenState();
}

class _TambahKategoriScreenState extends State<TambahKategoriScreen> {
  static const primaryPurple = Color(0xFFA020F0);
  static const softPurple = Color(0xFFF3E8FF);
  
  // ✅ Daftar satuan default untuk Dropdown
  static const List<String> defaultUnits = ['PCS', 'Unit', 'Set', 'Kotak', 'Gulung'];

  final _kategoriController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = false;

  //////////////////////////////////////////////////////////
  /// HELPER: Sanitasi nama untuk folder Cloudinary
  //////////////////////////////////////////////////////////
  String _sanitizeFolderName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  //////////////////////////////////////////////////////////
  /// HELPER: Dapatkan nama folder Lab (105-Laboratorium_xxx)
  //////////////////////////////////////////////////////////
  Future<String> _getLabFolderName() async {
    try {
      final labDoc = await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .get();

      final labName = labDoc.data()?['name'] as String? ?? 'Unknown_Lab';
      return '${widget.labId}-${_sanitizeFolderName(labName)}';
    } catch (e) {
      return '${widget.labId}-lab';
    }
  }

  //////////////////////////////////////////////////////////
  /// NOTIFIKASI CUSTOM
  //////////////////////////////////////////////////////////
  void _showSnackBar({
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

  //////////////////////////////////////////////////////////
  /// STYLE INPUT
  //////////////////////////////////////////////////////////
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: primaryPurple, fontWeight: FontWeight.w500, fontSize: 14.5),
      floatingLabelStyle: const TextStyle(
          color: primaryPurple, fontWeight: FontWeight.w600, fontSize: 14.5),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPurple)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPurple)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPurple, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  //////////////////////////////////////////////////////////
  /// MAIN BUTTON STYLE
  //////////////////////////////////////////////////////////
  Widget _mainButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: primaryPurple,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: primaryPurple.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  AutoSizeText(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
                ],
              ),
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// UPLOAD / GANTI GAMBAR BARANG → Sinkron ke item_types DAN inventory
  //////////////////////////////////////////////////////////
  Future<void> _uploadItemImage(
      String categoryId, String itemId, String itemName) async {
    
    final labFolder = await _getLabFolderName();

    final XFile? pickedFile = await showModalBottomSheet<XFile?>(
      // ignore: use_build_context_synchronously
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

    setState(() => _isLoading = true);

    try {
      final file = File(pickedFile.path);

      final docSnap = await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .collection('item_types')
          .doc(itemId)
          .get();

      final oldPublicId = docSnap.data()?['imagePublicId'] as String?;

      // Folder hanya: lab_items/{labId-NamaLab}/
      final result = await _cloudinary.uploadAndReplaceImage(
        file: file,
        folder: 'lab_items/$labFolder',
        publicId: 'item_$itemId',
        oldPublicId: oldPublicId,
      );

      if (result != null) {
        // ✅ PERBAIKAN: Gunakan method service untuk sinkronisasi ke item_types DAN inventory
        await _firestoreService.updateItemImage(
          widget.labId,
          categoryId,
          itemId,
          result['url'],
          result['publicId'],
        );

        _showSnackBar(
          message: 'Gambar "$itemName" berhasil diperbarui!',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      } else {
        throw Exception('Gagal mengupload gambar');
      }
    } catch (e) {
      _showSnackBar(
        message: 'Gagal upload gambar',
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //////////////////////////////////////////////////////////
  /// ✅ HAPUS GAMBAR BARANG (Sinkron ke item_types DAN inventory)
  //////////////////////////////////////////////////////////
  Future<void> _deleteItemImage(
      String categoryId, String itemId, String itemName) async {
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Foto', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: Text('Yakin ingin menghapus foto "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 15)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .collection('item_types')
          .doc(itemId)
          .get();

      final publicId = docSnap.data()?['imagePublicId'] as String?;

      // Hapus dari Cloudinary jika ada publicId
      if (publicId != null && publicId.isNotEmpty) {
        await _cloudinary.deleteImage(publicId);
      }

      // ✅ PERBAIKAN: Gunakan method service untuk sinkronisasi hapus ke item_types DAN inventory
      await _firestoreService.deleteItemImage(
        widget.labId,
        categoryId,
        itemId,
      );

      _showSnackBar(
        message: 'Foto "$itemName" berhasil dihapus',
        icon: Icons.check_circle_rounded,
        bgColor: primaryPurple,
      );
    } catch (e) {
      _showSnackBar(
        message: 'Gagal menghapus foto: ${e.toString()}',
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //////////////////////////////////////////////////////////
  /// VIEW FULL IMAGE
  //////////////////////////////////////////////////////////
  void _viewFullImage(String url) {
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
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                url,
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
    );
  }

  //////////////////////////////////////////////////////////
  /// TAMBAH KATEGORI
  //////////////////////////////////////////////////////////
  Future<void> _tambahKategori() async {
    final name = _kategoriController.text.trim();
    if (name.isEmpty) {
      _showSnackBar(message: 'Nama kategori wajib diisi', icon: Icons.warning_amber_rounded, bgColor: Colors.orange.shade800);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final existing = await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .where('name', isEqualTo: name)
          .get();
      if (existing.docs.isNotEmpty) {
        _showSnackBar(message: 'Kategori "$name" sudah ada', icon: Icons.info_outline_rounded, bgColor: Colors.blueGrey.shade700);
        setState(() => _isLoading = false);
        return;
      }
      await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .add({'name': name, 'createdAt': Timestamp.now()});
      _kategoriController.clear();
      _showSnackBar(message: 'Kategori "$name" berhasil ditambahkan', icon: Icons.check_circle_rounded, bgColor: primaryPurple);
    } catch (e) {
      _showSnackBar(message: 'Gagal menambah kategori: ${e.toString()}', icon: Icons.error_outline_rounded, bgColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //////////////////////////////////////////////////////////
  /// ✅ TAMBAH NAMA BARANG BARU (DENGAN SATUAN) - DIPERBAIKI
  //////////////////////////////////////////////////////////
  Future<void> _tambahItemBaru(String categoryId, TextEditingController nameController, String satuan) async {
    final name = nameController.text.trim();
    final finalSatuan = satuan.isEmpty ? 'Unit' : satuan;
    
    if (name.isEmpty) return;
    
    try {
      final existing = await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .collection('item_types')
          .where('name', isEqualTo: name)
          .get();
      if (existing.docs.isNotEmpty) {
        _showSnackBar(message: 'Nama barang "$name" sudah ada', icon: Icons.info_outline_rounded, bgColor: Colors.blueGrey.shade700);
        return;
      }
      await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .collection('item_types')
          .add({
            'name': name, 
            'satuan': finalSatuan, // ✅ SIMPAN SATUAN
            'createdAt': Timestamp.now()
          });
      nameController.clear();
      _showSnackBar(message: 'Nama barang "$name" ($finalSatuan) berhasil ditambahkan', icon: Icons.check_circle_rounded, bgColor: primaryPurple);
    } catch (e) {
      _showSnackBar(message: 'Gagal menambah nama barang', icon: Icons.error_outline_rounded, bgColor: Colors.red.shade700);
    }
  }

  //////////////////////////////////////////////////////////
  /// EDIT KATEGORI
  //////////////////////////////////////////////////////////
  Future<void> _editKategori(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: TextField(controller: controller, decoration: _inputDecoration('Nama Kategori')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 15))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(context);
                return;
              }
              setState(() => _isLoading = true);
              try {
                await _firestoreService.updateCategoryName(widget.labId, id, currentName, newName);
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                _showSnackBar(message: 'Kategori "$currentName" berhasil diubah menjadi "$newName"', icon: Icons.check_circle_rounded, bgColor: primaryPurple);
              } catch (e) {
                _showSnackBar(message: 'Gagal mengedit kategori: ${e.toString()}', icon: Icons.error_outline_rounded, bgColor: Colors.red.shade700);
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// HAPUS KATEGORI + SEMUA GAMBAR DI CLOUDINARY ✅ DIPERBAIKI
  //////////////////////////////////////////////////////////
  Future<void> _hapusKategori(String categoryId, String categoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: Text('Yakin ingin menghapus "$categoryName"?\n\nSemua barang di dalamnya akan ikut terhapus!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 15))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Semua', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .collection('item_types')
          .get();

      for (var itemDoc in itemsSnapshot.docs) {
        final data = itemDoc.data();
        final publicId = data['imagePublicId'] as String?;
        if (publicId != null && publicId.isNotEmpty) {
          try {
            await _cloudinary.deleteImage(publicId);
          } catch (e) {
            if (kDebugMode) {
              print('Gagal menghapus gambar $publicId: $e');
            }
          }
        }
      }

      await _firestoreService.deleteCategoryAndRelated(widget.labId, categoryId, categoryName);

      _showSnackBar(
        message: 'Kategori "$categoryName" beserta semua barang berhasil dihapus',
        icon: Icons.check_circle_rounded,
        bgColor: primaryPurple,
      );
    } catch (e) {
      _showSnackBar(message: 'Gagal menghapus kategori: ${e.toString()}', icon: Icons.error_outline_rounded, bgColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //////////////////////////////////////////////////////////
  /// HAPUS NAMA BARANG + GAMBAR
  //////////////////////////////////////////////////////////
  Future<void> _hapusItem(String categoryId, String itemId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Nama Barang', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: Text('Yakin ingin menghapus nama barang "$name"?\n\nSemua data inventaris dengan nama ini akan ikut terhapus!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 15))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .collection('item_types')
          .doc(itemId)
          .get();

      final oldPublicId = docSnap.data()?['imagePublicId'] as String?;

      if (oldPublicId != null && oldPublicId.isNotEmpty) {
        await _cloudinary.deleteImage(oldPublicId);
      }

      await _firestoreService.deleteItemTypeAndRelatedInventory(widget.labId, categoryId, itemId, name);

      _showSnackBar(message: 'Nama barang "$name" beserta unit berhasil dihapus', icon: Icons.check_circle_rounded, bgColor: primaryPurple);
    } catch (e) {
      _showSnackBar(message: 'Gagal menghapus nama barang: ${e.toString()}', icon: Icons.error_outline_rounded, bgColor: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  //////////////////////////////////////////////////////////
  /// ✅ EDIT NAMA BARANG + SATUAN (DROPDOWN + MANUAL INPUT)
  //////////////////////////////////////////////////////////
  Future<void> _editItem(String categoryId, String itemId, String currentName, String currentUnit) async {
    final nameController = TextEditingController(text: currentName);
    
    // ✅ Logika Dropdown & Manual Input untuk Edit
    String selectedUnit = defaultUnits.contains(currentUnit) ? currentUnit : 'Lainnya...';
    bool isManual = !defaultUnits.contains(currentUnit);
    final manualController = TextEditingController(text: isManual ? currentUnit : '');

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          String getCurrentUnit() {
            if (isManual) {
              return manualController.text.trim().isEmpty ? 'Unit' : manualController.text.trim();
            }
            return selectedUnit;
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Edit Nama Barang', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController, 
                  decoration: _inputDecoration('Nama Barang'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedUnit,
                  decoration: _inputDecoration('Satuan'),
                  isExpanded: true,
                  items: [
                    ...defaultUnits.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                    const DropdownMenuItem(value: 'Lainnya...', child: Text('Lainnya...')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedUnit = val!;
                      isManual = val == 'Lainnya...';
                    });
                  },
                ),
                if (isManual) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: manualController,
                    decoration: _inputDecoration('Satuan Lainnya'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 15))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final newUnit = getCurrentUnit();
                  
                  if (newName.isEmpty || (newName == currentName && newUnit == currentUnit)) {
                    Navigator.pop(context);
                    return;
                  }
                  setState(() => _isLoading = true);
                  try {
                    await _firestoreService.updateItemNameAndUnit(
                      widget.labId, 
                      categoryId, 
                      itemId, 
                      currentName, 
                      newName,
                      currentUnit,
                      newUnit,
                    );
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                    _showSnackBar(
                      message: 'Berhasil diubah: "$newName" ($newUnit)', 
                      icon: Icons.check_circle_rounded, 
                      bgColor: primaryPurple
                    );
                  } catch (e) {
                    _showSnackBar(message: 'Gagal mengedit: ${e.toString()}', icon: Icons.error_outline_rounded, bgColor: Colors.red.shade700);
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  //////////////////////////////////////////////////////////
  /// ✅ SECTION NAMA BARANG (DENGAN GAMBAR & SATUAN)
  //////////////////////////////////////////////////////////
  Widget _itemSection(String categoryId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // ✅ Gunakan StatefulWidget khusus untuk mengelola state Dropdown & Manual Input
        _AddItemForm(
          categoryId: categoryId,
          labId: widget.labId,
          inputDecoration: _inputDecoration,
          onAddItem: _tambahItemBaru,
          primaryPurple: primaryPurple,
        ),
        const SizedBox(height: 24),
        const Text('Daftar Nama Barang:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('labs')
              .doc(widget.labId)
              .collection('categories')
              .doc(categoryId)
              .collection('item_types')
              .orderBy('name')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Belum ada nama barang', style: TextStyle(color: Colors.grey, fontSize: 14))),
              );
            }
            final items = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final doc = items[index];
                final data = doc.data() as Map<String, dynamic>;
                final itemName = data['name'] as String? ?? 'Unknown';
                final itemUnit = data['satuan'] as String? ?? 'Unit'; // ✅ BACA SATUAN
                final imageUrl = data['imageUrl'] as String?;
                final itemId = doc.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryPurple.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (imageUrl != null && imageUrl.isNotEmpty) {
                            _viewFullImage(imageUrl);
                          } else {
                            _uploadItemImage(categoryId, itemId, itemName);
                          }
                        },
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                            image: imageUrl != null && imageUrl.isNotEmpty
                                ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                : null,
                          ),
                          child: imageUrl == null || imageUrl.isEmpty
                              ? const Center(child: Icon(Icons.add_a_photo_rounded, color: primaryPurple, size: 32))
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                                children: [
                                  TextSpan(text: itemName),
                                  const TextSpan(text: ' '),
                                  TextSpan(
                                    text: '($itemUnit)',
                                    style: const TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w400, 
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: primaryPurple, size: 22), 
                            onPressed: () => _editItem(categoryId, itemId, itemName, itemUnit), 
                            constraints: const BoxConstraints(), 
                            padding: EdgeInsets.zero
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22), 
                            onPressed: () => _hapusItem(categoryId, itemId, itemName), 
                            constraints: const BoxConstraints(), 
                            padding: EdgeInsets.zero
                          ),
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: primaryPurple, size: 22),
                              onPressed: () => _uploadItemImage(categoryId, itemId, itemName),
                              tooltip: 'Ganti Foto',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
                              onPressed: () => _deleteItemImage(categoryId, itemId, itemName),
                              tooltip: 'Hapus Foto',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ] else
                            IconButton(
                              icon: const Icon(Icons.add_a_photo_rounded, color: primaryPurple, size: 22),
                              onPressed: () => _uploadItemImage(categoryId, itemId, itemName),
                              tooltip: 'Upload Foto',
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  //////////////////////////////////////////////////////////
  /// UI UTAMA
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AutoSizeText("Kelola Kategori & Barang", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3), maxLines: 1, minFontSize: 17),
            AutoSizeText("Laboratorium ${widget.labId}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.1), maxLines: 1, minFontSize: 11),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: softPurple,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: primaryPurple.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _kategoriController, decoration: _inputDecoration('Nama Kategori Baru')),
                const SizedBox(height: 20),
                _mainButton(title: 'Tambah Kategori', icon: Icons.add_circle_outline_rounded, onTap: _tambahKategori, isLoading: _isLoading),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daftar Kategori & Nama Barang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('labs')
                  .doc(widget.labId)
                  .collection('categories')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryPurple));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Center(child: Text('Belum ada kategori', style: TextStyle(color: Colors.grey.shade600, fontSize: 15)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snap.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] as String? ?? 'Unknown';
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: primaryPurple.withValues(alpha: 0.5), width: 1.2)),
                        color: softPurple,
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: AutoSizeText(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                          leading: IconButton(icon: const Icon(Icons.edit, color: primaryPurple, size: 22), onPressed: () => _editKategori(doc.id, name), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22), onPressed: () => _hapusKategori(doc.id, name), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                          children: [
                            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: _itemSection(doc.id)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _kategoriController.dispose();
    super.dispose();
  }
}

//////////////////////////////////////////////////////////
/// ✅ WIDGET KHUSUS UNTUK FORM TAMBAH BARANG (DROPDOWN + MANUAL INPUT)
//////////////////////////////////////////////////////////
class _AddItemForm extends StatefulWidget {
  final String categoryId;
  final String labId;
  final InputDecoration Function(String) inputDecoration;
  final Future<void> Function(String categoryId, TextEditingController nameController, String satuan) onAddItem;
  final Color primaryPurple;

  const _AddItemForm({
    required this.categoryId,
    required this.labId,
    required this.inputDecoration,
    required this.onAddItem,
    required this.primaryPurple,
  });

  @override
  State<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends State<_AddItemForm> {
  static const List<String> _defaultUnits = ['PCS', 'Unit', 'Set', 'Kotak', 'Gulung'];
  
  final _itemController = TextEditingController();
  String _selectedUnit = 'Unit';
  bool _isManual = false;
  final _manualController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  String get _currentSatuan {
    if (_isManual) {
      return _manualController.text.trim().isEmpty ? 'Unit' : _manualController.text.trim();
    }
    return _selectedUnit;
  }

  Future<void> _submit() async {
    await widget.onAddItem(widget.categoryId, _itemController, _currentSatuan);
    // ✅ Reset ke default setelah berhasil menambah
    setState(() {
      _selectedUnit = 'Unit';
      _isManual = false;
      _manualController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Disesuaikan agar tetap rapi saat TextField manual muncul
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _itemController,
                decoration: widget.inputDecoration('Nama barang baru'),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedUnit,
                    decoration: widget.inputDecoration('Satuan').copyWith(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    isExpanded: true,
                    items: [
                      ..._defaultUnits.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                      const DropdownMenuItem(value: 'Lainnya...', child: Text('Lainnya...')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedUnit = val!;
                        _isManual = val == 'Lainnya...';
                      });
                    },
                  ),
                  if (_isManual) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _manualController,
                      decoration: widget.inputDecoration('Satuan Lainnya').copyWith(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
              onPressed: _submit,
              child: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}