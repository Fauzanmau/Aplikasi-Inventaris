import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:lab/utils/barcode_scanner_page.dart';
import '../../models/barang_model.dart';
import '../../services/firestore_service.dart';

class InputBarangScreen extends StatefulWidget {
  final String labId;
  final String? preselectedCategoryId;
  final String? preselectedCategoryName;
  final String? preselectedItemId;
  final String? preselectedItemName;

  const InputBarangScreen({
    super.key,
    required this.labId,
    this.preselectedCategoryId,
    this.preselectedCategoryName,
    this.preselectedItemId,
    this.preselectedItemName,
  });

  @override
  State<InputBarangScreen> createState() => _InputBarangScreenState();
}

class _InputBarangScreenState extends State<InputBarangScreen> {
  static const primaryPurple = Color(0xFFA020F0);
  static const softPurple = Color(0xFFF3E8FF);

  final _sn = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _keterangan = TextEditingController();
  final _satuan = TextEditingController(text: 'Unit');
  final _fs = FirestoreService();

  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedItemId;
  String? _selectedItemName;
  String _condition = 'BAIK';
  bool _loading = false;

  // ✅ FIELD BARU: Untuk menyimpan image data dari item_types master
  String? _tempImageUrl;
  String? _tempImagePublicId;

  // ✅ BARU: Helper untuk sanitize serial number ke Firestore document ID
  String _sanitizeSerialForDocId(String serial) {
    return serial.replaceAll('/', '_');
  }

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.preselectedCategoryId;
    _selectedCategoryName = widget.preselectedCategoryName;
    _selectedItemId = widget.preselectedItemId;
    _selectedItemName = widget.preselectedItemName;
    
    // ✅ AUTO-FILL SATUAN + IMAGE JIKA PRESELECTED
    if (widget.preselectedItemId != null && widget.preselectedCategoryId != null) {
      _fetchItemData(widget.preselectedCategoryId!, widget.preselectedItemId!);
    }
  }

  // ✅ FETCH SATUAN + IMAGE DARI ITEM_TYPES MASTER
  Future<void> _fetchItemData(String categoryId, String itemId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('labs')
          .doc(widget.labId)
          .collection('categories')
          .doc(categoryId)
          .collection('item_types')
          .doc(itemId)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data();
        
        // Fetch satuan
        final satuan = data?['satuan'] as String?;
        if (satuan != null && satuan.isNotEmpty) {
          setState(() {
            _satuan.text = satuan;
          });
        }
        
        // ✅ Fetch image data dari master
        setState(() {
          _tempImageUrl = data?['imageUrl'] as String?;
          _tempImagePublicId = data?['imagePublicId'] as String?;
        });
      }
    } catch (e) {
      // Ignore error
    }
  }

  //////////////////////////////////////////////////////////
  /// SNACKBAR CUSTOM
  //////////////////////////////////////////////////////////
  void _showCustomSnackBar({
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
  /// SIMPAN DATA
  //////////////////////////////////////////////////////////
  Future<void> _simpan() async {
    final sn = _sn.text.trim();
    final qty = int.tryParse(_quantity.text) ?? 0;
    final keterangan = _keterangan.text.trim();
    final satuan = _satuan.text.trim().isEmpty ? 'Unit' : _satuan.text.trim();

    if (sn.isEmpty || _selectedCategoryId == null || _selectedItemId == null || qty <= 0) {
      _showCustomSnackBar(
        message: 'Serial number, kategori, nama barang, dan quantity wajib diisi',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final labDoc = await FirebaseFirestore.instance.collection('labs').doc(widget.labId).get();
      if (!labDoc.exists) throw Exception('Lab tidak ditemukan');

      final labData = labDoc.data() as Map<String, dynamic>;
      final labName = labData['name'] ?? widget.labId;

      final int availableQty = _condition == 'BAIK' ? qty : 0;
      final int damagedQty = _condition == 'RUSAK' ? qty : 0;

      final barang = BarangModel(
        id: '',
        serialNumber: sn,
        labId: widget.labId,
        labName: labName,
        categoryId: _selectedCategoryId!,
        categoryName: _selectedCategoryName ?? '',
        itemId: _selectedItemId!,
        itemName: _selectedItemName ?? '',
        condition: _condition,
        totalQuantity: qty,
        availableQuantity: availableQty,
        damagedQuantity: damagedQty,
        satuan: satuan,
        keterangan: keterangan.isNotEmpty ? keterangan : null,
        // ✅ AMBIL IMAGE DARI MASTER (jika ada)
        imageUrl: _tempImageUrl,
        imagePublicId: _tempImagePublicId,
        tanggalInput: Timestamp.now(),
        riwayat: [],
      );

      await _fs.addBarang(widget.labId, barang);

      _resetForm();
      _showCustomSnackBar(
        message: 'Barang baru berhasil ditambahkan',
        icon: Icons.check_circle_rounded,
        bgColor: primaryPurple,
      );
    } catch (e) {
      if (e.toString().contains('Serial Number sudah terdaftar')) {
        final addQty = await _showAddQuantityDialog();
        if (addQty != null && addQty > 0) {
          try {
            // 1. Tambah quantity dulu
            await _fs.addQuantity(widget.labId, _sn.text.trim(), addQty);
            
            // ✅ 2. TAMBAHAN: Jika keterangan diisi, update juga field keterangan di Firestore
            if (keterangan.isNotEmpty) {    
              // ✅ DIPERBAIKI: gunakan helper function untuk sanitasi
              await FirebaseFirestore.instance
                  .collection('labs')
                  .doc(widget.labId)
                  .collection('inventory')
                  .doc(_sanitizeSerialForDocId(_sn.text.trim()))
                  .update({
                    'keterangan': keterangan,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
            }
            
            _resetForm();
            _showCustomSnackBar(
              message: 'Stok berhasil ditambahkan sebanyak $addQty',
              icon: Icons.add_circle_outline_rounded,
              bgColor: primaryPurple,
            );
          } catch (addError) {
            _showError(addError.toString());
          }
        }
      } else {
        _showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _sn.clear();
    _quantity.text = '1';
    _keterangan.clear();
    _satuan.text = 'Unit';
    // ✅ RESET JUGA IMAGE TEMP
    _tempImageUrl = null;
    _tempImagePublicId = null;
  }

  void _showError(String err) {
    String errorMessage = 'Gagal menyimpan: ${err.replaceAll('Exception: ', '')}';
    _showCustomSnackBar(
      message: errorMessage,
      icon: Icons.error_outline_rounded,
      bgColor: Colors.red.shade700,
      duration: const Duration(milliseconds: 3200),
    );
  }

  //////////////////////////////////////////////////////////
  /// DIALOG TAMBAH QUANTITY
  //////////////////////////////////////////////////////////
  Future<int?> _showAddQuantityDialog() async {
    final controller = TextEditingController(text: _quantity.text);

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Serial Number Sudah Ada', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Serial number sudah terdaftar. Tambahkan stok?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Jumlah Stok'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx, qty);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sn.dispose();
    _quantity.dispose();
    _keterangan.dispose();
    _satuan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPreselected = widget.preselectedCategoryId != null && widget.preselectedItemId != null;

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
            const AutoSizeText("Input Barang", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            AutoSizeText("Laboratorium ${widget.labId}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: softPurple,
                borderRadius: BorderRadius.circular(18),
                // ignore: deprecated_member_use
                border: Border.all(color: primaryPurple.withOpacity(0.5), width: 1.2),
              ),
              child: Column(
                children: [
                  // Serial Number
                  _textField(controller: _sn, label: 'Serial Number'),
                  const SizedBox(height: 12),
                  
                  // Quantity
                  _textField(
                    controller: _quantity,
                    label: 'Quantity',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  
                  // Keterangan (Compact - max 2 lines)
                  TextField(
                    controller: _keterangan,
                    maxLines: 2,
                    decoration: _inputDecoration('Keterangan (Opsional)').copyWith(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Satuan (DISABLED - Read Only)
                  _disabledTextField(label: 'Satuan', value: _satuan.text),
                  const SizedBox(height: 16),

                  // Kategori & Nama Barang (Disabled jika preselected)
                  if (isPreselected) ...[
                    _disabledTextField(label: 'Kategori', value: _selectedCategoryName ?? '-'),
                    const SizedBox(height: 12),
                    _disabledTextField(label: 'Nama Barang', value: _selectedItemName ?? '-'),
                    const SizedBox(height: 16),
                  ],

                  // Kondisi
                  DropdownButtonFormField<String>(
                    initialValue: _condition,
                    items: const [
                      DropdownMenuItem(value: 'BAIK', child: Text('Baik')),
                      DropdownMenuItem(value: 'RUSAK', child: Text('Rusak')),
                    ],
                    onChanged: (v) => setState(() => _condition = v!),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    dropdownColor: Colors.white,
                    iconEnabledColor: primaryPurple,
                    isExpanded: true,
                    decoration: _inputDecoration('Kondisi').copyWith(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons (Lebih compact)
                  _mainButton(
                    title: "Scan Serial Number",
                    icon: Icons.qr_code_scanner,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BarcodeScannerPage(
                            onDetect: (sn) => setState(() => _sn.text = sn),
                          ),
                        ),
                      );
                    },
                    loading: false,
                  ),
                  const SizedBox(height: 12),
                  _mainButton(
                    title: "Simpan",
                    icon: null,
                    onTap: _simpan,
                    loading: _loading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TextField Disabled (untuk Satuan, Kategori, Nama Barang)
  Widget _disabledTextField({required String label, required String value}) {
    return TextField(
      controller: TextEditingController(text: value),
      enabled: false,
      decoration: _inputDecoration(label).copyWith(
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      style: const TextStyle(color: Colors.grey, fontSize: 14),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w500, fontSize: 13),
      floatingLabelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w600, fontSize: 13),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
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

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: _inputDecoration(label),
    );
  }

  Widget _mainButton({
    required String title,
    IconData? icon,
    required VoidCallback onTap,
    required bool loading,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        height: 50, // ✅ Lebih compact (dari 55 jadi 50)
        decoration: BoxDecoration(
          color: loading ? Colors.grey : primaryPurple,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: primaryPurple.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  AutoSizeText(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                  ),
                ],
              ),
      ),
    );
  }
}