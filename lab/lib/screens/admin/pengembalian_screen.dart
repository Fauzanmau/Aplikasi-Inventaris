import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../services/firestore_service.dart';
import '../../models/barang_model.dart';
import '../../models/riwayat_model.dart';
import '../../utils/barcode_scanner_page.dart';

// Warna global
const primaryPurple = Color(0xFFA020F0);
const softPurple = Color(0xFFF3E8FF);
// Warna shade yang aman
const grey800 = Color(0xFF424242);
const red700 = Color(0xFFD32F2F);
const orange800 = Color(0xFFEF6C00);
const blueGrey700 = Color(0xFF455A64);
const grey700 = Color(0xFF616161);

// 🛠 HELPER: Sanitize serial number untuk Firestore document ID
String _sanitizeSerialForDocId(String serial) {
  return serial.replaceAll('/', '_');
}

class PengembalianScreen extends StatefulWidget {
  final String labId;
  const PengembalianScreen({
    super.key,
    required this.labId,
  });

  @override
  State<PengembalianScreen> createState() => _PengembalianScreenState();
}

class _PengembalianScreenState extends State<PengembalianScreen> {
  final FirestoreService _fs = FirestoreService();
  final List<Map<String, dynamic>> _itemsDipilih = [];

  //////////////////////////////////////////////////////
  /// NOTIFIKASI CUSTOM
  //////////////////////////////////////////////////////
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
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //////////////////////////////////////////////////////
  /// VIEW FULL IMAGE
  //////////////////////////////////////////////////////
  void _viewFullImage(String url) {
    if (!mounted) return;
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

  //////////////////////////////////////////////////////
  /// SCAN BARANG
  //////////////////////////////////////////////////////
  Future<void> _scanBarang(String sn) async {
    if (!mounted) return;
    try {
      final barang = await _fs.getBarang(widget.labId, sn);
      if (!mounted) return;
      
      if (barang == null) {
        _showSnackBar(message: 'Barang dengan SN "$sn" tidak ditemukan', icon: Icons.search_off_rounded, bgColor: grey800);
        return;
      }
      if (barang.condition == 'RUSAK') {
        _showSnackBar(message: 'Barang rusak, tidak sedang dipinjam', icon: Icons.report_problem_rounded, bgColor: red700);
        return;
      }
      
      // ✅ PERBAIKAN: Karena riwayat dihapus saat dikembalikan, semua riwayat yang ada adalah AKTIF
      // Tidak perlu filter r.tanggalKembali == null lagi
      final openRiwayats = barang.riwayat;
      
      if (openRiwayats.isEmpty) {
        _showSnackBar(message: 'Barang ini tidak sedang dipinjam', icon: Icons.info_outline_rounded, bgColor: blueGrey700);
        return;
      }

      RiwayatPeminjaman selectedRiwayat;
      if (openRiwayats.length == 1) {
        selectedRiwayat = openRiwayats.first;
      } else {
        if (!mounted) return;
        final result = await Navigator.push<RiwayatPeminjaman>(
          context,
          MaterialPageRoute(builder: (_) => _RiwayatPickerFullScreen(
            openRiwayats: openRiwayats, 
            barang: barang,
            alreadySelected: _itemsDipilih,
          )),
        );
        if (result == null || !mounted) return;
        selectedRiwayat = result;
      }

      // Cek duplikat dengan kombinasi yang lebih spesifik
      final sudahAda = _itemsDipilih.any((item) =>
          item['barang'].serialNumber == sn &&
          item['riwayat'].uidPeminjam == selectedRiwayat.uidPeminjam &&
          item['riwayat'].tanggalPinjam == selectedRiwayat.tanggalPinjam);

      if (sudahAda) {
        _showSnackBar(message: 'Peminjaman ini sudah ada di daftar pengembalian', icon: Icons.info_outline_rounded, bgColor: blueGrey700);
        return;
      }

      if (!mounted) return;
      setState(() => _itemsDipilih.add({'barang': barang, 'riwayat': selectedRiwayat}));
      _showSnackBar(message: 'Barang berhasil ditambahkan', icon: Icons.check_circle_rounded, bgColor: primaryPurple);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(message: 'Gagal memuat barang: ${e.toString().replaceAll('Exception: ', '')}', icon: Icons.error_outline_rounded, bgColor: red700);
    }
  }

  //////////////////////////////////////////////////////
  /// PROSES PENGEMBALIAN (DIPERBARUI)
  //////////////////////////////////////////////////////
  Future<void> _kembalikanSemua() async {
    if (!mounted) return;
    if (_itemsDipilih.isEmpty) {
      _showSnackBar(message: 'Belum ada barang yang dipilih', icon: Icons.warning_amber_rounded, bgColor: orange800);
      return;
    }
    int successCount = 0;
    List<String> errors = [];
    for (final item in _itemsDipilih) {
      try {
        // ✅ DIPERBARUI: Menambahkan parameter tanggalPinjam agar sesuai dengan FirestoreService terbaru
        await _fs.kembalikanBarangSpecific(
          widget.labId,
          item['barang'].serialNumber,
          item['riwayat'].uidPeminjam,
          item['riwayat'].tanggalPinjam,
        );
        successCount++;
      } catch (e) {
        errors.add('SN ${item['barang'].serialNumber}: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
    if (!mounted) return;
    if (successCount == _itemsDipilih.length) {
      _showSnackBar(message: 'Pengembalian berhasil untuk $successCount barang', icon: Icons.check_circle_rounded, bgColor: primaryPurple);
      setState(() => _itemsDipilih.clear());
    } else {
      final msg = errors.isEmpty ? 'Gagal memproses pengembalian' : 'Sebagian gagal:\n${errors.join('\n')}';
      _showSnackBar(message: msg, icon: Icons.error_outline_rounded, bgColor: red700);
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
            AutoSizeText("Pengembalian", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3), maxLines: 1, minFontSize: 17),
            AutoSizeText("Laboratorium ${widget.labId}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.1), maxLines: 1, minFontSize: 12),
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
              children: [
                _mainButton(title: "Scan Serial Number", icon: Icons.qr_code_scanner, onTap: () {
                  if (mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BarcodeScannerPage(onDetect: _scanBarang)));
                  }
                }, loading: false),
                const SizedBox(height: 24),
                _mainButton(title: "Proses Pengembalian", icon: Icons.logout, onTap: _kembalikanSemua, loading: false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text('Daftar Barang Dikembalikan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _itemsDipilih.isEmpty
                ? const Center(child: Text('Belum ada barang yang dipindai', style: TextStyle(color: Colors.grey, fontSize: 15)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _itemsDipilih.length,
                    itemBuilder: (context, index) {
                      final item = _itemsDipilih[index];
                      final BarangModel barang = item['barang'];
                      final RiwayatPeminjaman riwayat = item['riwayat'];
                      return StreamBuilder<DocumentSnapshot<BarangModel>>(
                        // ✅ SUDAH DIPERBAIKI: sanitize serialNumber untuk document ID
                        stream: _fs.getInventoryRef(widget.labId).doc(_sanitizeSerialForDocId(barang.serialNumber)).snapshots(),
                        builder: (context, barangSnap) {
                          if (!mounted) return const SizedBox.shrink();
                          final BarangModel currentBarang = barangSnap.data?.data() ?? barang;
                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(riwayat.uidPeminjam).snapshots(),
                            builder: (context, userSnap) {
                              if (!mounted) return const SizedBox.shrink();
                              String namaLengkap = riwayat.peminjam;
                              String nim = riwayat.nim;
                              String kelas = riwayat.kelas;
                              String? photoUrl;
                              if (userSnap.hasData && userSnap.data!.exists) {
                                final dataUser = userSnap.data!.data() as Map<String, dynamic>;
                                namaLengkap = dataUser['namaLengkap'] ?? riwayat.peminjam;
                                nim = dataUser['nim'] ?? riwayat.nim;
                                kelas = dataUser['kelas'] ?? riwayat.kelas;
                                photoUrl = dataUser['photoUrl'] as String?;
                              }
                              final updatedRiwayat = riwayat.copyWith(peminjam: namaLengkap, nim: nim, kelas: kelas);
                              return _barangCard(currentBarang, updatedRiwayat, photoUrl);
                            },
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

  //////////////////////////////////////////////////////////
  /// MAIN BUTTON
  //////////////////////////////////////////////////////////
  Widget _mainButton({required String title, IconData? icon, required VoidCallback onTap, required bool loading}) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: loading ? Colors.grey : primaryPurple,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: primaryPurple.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 22), const SizedBox(width: 10)],
                  AutoSizeText(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, minFontSize: 14),
                ],
              ),
      ),
    );
  }

  //////////////////////////////////////////////////////
  /// BARANG CARD UTAMA
  //////////////////////////////////////////////////////
  Widget _barangCard(BarangModel b, RiwayatPeminjaman r, String? photoUrl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: softPurple,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('labs')
                    .doc(widget.labId)
                    .collection('categories')
                    .doc(b.categoryId)
                    .collection('item_types')
                    .doc(b.itemId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!mounted) return const SizedBox.shrink();
                  String? imageUrl;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    imageUrl = data?['imageUrl'] as String?;
                  }
                  return GestureDetector(
                    onTap: () {
                      if (!mounted) return;
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        _viewFullImage(imageUrl);
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
                          ? const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28))
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${b.categoryName} • ${b.itemName.isNotEmpty ? b.itemName : "—"}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${r.quantity} ${b.satuan}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryPurple),
                    ),
                    const SizedBox(height: 6),
                    Text('SN: ${b.serialNumber}', style: TextStyle(color: grey700, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (!mounted) return;
                  setState(() => _itemsDipilih.removeWhere((item) =>
                      item['barang'].serialNumber == b.serialNumber &&
                      item['riwayat'].uidPeminjam == r.uidPeminjam &&
                      item['riwayat'].tanggalPinjam == r.tanggalPinjam));
                },
              ),
            ],
          ),
          if (b.keterangan != null && b.keterangan!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryPurple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: primaryPurple.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: primaryPurple, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.keterangan!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (!mounted) return;
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    _viewFullImage(photoUrl);
                  }
                },
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: softPurple,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person, color: primaryPurple, size: 28) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.peminjam} • ${r.kelas}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text('NIM: ${r.nim}', style: TextStyle(color: grey700, fontSize: 12)),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(r.uidPeminjam).snapshots(),
                      builder: (context, userSnap) {
                        if (!mounted) return const SizedBox.shrink();
                        String prodi = '';
                        if (userSnap.hasData && userSnap.data!.exists) {
                          final dataUser = userSnap.data!.data() as Map<String, dynamic>;
                          prodi = dataUser['prodi'] ?? '';
                        }
                        return prodi.isNotEmpty
                            ? AutoSizeText(prodi, style: TextStyle(color: grey700, fontSize: 12), maxLines: 2, minFontSize: 11)
                            : const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================== HALAMAN PILIH PENGEMBALIAN ==================
class _RiwayatPickerFullScreen extends StatefulWidget {
  final List<RiwayatPeminjaman> openRiwayats;
  final BarangModel barang;
  final List<Map<String, dynamic>> alreadySelected;

  const _RiwayatPickerFullScreen({
    required this.openRiwayats,
    required this.barang,
    required this.alreadySelected,
  });

  @override
  State<_RiwayatPickerFullScreen> createState() => _RiwayatPickerFullScreenState();
}

class _RiwayatPickerFullScreenState extends State<_RiwayatPickerFullScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _keyword = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ==================== FILTER PENCARIAN PENGEMBALIAN ====================

  /// Menerapkan filter pencarian pada daftar riwayat peminjaman.
  List<RiwayatPeminjaman> _applyFiltersPengembalian(List<RiwayatPeminjaman> riwayats) {
    List<RiwayatPeminjaman> result = riwayats;

    // ✅ DIPERBARUI: Lakukan pencarian berdasarkan NIM atau Nama Peminjam (case-insensitive)
    if (_keyword.isNotEmpty) {
      final lowerKeyword = _keyword.toLowerCase();
      result = result.where((e) => 
        e.nim.toLowerCase().startsWith(lowerKeyword) ||
        e.peminjam.toLowerCase().contains(lowerKeyword)
      ).toList();
    }

    return result;
  }

  List<RiwayatPeminjaman> _filterAlreadySelected(List<RiwayatPeminjaman> riwayats) {
    return riwayats.where((r) {
      return !widget.alreadySelected.any((item) =>
          item['barang'].serialNumber == widget.barang.serialNumber &&
          item['riwayat'].uidPeminjam == r.uidPeminjam &&
          item['riwayat'].tanggalPinjam == r.tanggalPinjam);
    }).toList();
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      // ✅ DIPERBARUI: Label dan hint disesuaikan agar user tahu bisa cari pakai nama
      labelText: 'NIM / Nama',
      labelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: primaryPurple, fontWeight: FontWeight.w600),
      hintText: 'Cari NIM atau Nama...',
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: Icon(Icons.search_rounded, color: primaryPurple.withValues(alpha: 0.8), size: 22),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primaryPurple, width: 2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  //////////////////////////////////////////////////////
  /// VIEW FULL IMAGE
  //////////////////////////////////////////////////////
  void _viewFullImage(String url) {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final availableRiwayats = _filterAlreadySelected(widget.openRiwayats);
    final filteredRiwayats = _applyFiltersPengembalian(availableRiwayats);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryPurple,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Pilih Pengembalian', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: _searchDecoration(),
              style: const TextStyle(color: Colors.black87),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  if (mounted) setState(() => _keyword = value.trim().toUpperCase());
                });
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<BarangModel>>(
                // ✅ DIPERBAIKI: sanitize serialNumber untuk document ID
                stream: FirebaseFirestore.instance
                    .collection('labs')
                    .doc(widget.barang.labId)
                    .collection('inventory')
                    .doc(_sanitizeSerialForDocId(widget.barang.serialNumber))
                    .withConverter<BarangModel>(
                      fromFirestore: (snap, _) => BarangModel.fromDocument(snap),
                      toFirestore: (barang, _) => barang.toMap(),
                    )
                    .snapshots(),
                builder: (context, barangSnap) {
                  if (barangSnap.data != null && !barangSnap.data!.exists) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) Navigator.pop(context);
                    });
                    return const Center(child: Text('Barang telah dihapus', style: TextStyle(color: Colors.grey, fontSize: 15)));
                  }

                  if (!mounted) return const SizedBox.shrink();
                  
                  return filteredRiwayats.isEmpty
                      ? const Center(child: Text('Tidak ada pengembalian yang sesuai atau sudah dipilih', style: TextStyle(color: Colors.grey, fontSize: 15)))
                      : ListView.builder(
                          itemCount: filteredRiwayats.length,
                          itemBuilder: (context, index) {
                            if (!mounted) return const SizedBox.shrink();
                            final r = filteredRiwayats[index];
                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').doc(r.uidPeminjam).snapshots(),
                              builder: (context, userSnap) {
                                if (!mounted) return const SizedBox.shrink();
                                String namaLengkap = r.peminjam;
                                String nim = r.nim;
                                String kelas = r.kelas;
                                String? photoUrl;
                                if (userSnap.hasData && userSnap.data!.exists) {
                                  final dataUser = userSnap.data!.data() as Map<String, dynamic>;
                                  namaLengkap = dataUser['namaLengkap'] ?? r.peminjam;
                                  nim = dataUser['nim'] ?? r.nim;
                                  kelas = dataUser['kelas'] ?? r.kelas;
                                  photoUrl = dataUser['photoUrl'] as String?;
                                }
                                return _barangCardPicker(r, namaLengkap, nim, kelas, photoUrl);
                              },
                            );
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barangCardPicker(RiwayatPeminjaman r, String namaLengkap, String nim, String kelas, String? photoUrl) {
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        Navigator.pop(context, r);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: softPurple,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryPurple.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('labs')
                      .doc(widget.barang.labId)
                      .collection('categories')
                      .doc(widget.barang.categoryId)
                      .collection('item_types')
                      .doc(widget.barang.itemId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!mounted) return const SizedBox.shrink();
                    String? imageUrl;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      imageUrl = data?['imageUrl'] as String?;
                    }
                    return GestureDetector(
                      onTap: () {
                        if (!mounted) return;
                        if (imageUrl != null && imageUrl.isNotEmpty) {
                          _viewFullImage(imageUrl);
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
                            ? const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28))
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<DocumentSnapshot<BarangModel>>(
                        stream: FirebaseFirestore.instance
                            .collection('labs')
                            .doc(widget.barang.labId)
                            .collection('inventory')
                            .doc(_sanitizeSerialForDocId(widget.barang.serialNumber))
                            .withConverter<BarangModel>(
                              fromFirestore: (snap, _) => BarangModel.fromDocument(snap),
                              toFirestore: (barang, _) => barang.toMap(),
                            )
                            .snapshots(),
                        builder: (context, barangSnap) {
                          if (!mounted) return const SizedBox.shrink();
                          final BarangModel currentBarang = barangSnap.data?.data() ?? widget.barang;
                          return Text(
                            '${currentBarang.categoryName} • ${currentBarang.itemName.isNotEmpty ? currentBarang.itemName : "—"}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<DocumentSnapshot<BarangModel>>(
                        stream: FirebaseFirestore.instance
                            .collection('labs')
                            .doc(widget.barang.labId)
                            .collection('inventory')
                            .doc(_sanitizeSerialForDocId(widget.barang.serialNumber))
                            .withConverter<BarangModel>(
                              fromFirestore: (snap, _) => BarangModel.fromDocument(snap),
                              toFirestore: (barang, _) => barang.toMap(),
                            )
                            .snapshots(),
                        builder: (context, barangSnap) {
                          if (!mounted) return const SizedBox.shrink();
                          final BarangModel currentBarang = barangSnap.data?.data() ?? widget.barang;
                          return Text(
                            '${r.quantity} ${currentBarang.satuan}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryPurple),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text('SN: ${widget.barang.serialNumber}', style: TextStyle(color: grey700, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            StreamBuilder<DocumentSnapshot<BarangModel>>(
              stream: FirebaseFirestore.instance
                  .collection('labs')
                  .doc(widget.barang.labId)
                  .collection('inventory')
                  .doc(_sanitizeSerialForDocId(widget.barang.serialNumber))
                  .withConverter<BarangModel>(
                    fromFirestore: (snap, _) => BarangModel.fromDocument(snap),
                    toFirestore: (barang, _) => barang.toMap(),
                  )
                  .snapshots(),
              builder: (context, barangSnap) {
                if (!mounted) return const SizedBox.shrink();
                final BarangModel currentBarang = barangSnap.data?.data() ?? widget.barang;
                if (currentBarang.keterangan == null || currentBarang.keterangan!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryPurple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: primaryPurple.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: primaryPurple, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentBarang.keterangan!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 24),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (!mounted) return;
                    if (photoUrl != null && photoUrl.isNotEmpty) {
                      _viewFullImage(photoUrl);
                    }
                  },
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: softPurple,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? const Icon(Icons.person, color: primaryPurple, size: 28)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$namaLengkap • $kelas',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text('NIM: $nim', style: TextStyle(color: grey700, fontSize: 12)),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(r.uidPeminjam).snapshots(),
                        builder: (context, userSnap) {
                          if (!mounted) return const SizedBox.shrink();
                          String prodi = '';
                          if (userSnap.hasData && userSnap.data!.exists) {
                            final dataUser = userSnap.data!.data() as Map<String, dynamic>;
                            prodi = dataUser['prodi'] ?? '';
                          }
                          return prodi.isNotEmpty
                              ? AutoSizeText(prodi, style: TextStyle(color: grey700, fontSize: 12), maxLines: 2, minFontSize: 11)
                              : const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}