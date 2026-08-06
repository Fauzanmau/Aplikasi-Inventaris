import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/reservation_model.dart';
import '../../services/firestore_service.dart';
import 'peminjaman_screen.dart';

class AdminReservationScreen extends StatefulWidget {
  const AdminReservationScreen({super.key});

  @override
  State<AdminReservationScreen> createState() => _AdminReservationScreenState();
}

class _AdminReservationScreenState extends State<AdminReservationScreen> {
  static const Color primaryPurple = Color(0xFFA020F0);
  static const Color softPurple = Color(0xFFF3E8FF);

  List<ReservationModel> _currentReservations = [];
  String _selectedLab = 'Semua'; // ✅ Tambahan: State untuk filter laboratorium

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
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

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 19,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSingleReservation(String id, String status) async {
    if (status == ReservationModel.dipesan) {
      _showCustomSnackBar(
        message: 'Reservasi harus ditolak terlebih dahulu sebelum dihapus.',
        icon: Icons.warning_amber_rounded,
        bgColor: Colors.orange.shade800,
      );
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Hapus Reservasi',
      message: 'Apakah Anda yakin ingin menghapus reservasi ini secara permanen?',
      confirmText: 'Hapus',
      confirmColor: Colors.red,
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirestoreService().deleteReservation(id);

      if (mounted) {
        _showCustomSnackBar(
          message: 'Reservasi berhasil dihapus.',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
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

  Future<void> _deleteAllReservations() async {
    // Tetap menggunakan _currentReservations (semua data) agar bisa membersihkan semua lab
    final deletableReservations = _currentReservations
        .where((r) => r.status == ReservationModel.dibatalkan)
        .toList();

    if (deletableReservations.isEmpty) {
      _showCustomSnackBar(
        message: 'Tidak ada reservasi dibatalkan untuk dihapus. Tolak reservasi terlebih dahulu.',
        icon: Icons.info_outline,
        bgColor: Colors.grey.shade700,
      );
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Hapus Reservasi Dibatalkan',
      message: 'Apakah Anda yakin ingin menghapus semua reservasi yang berstatus dibatalkan secara permanen?',
      confirmText: 'Hapus',
      confirmColor: Colors.red,
    );

    if (confirmed != true || !mounted) return;

    try {
      for (var res in deletableReservations) {
        await FirestoreService().deleteReservation(res.id);
      }

      if (mounted) {
        _showCustomSnackBar(
          message: 'Reservasi dibatalkan berhasil dihapus.',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
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

  Future<void> _approveReservation(ReservationModel res) async {
    final confirmed = await _showConfirmDialog(
      title: 'Konfirmasi',
      message: 'Proses peminjaman barang untuk reservasi ini?',
      confirmText: 'YA',
      confirmColor: primaryPurple,
    );

    if (confirmed != true || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeminjamanScreen(
          labId: res.labId,
          reservation: res,
        ),
      ),
    );
  }

  Future<void> _rejectReservation(String reservationId) async {
    final confirmed = await _showConfirmDialog(
      title: 'Konfirmasi',
      message: 'Apakah Anda yakin ingin menolak reservasi ini?',
      confirmText: 'YA',
      confirmColor: Colors.red,
    );

    if (confirmed != true || !mounted) return;

    try {
      await FirestoreService().cancelReservation(reservationId);

      if (mounted) {
        _showCustomSnackBar(
          message: 'Reservasi berhasil ditolak.',
          icon: Icons.check_circle_rounded,
          bgColor: primaryPurple,
        );
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(
          message: 'Gagal: ${e.toString()}',
          icon: Icons.error_outline_rounded,
          bgColor: Colors.red.shade700,
        );
      }
    }
  }

  // ✅ Tambahan: Widget Filter Laboratorium
  Widget _buildFilterLab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('labs').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        final labList = ['Semua', ...docs.map((e) => e.id)];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: DropdownButtonFormField<String>(
            value: _selectedLab,
            isExpanded: true,
            iconEnabledColor: primaryPurple,
            dropdownColor: Colors.white,
            items: labList.map((lab) {
              if (lab == 'Semua') {
                return const DropdownMenuItem(
                  value: 'Semua',
                  child: Text('Semua'),
                );
              }
              final data = docs.firstWhere((d) => d.id == lab).data() as Map<String, dynamic>;
              final name = data['name'] ?? '';
              return DropdownMenuItem(
                value: lab,
                child: Text('$lab - $name', overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedLab = value);
              }
            },
            decoration: InputDecoration(
              labelText: 'Filter Laboratorium',
              labelStyle: const TextStyle(
                color: primaryPurple,
                fontWeight: FontWeight.w500,
                fontSize: 14.5,
              ),
              floatingLabelStyle: const TextStyle(
                color: primaryPurple,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
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
            ),
          ),
        );
      },
    );
  }

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
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    Text(
                      '${res.labId} - ${res.labName}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(res.status),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    tooltip: 'Hapus Reservasi',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _deleteSingleReservation(res.id, res.status),
                  ),
                ],
              ),
            ],
          ),
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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(res.uid).snapshots(),
            builder: (context, userSnap) {
              String namaLengkap = res.nama;
              String nim = res.nim;
              String kelas = res.kelas;
              String prodi = res.prodi;
              String? photoUrl;

              if (userSnap.hasData && userSnap.data!.exists) {
                final userData = userSnap.data!.data() as Map<String, dynamic>;
                namaLengkap = userData['namaLengkap'] ?? res.nama;
                nim = userData['nim'] ?? res.nim;
                kelas = userData['kelas'] ?? res.kelas;
                prodi = userData['prodi'] ?? res.prodi;
                photoUrl = userData['photoUrl'] as String?;
              }

              return Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (photoUrl != null && photoUrl.isNotEmpty) {
                        _viewFullImage(context, photoUrl);
                      }
                    },
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: softPurple,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty 
                          ? NetworkImage(photoUrl) 
                          : null,
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
                        Text(
                          'NIM: $nim',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                        if (prodi.isNotEmpty)
                          Text(
                            prodi,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
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
          if (res.status == ReservationModel.dipesan) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'Tolak',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _rejectReservation(res.id),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Pinjamkan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _approveReservation(res),
                  ),
                ),
              ],
            ),
          ],
        ],
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
        title: const Text(
          'Reservasi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Hapus Semua Reservasi Dibatalkan',
            onPressed: _deleteAllReservations,
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Tampilan Filter Laboratorium
          _buildFilterLab(),
          
          Expanded(
            child: StreamBuilder<List<ReservationModel>>(
              stream: FirestoreService().getAllReservations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryPurple),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Terjadi kesalahan saat memuat data.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  );
                }

                final allReservations = snapshot.data ?? [];
                
                // ✅ Simpan semua data untuk kebutuhan fungsi hapus semua
                _currentReservations = allReservations; 

                // ✅ Filter data berdasarkan pilihan laboratorium
                final filteredReservations = _selectedLab == 'Semua'
                    ? allReservations
                    : allReservations.where((r) => r.labId == _selectedLab).toList();

                if (filteredReservations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedLab == 'Semua' 
                              ? 'Belum ada reservasi' 
                              : 'Tidak ada reservasi untuk lab ini',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedLab == 'Semua'
                              ? 'Reservasi dari mahasiswa akan muncul di sini.'
                              : 'Coba pilih laboratorium lain atau "Semua".',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
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
          ),
        ],
      ),
    );
  }
}