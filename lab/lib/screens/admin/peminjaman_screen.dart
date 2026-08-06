import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../models/riwayat_model.dart';
import '../../models/barang_model.dart';
import '../../models/reservation_model.dart';
import '../../utils/barcode_scanner_page.dart';

const primaryPurple = Color(0xFFA020F0);
const softPurple = Color(0xFFF3E8FF);

class PeminjamanScreen extends StatefulWidget {
  final String labId;
  final ReservationModel reservation;

  const PeminjamanScreen({
    super.key,
    required this.labId,
    required this.reservation,
  });

  @override
  State<PeminjamanScreen> createState() => _PeminjamanScreenState();
}

class _PeminjamanScreenState extends State<PeminjamanScreen> {
  final FirestoreService _fs = FirestoreService();
  final List<Map<String, dynamic>> _itemsDipilih = []; 

  // Helper untuk menghitung total qty yang sudah discan
  int get _currentTotalQty {
    return _itemsDipilih.fold(0, (sum, item) => sum + (item['qty'] as int));
  }

  String _sanitizeSerialForDocId(String serial) {
    return serial.replaceAll('/', '_');
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
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _scanBarang(String sn) async {
    int currentTotalQty = _currentTotalQty;
    int remainingQty = widget.reservation.quantity - currentTotalQty;

    // 1. Maksimal jumlah scan mengikuti sisa quantity reservasi
    if (remainingQty <= 0) {
      _showSnackBar(
        message: 'Jumlah barang reservasi sudah terpenuhi.',
        icon: Icons.info_outline,
        bgColor: Colors.blue[800]!,
      );
      return;
    }

    // 2. Setiap Serial Number hanya boleh discan satu kali
    if (_itemsDipilih.any((item) => item['barang'].serialNumber == sn)) {
      _showSnackBar(
        message: 'Serial Number sudah discan.',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange[800]!,
      );
      return;
    }

    try {
      final barang = await _fs.getBarang(widget.labId, sn);
      
      if (barang == null) {
        _showSnackBar(message: 'Barang dengan SN "$sn" tidak ditemukan', icon: Icons.search_off_rounded, bgColor: Colors.grey[800]!);
        return;
      }
      if (barang.condition != 'BAIK') {
        _showSnackBar(message: 'Barang dalam kondisi rusak, tidak dapat dipinjam', icon: Icons.report_problem_rounded, bgColor: Colors.red[700]!);
        return;
      }
      if (barang.availableQuantity <= 0) {
        _showSnackBar(message: 'Barang sedang dipinjam atau stok tidak tersedia', icon: Icons.lock_rounded, bgColor: Colors.red[700]!);
        return;
      }
      if (barang.itemId != widget.reservation.itemId) {
        _showSnackBar(
          message: 'Serial Number tidak sesuai dengan barang yang direservasi',
          icon: Icons.error_outline,
          bgColor: Colors.red[800]!,
        );
        return;
      }

      if (!mounted) return;

      // Hitung quantity yang akan ditambahkan secara otomatis
      // Ambil yang lebih kecil antara availableQuantity dan remainingQty
      int qtyToAdd = barang.availableQuantity < remainingQty 
          ? barang.availableQuantity 
          : remainingQty;

      setState(() {
        _itemsDipilih.add({
          'barang': barang,
          'qty': qtyToAdd,
          'isReserved': true,
        });
      });

      _showSnackBar(
        message: 'Barang reservasi berhasil discan (Qty: $qtyToAdd)', 
        icon: Icons.check_circle_rounded, 
        bgColor: primaryPurple
      );

    } catch (e) {
      _showSnackBar(message: 'Gagal memuat barang: ${e.toString().replaceAll('Exception: ', '')}', icon: Icons.error_outline_rounded, bgColor: Colors.red[700]!);
    }
  }

  Future<void> _pinjamSemua() async {
    if (_itemsDipilih.isEmpty) {
      _showSnackBar(message: 'Silakan scan barang reservasi terlebih dahulu', icon: Icons.warning_amber_rounded, bgColor: Colors.orange[800]!);
      return;
    }

    // 6. Tombol hanya boleh diproses jika total qty yang discan == quantity reservasi
    int currentTotalQty = _currentTotalQty;
    if (currentTotalQty < widget.reservation.quantity) {
      final sisa = widget.reservation.quantity - currentTotalQty;
      _showSnackBar(
        message: 'Silakan scan $sisa unit lagi.',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange[800]!,
      );
      return;
    }

    // ============================================================
    // VALIDASI ULANG: Cek data terbaru di Firestore sebelum memproses
    // ============================================================
    for (final item in _itemsDipilih) {
      final sn = item['barang'].serialNumber;
      final qtyToBorrow = item['qty'] as int;

      try {
        final latestBarang = await _fs.getBarang(widget.labId, sn);
        
        if (latestBarang == null) {
          _showSnackBar(
            message: 'Barang SN $sn sudah tidak tersedia.',
            icon: Icons.error_outline,
            bgColor: Colors.red[700]!,
          );
          return;
        }
        if (latestBarang.condition != 'BAIK') {
          _showSnackBar(
            message: 'Kondisi barang SN $sn sudah tidak BAIK.',
            icon: Icons.error_outline,
            bgColor: Colors.red[700]!,
          );
          return;
        }
        if (latestBarang.availableQuantity < qtyToBorrow) {
          _showSnackBar(
            message: 'Stok SN $sn sudah berubah. Silakan scan ulang.',
            icon: Icons.error_outline,
            bgColor: Colors.red[700]!,
          );
          return;
        }
      } catch (e) {
        _showSnackBar(
          message: 'Gagal memvalidasi SN $sn: ${e.toString().replaceAll('Exception: ', '')}',
          icon: Icons.error_outline,
          bgColor: Colors.red[700]!,
        );
        return;
      }
    }
    // ============================================================

    int successCount = 0;
    List<String> errors = [];
    
    final riwayatBase = RiwayatPeminjaman(
      uidPeminjam: widget.reservation.uid,
      peminjam: widget.reservation.nama,
      nim: widget.reservation.nim,
      kelas: widget.reservation.kelas,
      tanggalPinjam: Timestamp.now(),
      tanggalHarusKembali: widget.reservation.tanggalHarusKembali,
    );

    for (final item in _itemsDipilih) {
      try {
        // Tetap gunakan fungsi pinjamBarang, kirim qty sesuai jumlah yang dipilih pada setiap SN
        await _fs.pinjamBarang(widget.labId, item['barang'].serialNumber, riwayatBase, item['qty']);
        successCount++;
      } catch (e) {
        errors.add('SN ${item['barang'].serialNumber}: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }

    // ✅ DIPERBARUI: Hapus reservasi setelah seluruh proses peminjaman berhasil
    if (successCount == _itemsDipilih.length) {
      _showSnackBar(message: 'Peminjaman berhasil', icon: Icons.check_circle_rounded, bgColor: primaryPurple);
      
      try {
        await FirestoreService().deleteReservation(
          widget.reservation.id,
        );
      } catch (e) {
        debugPrint('Gagal menghapus reservasi: $e');
      }

      if (!mounted) return;

      // Kembali ke halaman AdminReservationScreen
      Navigator.pop(context);
    } else {
      final msg = errors.isEmpty ? 'Gagal memproses peminjaman' : 'Sebagian gagal:\n${errors.join('\n')}';
      _showSnackBar(message: msg, icon: Icons.error_outline_rounded, bgColor: Colors.red[700]!, duration: const Duration(milliseconds: 4500));
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
              "Proses Peminjaman",
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
              minFontSize: 12,
            ),
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
                _mainButton(
                  title: "Scan Serial Number",
                  icon: Icons.qr_code_scanner,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BarcodeScannerPage(onDetect: _scanBarang))),
                  loading: false,
                ),
                const SizedBox(height: 16),
                _mahasiswaCardCompact(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100, 
                    borderRadius: BorderRadius.circular(14), 
                    border: Border.all(color: Colors.grey.shade300)
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, color: Colors.grey.shade600, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Kembali: ${DateFormat('dd MMM yyyy').format(widget.reservation.tanggalHarusKembali.toDate())}',
                          style: const TextStyle(color: Colors.black87, fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // ✅ DIPERBARUI: Warna teks mengikuti tema (Hitam default, Ungu saat terpenuhi)
                Center(
                  child: Text(
                    'Sudah discan: $_currentTotalQty / ${widget.reservation.quantity}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _currentTotalQty == widget.reservation.quantity 
                          ? primaryPurple 
                          : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _mainButton(title: "Proses Peminjaman", icon: Icons.login, onTap: _pinjamSemua, loading: false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text('Barang Dipinjam', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _itemsDipilih.isEmpty
                ? const Center(child: Text('Silakan scan barang reservasi', style: TextStyle(color: Colors.grey, fontSize: 15)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _itemsDipilih.length,
                    itemBuilder: (context, index) {
                      final item = _itemsDipilih[index];
                      final BarangModel barang = item['barang'];
                      final int qty = item['qty'];

                      return StreamBuilder<DocumentSnapshot<BarangModel>>(
                        stream: _fs.getInventoryRef(widget.labId).doc(_sanitizeSerialForDocId(barang.serialNumber)).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError || (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)) {
                            return _barangCard(
                              barang, 
                              qty, 
                              () {
                                setState(() {
                                  _itemsDipilih.removeAt(index);
                                });
                                _showSnackBar(
                                  message: 'Barang dihapus dari daftar',
                                  icon: Icons.delete_outline,
                                  bgColor: Colors.orange[800]!,
                                );
                              }
                            );
                          }

                          final docSnapshot = snapshot.data;
                          if (docSnapshot != null && !docSnapshot.exists) {
                            return const SizedBox.shrink();
                          }

                          final BarangModel currentBarang = docSnapshot?.data() ?? barang;
                          return _barangCard(
                            currentBarang, 
                            qty, 
                            () {
                              setState(() {
                                _itemsDipilih.removeAt(index);
                              });
                              _showSnackBar(
                                message: 'Barang dihapus dari daftar',
                                icon: Icons.delete_outline,
                                bgColor: Colors.orange[800]!,
                              );
                            }
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

  Widget _mahasiswaCardCompact() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.reservation.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final m = (snapshot.hasData && snapshot.data!.exists) 
            ? (snapshot.data!.data() as Map<String, dynamic>) 
            : {
                'namaLengkap': widget.reservation.nama,
                'nim': widget.reservation.nim,
                'kelas': widget.reservation.kelas,
                'prodi': widget.reservation.prodi,
                'photoUrl': null,
              };
        
        final photoUrl = m['photoUrl'] as String?;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryPurple.withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    _viewFullImage(photoUrl);
                  }
                },
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: softPurple,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? const Icon(Icons.person, color: primaryPurple, size: 32)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      m['namaLengkap'] ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 2,
                      minFontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIM: ${m['nim'] ?? '—'} • ${m['kelas'] ?? '—'}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    if (m['prodi'] != null && m['prodi'].toString().isNotEmpty)
                      AutoSizeText(
                        m['prodi'],
                        style: TextStyle(color: Colors.grey[700], fontSize: 12.8),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
                  AutoSizeText(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 1,
                    minFontSize: 14,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }

  // ✅ DIPERBARUI: Menambahkan parameter onDelete untuk fitur hapus
  Widget _barangCard(BarangModel b, int qty, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softPurple,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
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
                        String? imageUrl;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          imageUrl = data?['imageUrl'] as String?;
                        }

                        return GestureDetector(
                          onTap: () {
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
                                ? const Center(
                                    child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28),
                                  )
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
                          const SizedBox(height: 6),
                          Text(
                            '$qty ${b.satuan}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryPurple),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SN: ${b.serialNumber}',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ✅ TOMBOL HAPUS DITAMBAHKAN DI SINI
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Hapus dari daftar',
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
        ],
      ),
    );
  }
}