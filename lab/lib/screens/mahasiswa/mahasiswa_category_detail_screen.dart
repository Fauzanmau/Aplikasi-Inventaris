import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/barang_model.dart';
import '../../models/reservation_model.dart';
import '../../services/firestore_service.dart';

class MahasiswaCategoryDetailScreen extends StatefulWidget {
  final String labId;
  final String categoryId;
  final String categoryName;
  final String itemId;
  final String itemName;

  const MahasiswaCategoryDetailScreen({
    super.key,
    required this.labId,
    required this.categoryId,
    required this.categoryName,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<MahasiswaCategoryDetailScreen> createState() => _MahasiswaCategoryDetailScreenState();
}

class _MahasiswaCategoryDetailScreenState extends State<MahasiswaCategoryDetailScreen> {
  static const primaryPurple = Color(0xFFA020F0);
  static const softPurple = Color(0xFFF3E8FF);
  static const blueColor = Color(0xFF1976D2);

  void _viewFullImage(BuildContext context, String url) {
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
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

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
        borderSide: const BorderSide(color: primaryPurple),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryPurple),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryPurple, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _showReservationDialog(BuildContext context, int maxQuantity, String satuan) async {
    final qtyController = TextEditingController(text: '1');
    final catatanController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Reservasi Barang',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19, color: Colors.black),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: softPurple,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryPurple),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stok tersedia: $maxQuantity $satuan',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Jumlah Barang'),
                    onChanged: (value) {
                      final qty = int.tryParse(value) ?? 0;
                      if (qty > maxQuantity) {
                        qtyController.text = maxQuantity.toString();
                        qtyController.selection = TextSelection.fromPosition(
                          TextPosition(offset: qtyController.text.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: primaryPurple,
                                onPrimary: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: primaryPurple),
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: primaryPurple),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Rencana Kembali: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                              style: const TextStyle(fontSize: 13, color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: catatanController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: _inputDecoration('Catatan (Opsional)').copyWith(
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  final qty = int.tryParse(qtyController.text) ?? 0;
                  if (qty <= 0 || qty > maxQuantity) {
                    _showCustomSnackBar(
                      message: 'Jumlah tidak valid (1 - $maxQuantity)',
                      icon: Icons.warning_amber_rounded,
                      bgColor: Colors.orange.shade800,
                    );
                    return;
                  }

                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (context.mounted) {
                      _showCustomSnackBar(message: 'Sesi login berakhir', icon: Icons.error_outline, bgColor: Colors.red.shade700);
                    }
                    return;
                  }

                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  final userData = userDoc.data() ?? {};

                  final labDoc = await FirebaseFirestore.instance.collection('labs').doc(widget.labId).get();
                  final labName = labDoc.data()?['name'] ?? 'Laboratorium';

                  final reservation = ReservationModel(
                    id: '',
                    uid: user.uid,
                    nama: userData['namaLengkap'] ?? 'Pengguna',
                    nim: userData['nim'] ?? '-',
                    kelas: userData['kelas'] ?? '-',
                    prodi: userData['prodi'] ?? '-',
                    labId: widget.labId,
                    labName: labName,
                    categoryId: widget.categoryId,
                    categoryName: widget.categoryName,
                    itemId: widget.itemId,
                    itemName: widget.itemName,
                    satuan: satuan,
                    quantity: qty,
                    status: ReservationModel.dipesan,
                    catatan: catatanController.text.trim().isEmpty ? null : catatanController.text.trim(),
                    createdAt: Timestamp.now(),
                    tanggalHarusKembali: Timestamp.fromDate(selectedDate),
                  );

                  try {
                    await FirestoreService().createReservation(reservation);
                    
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    
                    if (context.mounted) {
                      _showCustomSnackBar(
                        message: 'Reservasi berhasil dikirim!',
                        icon: Icons.check_circle_rounded,
                        bgColor: primaryPurple,
                      );
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (context.mounted) {
                      _showCustomSnackBar(
                        message: 'Gagal: ${e.toString().replaceAll('Exception: ', '')}',
                        icon: Icons.error_outline_rounded,
                        bgColor: Colors.red.shade700,
                      );
                    }
                  }
                },
                child: const Text('Reservasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ],
          );
        },
      ),
    );
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
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('labs')
              .doc(widget.labId)
              .collection('categories')
              .doc(widget.categoryId)
              .snapshots(),
          builder: (context, catSnap) {
            String catName = widget.categoryName;
            if (catSnap.hasData && catSnap.data!.exists) {
              final data = catSnap.data!.data() as Map<String, dynamic>;
              catName = data['name'] ?? widget.categoryName;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AutoSizeText(
                  'Detail Barang',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                  maxLines: 1,
                  minFontSize: 17,
                ),
                AutoSizeText(
                  catName,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.1),
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
            .collection('inventory')
            .where('categoryId', isEqualTo: widget.categoryId)
            .where('itemId', isEqualTo: widget.itemId)
            .where('condition', isEqualTo: 'BAIK')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryPurple));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Tidak ada barang dalam kondisi baik', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          final baikItems = snapshot.data!.docs
              .map((doc) => BarangModel.fromDocument(doc as DocumentSnapshot<Map<String, dynamic>>))
              .where((b) => b.availableQuantity > 0)
              .toList();

          final totalAvailableUnit = baikItems.fold<int>(
            0,
            (total, barang) => total + barang.availableQuantity,
          );
          
          final satuanBarang = baikItems.isNotEmpty ? baikItems.first.satuan : 'Unit';

          // ✅ DIPERBAIKI: Menggunakan StreamBuilder agar update secara REALTIME
          return StreamBuilder<int>(
            stream: FirestoreService().getReservedQuantityStream(widget.labId, widget.categoryId, widget.itemId),
            builder: (context, reservedSnapshot) {
              // Tampilkan loading hanya di awal saat data benar-benar belum ada
              if (reservedSnapshot.connectionState == ConnectionState.waiting && reservedSnapshot.data == null) {
                return const Center(child: CircularProgressIndicator(color: primaryPurple));
              }

              final reservedQuantity = reservedSnapshot.data ?? 0;
              final stokTersedia = totalAvailableUnit - reservedQuantity;
              final stokDisplay = stokTersedia > 0 ? stokTersedia : 0;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: softPurple,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryPurple.withValues(alpha: 0.5), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: primaryPurple.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            decoration: BoxDecoration(
                              color: primaryPurple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  stokDisplay.toString(),
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: primaryPurple),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Total Stok Tersedia ($satuanBarang)',
                                  style: const TextStyle(fontSize: 15.5, color: Colors.black87, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: baikItems.length,
                      itemBuilder: (context, index) {
                        final barang = baikItems[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: primaryPurple.withValues(alpha: 0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('labs')
                                          .doc(widget.labId)
                                          .collection('categories')
                                          .doc(barang.categoryId)
                                          .collection('item_types')
                                          .doc(barang.itemId)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        String? imageUrl;
                                        String liveItemName = widget.itemName;

                                        if (snapshot.hasData && snapshot.data!.exists) {
                                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                                          imageUrl = data?['imageUrl'] as String?;
                                          liveItemName = data?['name'] ?? widget.itemName;
                                        }

                                        return Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                if (imageUrl != null && imageUrl.isNotEmpty) {
                                                  _viewFullImage(context, imageUrl);
                                                }
                                              },
                                              child: Container(
                                                width: 68,
                                                height: 68,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                                                  image: imageUrl != null && imageUrl.isNotEmpty
                                                      ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                                      : null,
                                                ),
                                                child: imageUrl == null || imageUrl.isEmpty
                                                    ? const Center(
                                                        child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28),
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'SN: ${barang.serialNumber.isEmpty ? "-" : barang.serialNumber}',
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  RichText(
                                                    text: TextSpan(
                                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                                      children: [
                                                        TextSpan(text: liveItemName),
                                                        const TextSpan(text: ' '),
                                                        TextSpan(
                                                          text: '(${barang.satuan})',
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
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: blueColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Baik',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: blueColor),
                                    ),
                                  ),
                                ],
                              ),
                              if (barang.keterangan != null && barang.keterangan!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryPurple.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: primaryPurple.withValues(alpha: 0.2), width: 1),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: primaryPurple, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          barang.keterangan!,
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        // ✅ DIPERBAIKI: Tombol otomatis nonaktif jika stokTersedia <= 0
                        onPressed: stokTersedia > 0
                            ? () => _showReservationDialog(context, stokTersedia, satuanBarang)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade500,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_checkout_rounded, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Reservasi Barang',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}