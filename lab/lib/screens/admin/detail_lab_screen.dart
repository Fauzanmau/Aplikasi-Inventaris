import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/firestore_service.dart';
import '../../models/barang_model.dart';
import '../../services/export_service.dart';
import 'item_type_list_screen.dart';
import '../mahasiswa/mahasiswa_item_type_list_screen.dart';

class DetailLabScreen extends StatefulWidget {
  final String labId;
  final bool isMahasiswa;
  final String mode;

  const DetailLabScreen({
    super.key,
    required this.labId,
    this.isMahasiswa = false,
    this.mode = 'inventaris',
  });

  @override
  State<DetailLabScreen> createState() => _DetailLabScreenState();
}

class _DetailLabScreenState extends State<DetailLabScreen> {
  static const primaryPurple = Color(0xFFA020F0);
  final FirestoreService _fs = FirestoreService();

  List<BarangModel> _allItems = [];

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

  Future<void> _editCategory(String categoryId, String currentName) async {
    final controller = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Nama Kategori',
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
          ),
          autofocus: true,
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
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.pop(context);
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('labs')
                    .doc(widget.labId)
                    .collection('categories')
                    .doc(categoryId)
                    .update({
                  'name': newName,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                final inventoryRef = FirebaseFirestore.instance
                    .collection('labs')
                    .doc(widget.labId)
                    .collection('inventory')
                    .where('categoryId', isEqualTo: categoryId);

                final inventorySnap = await inventoryRef.get();
                for (var doc in inventorySnap.docs) {
                  await doc.reference.update({
                    'categoryName': newName,
                  });
                }

                if (!mounted) return;
                Navigator.pop(context);
                _showSnackBar(
                  message: 'Kategori berhasil diubah menjadi "$newName"',
                  icon: Icons.check_circle_rounded,
                  bgColor: primaryPurple,
                );
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showSnackBar(
                    message: 'Gagal mengedit kategori: ${e.toString()}',
                    icon: Icons.error_outline_rounded,
                    bgColor: Colors.red.shade700,
                  );
                }
              }
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(String categoryId, String categoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Kategori', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: Text('Yakin ingin menghapus "$categoryName"?\n\nSemua nama barang dan data inventaris di dalamnya akan ikut terhapus!'),
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
      final itemTypesRef = FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .collection('item_types');

      final itemTypesSnap = await itemTypesRef.get();
      for (var doc in itemTypesSnap.docs) {
        await doc.reference.delete();
      }

      final inventoryRef = FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('inventory')
          .where('categoryId', isEqualTo: categoryId);

      final inventorySnap = await inventoryRef.get();
      for (var doc in inventorySnap.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .delete();

      if (mounted) {
        _showSnackBar(
          message: 'Kategori "$categoryName" berhasil dihapus',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          message: 'Gagal menghapus kategori: ${e.toString()}',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    }
  }

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
            AutoSizeText(
              "Kategori",
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
        ),
        // ✅ Tombol Export HANYA muncul di mode 'inventaris'
        actions: (widget.isMahasiswa || widget.mode != 'inventaris')
            ? []
            : [
                Tooltip(
                  message: 'Export Data Inventaris (PDF / Excel)',
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          ExportService.showExport(
                            context: context,
                            labId: widget.labId,
                            data: _allItems,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.download_for_offline_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Export',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _fs.getCategoriesRef(widget.labId).orderBy('name').snapshots(),
        builder: (context, categorySnap) {
          if (!categorySnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            );
          }

          final categories = categorySnap.data!.docs;

          return StreamBuilder<List<BarangModel>>(
            stream: _fs.getBarangByLab(widget.labId),
            builder: (context, inventorySnap) {
              if (!inventorySnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryPurple),
                );
              }

              final allItems = inventorySnap.data ?? [];
              _allItems = allItems;

              final Map<String, List<BarangModel>> grouped = {};
              final Map<String, String> categoryNameMap = {};

              for (var catDoc in categories) {
                final data = catDoc.data() as Map<String, dynamic>;
                final catName = data['name'] ?? 'Unknown';

                grouped[catDoc.id] = [];
                categoryNameMap[catDoc.id] = catName;
              }

              for (var item in allItems) {
                final key = item.categoryId;

                if (key.isNotEmpty) {
                  grouped.putIfAbsent(key, () => []).add(item);
                }
              }

              final sortedKeys = grouped.keys.toList()
                ..sort((a, b) =>
                    (categoryNameMap[a] ?? '').compareTo(categoryNameMap[b] ?? ''));

              if (sortedKeys.isEmpty) {
                return const Center(
                  child: Text(
                    'Belum ada kategori',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedKeys.length,
                itemBuilder: (context, index) {
                  final categoryId = sortedKeys[index];
                  final categoryName = categoryNameMap[categoryId] ?? 'Unknown';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      leading: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.folder_rounded,
                          color: primaryPurple,
                          size: 42,
                        ),
                      ),
                      title: AutoSizeText(
                        categoryName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        minFontSize: 15,
                      ),
                      subtitle: Text(
                        'Lihat daftar barang',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ PERUBAHAN: Popup edit/hapus kategori
                          // HANYA muncul di mode 'inventaris'
                          // Mode 'input' tidak boleh mengelola kategori
                          if (!widget.isMahasiswa && widget.mode == 'inventaris')
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: primaryPurple, size: 22),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editCategory(categoryId, categoryName);
                                } else if (value == 'delete') {
                                  _deleteCategory(categoryId, categoryName);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, color: primaryPurple, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit Kategori'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                      SizedBox(width: 8),
                                      Text('Hapus Kategori', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: primaryPurple,
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => widget.isMahasiswa
                                ? MahasiswaItemTypeListScreen(
                                    labId: widget.labId,
                                    categoryId: categoryId,
                                    categoryName: categoryName,
                                  )
                                : ItemTypeListScreen(
                                    labId: widget.labId,
                                    categoryId: categoryId,
                                    categoryName: categoryName,
                                    mode: widget.mode,
                                  ),
                          ),
                        );
                      },
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