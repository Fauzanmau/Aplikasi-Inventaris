import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../models/barang_model.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import 'category_detail_screen.dart';
import 'input_barang_screen.dart';

class ItemTypeListScreen extends StatefulWidget {
  final String labId;
  final String categoryId;
  final String categoryName;
  final String mode;

  const ItemTypeListScreen({
    super.key,
    required this.labId,
    required this.categoryId,
    required this.categoryName,
    this.mode = 'inventaris',
  });

  @override
  State<ItemTypeListScreen> createState() => _ItemTypeListScreenState();
}

class _ItemTypeListScreenState extends State<ItemTypeListScreen> {
  static const primaryPurple = Color(0xFFA020F0);
  // ✅ Daftar satuan default untuk Dropdown
  static const List<String> defaultUnits = ['PCS', 'Unit', 'Set', 'Kotak', 'Gulung'];

  final FirestoreService _fs = FirestoreService();
  final CloudinaryService _cloudinary = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  final Map<String, bool> _isLoadingUpload = {};

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
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar({
    required String message,
    required IconData icon,
    required Color bgColor,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    if (!mounted) return;
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

  String _sanitizeFolderName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

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

  Future<void> _uploadItemImageInline(String categoryId, String itemId, String itemName) async {
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

    setState(() => _isLoadingUpload[itemId] = true);

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

      final result = await _cloudinary.uploadAndReplaceImage(
        file: file,
        folder: 'lab_items/$labFolder',
        publicId: 'item_$itemId',
        oldPublicId: oldPublicId,
      );

      if (result != null) {
        await _fs.updateItemImage(
          widget.labId,
          categoryId,
          itemId,
          result['url'],
          result['publicId'],
        );

        if (mounted) {
          _showSnackBar(
            message: 'Gambar "$itemName" berhasil diperbarui!',
            icon: Icons.check_circle_rounded,
            bgColor: primaryPurple,
          );
        }
      } else {
        throw Exception('Gagal mengupload gambar');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          message: 'Gagal upload gambar: ${e.toString()}',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingUpload[itemId] = false);
      }
    }
  }

  Future<void> _deleteItemImageInline(String categoryId, String itemId, String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Foto', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: Text('Yakin ingin menghapus foto "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
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

      if (publicId != null && publicId.isNotEmpty) {
        await _cloudinary.deleteImage(publicId);
      }

      await _fs.deleteItemImage(
        widget.labId,
        categoryId,
        itemId,
      );

      if (mounted) {
        _showSnackBar(
          message: 'Foto "$itemName" berhasil dihapus',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          message: 'Gagal menghapus foto: ${e.toString()}',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    }
  }

  //////////////////////////////////////////////////////////
  /// ✅ EDIT NAMA BARANG + SATUAN (DROPDOWN + MANUAL INPUT)
  /// Hanya method ini yang diperbaiki, yang lain tidak disentuh
  //////////////////////////////////////////////////////////
  Future<void> _editItemInline(String categoryId, String itemId, String currentName, String currentUnit) async {
    final nameController = TextEditingController(text: currentName);

    // ✅ Logika Dropdown & Manual Input untuk Edit
    String selectedUnit = defaultUnits.contains(currentUnit) ? currentUnit : 'Lainnya...';
    bool isManual = !defaultUnits.contains(currentUnit);
    final manualController = TextEditingController(text: isManual ? currentUnit : '');

    InputDecoration unitDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
    }

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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: unitDecoration('Nama Barang'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUnit,
                    decoration: unitDecoration('Satuan'),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: manualController,
                      decoration: unitDecoration('Satuan Lainnya'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final newUnit = getCurrentUnit();

                  if (newName.isEmpty || (newName == currentName && newUnit == currentUnit)) {
                    Navigator.pop(context);
                    return;
                  }

                  try {
                    await _fs.updateItemNameAndUnit(
                      widget.labId,
                      categoryId,
                      itemId,
                      currentName,
                      newName,
                      currentUnit,
                      newUnit,
                    );

                    if (!context.mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                    if (mounted) {
                      _showSnackBar(
                        message: 'Berhasil diubah: "$newName" ($newUnit)',
                        icon: Icons.check_circle_rounded,
                        bgColor: primaryPurple,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      _showSnackBar(
                        message: 'Gagal mengedit: ${e.toString()}',
                        icon: Icons.error_outline_rounded,
                        bgColor: Colors.red.shade700,
                      );
                    }
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

  Future<void> _deleteItemInline(String categoryId, String itemId, String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Nama Barang', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: Text('Yakin ingin menghapus "$itemName"?\n\nSemua data inventaris dengan nama ini akan ikut terhapus!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
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
      if (publicId != null && publicId.isNotEmpty) {
        await _cloudinary.deleteImage(publicId);
      }

      await _fs.deleteItemTypeAndRelatedInventory(widget.labId, categoryId, itemId, itemName);

      if (mounted) {
        _showSnackBar(
          message: '"$itemName" berhasil dihapus',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          message: 'Gagal menghapus: ${e.toString()}',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catId = widget.categoryId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: primaryPurple,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),

        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('labs')
              .doc(widget.labId)
              .collection('categories')
              .doc(catId)
              .snapshots(),
          builder: (context, snapshot) {
            String categoryName = widget.categoryName;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              categoryName = data['name'] ?? widget.categoryName;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AutoSizeText(
                  categoryName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  minFontSize: 17,
                ),
                AutoSizeText(
                  "Laboratorium ${widget.labId}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  minFontSize: 11,
                ),
              ],
            );
          },
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('labs')
            .doc(widget.labId)
            .collection('categories')
            .doc(catId)
            .collection('item_types')
            .orderBy('name')
            .snapshots(),
        builder: (context, itemTypeSnap) {
          if (!itemTypeSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            );
          }

          if (itemTypeSnap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada nama barang di kategori ini',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final itemTypeDocs = itemTypeSnap.data!.docs;

          return StreamBuilder<List<BarangModel>>(
            stream: _fs.getBarangByLab(widget.labId),
            builder: (context, inventorySnap) {
              if (!inventorySnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryPurple),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: itemTypeDocs.length,
                itemBuilder: (context, index) {
                  final doc = itemTypeDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final itemName = data['name'] ?? '';
                  final itemId = doc.id;
                  final imageUrl = data['imageUrl'];
                  final satuan = data['satuan'] ?? 'Unit';

                  final isUploading = _isLoadingUpload[itemId] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ✅ GAMBAR BARANG
                          // Mode inventaris: tap untuk lihat full / upload jika kosong
                          // Mode input: tap hanya untuk lihat full (jika ada gambar)
                          GestureDetector(
                            onTap: () {
                              if (imageUrl != null && imageUrl.toString().isNotEmpty) {
                                _viewFullImage(imageUrl);
                              } else if (widget.mode == 'inventaris') {
                                _uploadItemImageInline(catId, itemId, itemName);
                              }
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: primaryPurple.withValues(alpha: 0.25),
                                      width: 1.5,
                                    ),
                                    image: imageUrl != null && imageUrl.toString().isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(imageUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: (imageUrl == null || imageUrl.toString().isEmpty) &&
                                          widget.mode == 'inventaris'
                                      ? const Center(
                                          child: Icon(
                                            Icons.add_a_photo_rounded,
                                            color: primaryPurple,
                                            size: 28,
                                          ),
                                        )
                                      : null,
                                ),
                                if (isUploading)
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AutoSizeText(
                                  itemName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                  ),
                                  maxLines: 3,
                                  minFontSize: 13,
                                ),
                                const SizedBox(height: 6),
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Satuan: '),
                                      TextSpan(
                                        text: '($satuan)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ✅ POPUP MENU: HANYA tampil di mode 'inventaris'
                          // Mode input: tidak ada menu titik tiga sama sekali
                          if (widget.mode == 'inventaris')
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: primaryPurple, size: 22),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editItemInline(catId, itemId, itemName, satuan);
                                } else if (value == 'photo') {
                                  _uploadItemImageInline(catId, itemId, itemName);
                                } else if (value == 'delete_photo') {
                                  _deleteItemImageInline(catId, itemId, itemName);
                                } else if (value == 'delete') {
                                  _deleteItemInline(catId, itemId, itemName);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, color: primaryPurple, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit Nama Barang'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'photo',
                                  child: Row(
                                    children: [
                                      Icon(Icons.camera_alt_rounded, color: primaryPurple, size: 20),
                                      SizedBox(width: 8),
                                      Text('Ganti Foto'),
                                    ],
                                  ),
                                ),
                                if (imageUrl != null && imageUrl.isNotEmpty)
                                  const PopupMenuItem(
                                    value: 'delete_photo',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Hapus Foto', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                      SizedBox(width: 8),
                                      Text('Hapus Nama Barang', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(width: 8),

                          // ✅ TOMBOL PANAH: Trigger utama navigasi
                          // Mode input → InputBarangScreen
                          // Mode inventaris → CategoryDetailScreen
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: primaryPurple,
                              size: 22,
                            ),
                            onPressed: () {
                              if (widget.mode == 'input') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InputBarangScreen(
                                      labId: widget.labId,
                                      preselectedCategoryId: widget.categoryId,
                                      preselectedCategoryName: widget.categoryName,
                                      preselectedItemId: itemId,
                                      preselectedItemName: itemName,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoryDetailScreen(
                                      labId: widget.labId,
                                      categoryId: widget.categoryId,
                                      categoryName: widget.categoryName,
                                      itemId: itemId,
                                      itemName: itemName,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}