// FILE 1: kelola_laboratorium_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/firestore_service.dart';

const Color primaryPurple = Color(0xFFA020F0);
const Color softPurple = Color(0xFFF3E8FF);

class KelolaLaboratoriumScreen extends StatefulWidget {
  const KelolaLaboratoriumScreen({super.key});

  @override
  State<KelolaLaboratoriumScreen> createState() => _KelolaLaboratoriumScreenState();
}

class _KelolaLaboratoriumScreenState extends State<KelolaLaboratoriumScreen> {
  final FirestoreService _firestoreService = FirestoreService();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryPurple,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const AutoSizeText(
          'Kelola Laboratorium',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          minFontSize: 17,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('labs')
            .orderBy(FieldPath.documentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apartment_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada laboratorium',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final labId = doc.id;
              final data = doc.data() as Map<String, dynamic>;
              final labName = data['name'] ?? 'Tanpa Nama';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: softPurple,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: primaryPurple.withValues(alpha: 0.3),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: primaryPurple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.desktop_mac_rounded,
                            color: primaryPurple,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                labId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                labName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_rounded, color: primaryPurple),
                          onPressed: () => _showEditLabDialog(labId, labName),
                        ),
                        IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete_rounded, color: Colors.red),
                          onPressed: () => _showDeleteLabDialog(labId, labName),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: _showAddLabDialog,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  void _showAddLabDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddLabDialog(
        parentContext: context,
        onSubmit: (id, name) async {
          await _firestoreService.addLab(labId: id, labName: name);
        },
      ),
    ).then((result) {
      if (!mounted) return;
      if (result == true) {
        _showSnackBar(
          message: 'Laboratorium berhasil ditambahkan',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      } else if (result is String) {
        _showSnackBar(
          message: 'Gagal menambahkan: $result',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    });
  }

  void _showEditLabDialog(String oldLabId, String currentName) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditLabDialog(
        parentContext: context,
        oldLabId: oldLabId,
        currentName: currentName,
        onSubmit: (newId, newName) async {
          await _firestoreService.updateLabDetails(oldLabId: oldLabId, newLabId: newId, newName: newName);
        },
      ),
    ).then((result) {
      if (!mounted) return;
      if (result == true) {
        _showSnackBar(
          message: 'Laboratorium berhasil diperbarui',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      } else if (result is String) {
        _showSnackBar(
          message: 'Gagal memperbarui: $result',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    });
  }

  void _showDeleteLabDialog(String labId, String labName) {
    showDialog(
      context: context,
      builder: (dialogContext) => _DeleteLabDialog(
        parentContext: context,
        labId: labId,
        labName: labName,
        onSubmit: (id) async {
          await _firestoreService.deleteLab(id);
        },
      ),
    ).then((result) {
      if (!mounted) return;
      if (result == true) {
        _showSnackBar(
          message: 'Laboratorium berhasil dihapus',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      } else if (result is String) {
        _showSnackBar(
          message: 'Gagal menghapus: $result',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    });
  }
}

// =====================================================
// DIALOG WIDGETS (StatefulWidget untuk Lifecycle Aman)
// =====================================================

class _AddLabDialog extends StatefulWidget {
  final BuildContext parentContext;
  final Future<void> Function(String id, String name) onSubmit;

  const _AddLabDialog({
    required this.parentContext,
    required this.onSubmit,
  });

  @override
  State<_AddLabDialog> createState() => _AddLabDialogState();
}

class _AddLabDialogState extends State<_AddLabDialog> {
  late final TextEditingController _labIdController;
  late final TextEditingController _labNameController;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _labIdController = TextEditingController();
    _labNameController = TextEditingController();
  }

  @override
  void dispose() {
    _labIdController.dispose();
    _labNameController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w500, fontSize: 14.5),
      floatingLabelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w600, fontSize: 14.5),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Tambah Laboratorium',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labIdController,
            decoration: _inputDecoration('Kode Laboratorium'),
            textCapitalization: TextCapitalization.none,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labNameController,
            decoration: _inputDecoration('Nama Laboratorium'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isAdding ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 15)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isAdding
              ? null
              : () async {
                  final id = _labIdController.text.trim();
                  final name = _labNameController.text.trim();

                  if (id.isEmpty || name.isEmpty) {
                    Navigator.of(context).pop('Data tidak boleh kosong');
                    return;
                  }

                  if (id.contains('/') || id.contains(' ')) {
                    Navigator.of(context).pop('Kode tidak boleh mengandung / atau spasi');
                    return;
                  }

                  setState(() => _isAdding = true);

                  try {
                    await widget.onSubmit(id, name);
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isAdding = false);
                    final errorMessage = e.toString().replaceFirst('Exception: ', '');
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop(errorMessage);
                  }
                },
          child: _isAdding
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }
}

class _EditLabDialog extends StatefulWidget {
  final BuildContext parentContext;
  final String oldLabId;
  final String currentName;
  final Future<void> Function(String newId, String newName) onSubmit;

  const _EditLabDialog({
    required this.parentContext,
    required this.oldLabId,
    required this.currentName,
    required this.onSubmit,
  });

  @override
  State<_EditLabDialog> createState() => _EditLabDialogState();
}

class _EditLabDialogState extends State<_EditLabDialog> {
  late final TextEditingController _labIdController;
  late final TextEditingController _labNameController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _labIdController = TextEditingController(text: widget.oldLabId);
    _labNameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _labIdController.dispose();
    _labNameController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w500, fontSize: 14.5),
      floatingLabelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w600, fontSize: 14.5),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Edit Laboratorium',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labIdController,
            decoration: _inputDecoration('Kode Laboratorium'),
            textCapitalization: TextCapitalization.none,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labNameController,
            decoration: _inputDecoration('Nama Laboratorium'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isEditing ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 15)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isEditing
              ? null
              : () async {
                  final newId = _labIdController.text.trim();
                  final newName = _labNameController.text.trim();

                  if (newId.isEmpty || newName.isEmpty) {
                    Navigator.of(context).pop('Data tidak boleh kosong');
                    return;
                  }

                  if (newId.contains('/') || newId.contains(' ')) {
                    Navigator.of(context).pop('Kode tidak boleh mengandung / atau spasi');
                    return;
                  }

                  setState(() => _isEditing = true);

                  try {
                    await widget.onSubmit(newId, newName);
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isEditing = false);
                    final errorMessage = e.toString().replaceFirst('Exception: ', '');
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop(errorMessage);
                  }
                },
          child: _isEditing
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      ],
    );
  }
}

class _DeleteLabDialog extends StatefulWidget {
  final BuildContext parentContext;
  final String labId;
  final String labName;
  final Future<void> Function(String id) onSubmit;

  const _DeleteLabDialog({
    required this.parentContext,
    required this.labId,
    required this.labName,
    required this.onSubmit,
  });

  @override
  State<_DeleteLabDialog> createState() => _DeleteLabDialogState();
}

class _DeleteLabDialogState extends State<_DeleteLabDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Hapus Laboratorium',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
      ),
      content: Text(
        'Yakin ingin menghapus laboratorium "${widget.labName}" (${widget.labId})?\n\nSeluruh kategori, barang, dan data inventaris juga akan ikut terhapus!',
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500, fontSize: 15)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isDeleting
              ? null
              : () async {
                  setState(() => _isDeleting = true);

                  try {
                    await widget.onSubmit(widget.labId);
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop(true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isDeleting = false);
                    final errorMessage = e.toString().replaceFirst('Exception: ', '');
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop(errorMessage);
                  }
                },
          child: _isDeleting
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : const Text('Hapus', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}