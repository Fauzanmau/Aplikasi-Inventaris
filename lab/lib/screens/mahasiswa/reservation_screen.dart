import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/reservation_model.dart';
import '../../services/firestore_service.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({super.key});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  static const Color primaryPurple = Color(0xFFA020F0);
  static const Color softPurple = Color(0xFFF3E8FF);
  static const Color grey700 = Color(0xFF616161);

  List<ReservationModel> _currentReservations = [];

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  // ================== VIEW FULL IMAGE ==================
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

  // ✅ NOTIFIKASI CUSTOM (Sama persis dengan MahasiswaCategoryDetailScreen)
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

  // ================== STATUS CHIP ==================
  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    if (status == ReservationModel.dipesan) {
      bgColor = Colors.orange.withOpacity(0.15);
      textColor = Colors.orange.shade800;
      label = 'Dipesan';
      icon = Icons.inventory_2_outlined;
    } else {
      bgColor = Colors.red.withOpacity(0.15);
      textColor = Colors.red.shade800;
      label = 'Dibatalkan';
      icon = Icons.cancel_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================== DIALOG KONFIRMASI ==================
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 19)),
        content: Text(message, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ================== HAPUS RESERVASI (SATU) ==================
  Future<void> _deleteSingleReservation(String id, String status) async {
    final confirmed = await _showConfirmDialog(
      title: 'Hapus Reservasi',
      message: 'Apakah Anda yakin ingin menghapus reservasi ini?\n\nReservasi akan dibatalkan dan stok barang akan dikembalikan.',
      confirmText: 'Hapus',
      confirmColor: Colors.red,
    );

    if (confirmed != true || !mounted) return;

    try {
      if (status == ReservationModel.dipesan) {
        await FirestoreService().cancelReservation(id);
      }
      await FirestoreService().deleteReservation(id);

      if (mounted) {
        _showCustomSnackBar(
          message: 'Reservasi berhasil dihapus.',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple, // ✅ Warna Ungu
        );
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(
          message: 'Gagal menghapus: ${e.toString()}',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    }
  }

  // ================== HAPUS SEMUA RESERVASI ==================
  Future<void> _deleteAllReservations() async {
    if (_currentReservations.isEmpty) {
      _showCustomSnackBar(
        message: 'Tidak ada reservasi untuk dihapus',
        icon: Icons.info_outline,
        bgColor: Colors.grey.shade700, // ✅ Warna Abu-abu sesuai permintaan
      );
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Hapus Semua Reservasi',
      message: 'Apakah Anda yakin ingin menghapus semua reservasi?\n\nSeluruh reservasi akan dibatalkan dan stok barang akan dikembalikan.',
      confirmText: 'Hapus Semua',
      confirmColor: Colors.red,
    );

    if (confirmed != true || !mounted) return;

    try {
      for (var res in _currentReservations) {
        if (res.status == ReservationModel.dipesan) {
          await FirestoreService().cancelReservation(res.id);
        }
        await FirestoreService().deleteReservation(res.id);
      }

      if (mounted) {
        _showCustomSnackBar(
          message: 'Semua reservasi berhasil dihapus.',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple, // ✅ Warna Ungu
        );
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(
          message: 'Gagal menghapus semua: ${e.toString()}',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    }
  }

  // ================== CARD DESIGN ==================
  Widget _buildReservationCard(ReservationModel res) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Gambar Barang
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('labs')
                    .doc(res.labId)
                    .collection('categories')
                    .doc(res.categoryId)
                    .collection('item_types')
                    .doc(res.itemId)
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
                  );
                },
              ),
              const SizedBox(width: 16),

              // 2. Info Barang
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${res.categoryName} • ${res.itemName}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${res.quantity} ${res.satuan}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'SN: Belum ditentukan',
                      style: TextStyle(color: grey700, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    Text(
                      '${res.labId} - ${res.labName}',
                      style: const TextStyle(color: grey700, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // 3. Status & Tombol Hapus Per Card
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(res.status),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                    tooltip: 'Hapus Reservasi',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteSingleReservation(res.id, res.status),
                  ),
                ],
              ),
            ],
          ),

          // 4. Keterangan (Opsional)
          if (res.catatan != null && res.catatan!.trim().isNotEmpty) ...[
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
                      res.catatan!,
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

          // 5. Tanggal
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 15, color: primaryPurple),
              const SizedBox(width: 6),
              Text(
                'Dibuat: ${_formatDate(res.createdAt)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 15, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'Harus kembali: ${_formatDate(res.tanggalHarusKembali)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: primaryPurple,
          title: const Text('Reservasi'),
          centerTitle: true,
        ),
        body: const Center(child: Text('Sesi login telah berakhir.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryPurple,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Reservasi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Hapus Semua Reservasi',
            onPressed: _deleteAllReservations,
          ),
        ],
      ),
      body: StreamBuilder<List<ReservationModel>>(
        stream: FirestoreService().getReservationsByUid(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryPurple));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Terjadi kesalahan saat memuat data.', style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            );
          }

          _currentReservations = snapshot.data ?? [];

          // Filter hanya menampilkan 'dipesan' dan 'dibatalkan'
          final filteredReservations = _currentReservations.where((r) => 
            r.status == ReservationModel.dipesan || 
            r.status == ReservationModel.dibatalkan
          ).toList();

          if (filteredReservations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada reservasi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reservasi yang Anda buat akan muncul di sini.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredReservations.length,
            itemBuilder: (context, index) {
              return _buildReservationCard(filteredReservations[index]);
            },
          );
        },
      ),
    );
  }
}