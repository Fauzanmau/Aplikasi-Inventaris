import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/riwayat_model.dart';

const Color primaryPurple = Color(0xFFA020F0);
const Color softPurple = Color(0xFFF3E8FF);
const Color grey700 = Color(0xFF616161);

class RiwayatMahasiswaScreen extends StatefulWidget {
  const RiwayatMahasiswaScreen({super.key});

  @override
  State<RiwayatMahasiswaScreen> createState() => _RiwayatMahasiswaScreenState();
}

class _RiwayatMahasiswaScreenState extends State<RiwayatMahasiswaScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ================== CEK TELAT ==================
  bool _isTelat(Timestamp? tanggalHarusKembali) {
    if (tanggalHarusKembali == null) return false;

    final DateTime harusKembaliDate = tanggalHarusKembali.toDate();
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dueDay = DateTime(
      harusKembaliDate.year,
      harusKembaliDate.month,
      harusKembaliDate.day,
    );

    return today.isAfter(dueDay);
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

  // ================== FILTER PEMINJAMAN MAHASISWA ==================
  List<Map<String, dynamic>> _getActiveUserBorrowings(
    QuerySnapshot snapshot,
    String userUid,
  ) {
    final List<Map<String, dynamic>> activeBorrowings = [];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final List<dynamic> riwayatList = data['riwayat'] ?? [];

      if (riwayatList.isEmpty) continue;

      final labId = data['labId'] ?? '-';
      final labName = data['labName'] ?? '';
      final serialNumber = data['serialNumber'] ?? '-';
      final categoryName = data['categoryName'] ?? '-';
      final itemName = data['itemName'] ?? '-';
      final categoryId = data['categoryId'];
      final itemId = data['itemId'];
      final satuan = data['satuan'] ?? 'Unit';
      final keterangan = data['keterangan'] as String?;

      for (final r in riwayatList) {
        final riwayatMap = r as Map<String, dynamic>;

        if (riwayatMap['uidPeminjam'] == userUid) {
          activeBorrowings.add({
            'inventoryDoc': doc,
            'labId': labId,
            'labName': labName,
            'serialNumber': serialNumber,
            'categoryName': categoryName,
            'itemName': itemName,
            'satuan': satuan,
            'keterangan': keterangan,
            'categoryId': categoryId,
            'itemId': itemId,
            'riwayat': RiwayatPeminjaman.fromMap(riwayatMap),
          });
        }
      }
    }

    activeBorrowings.sort((a, b) {
      final ta = (a['riwayat'] as RiwayatPeminjaman).tanggalPinjam;
      final tb = (b['riwayat'] as RiwayatPeminjaman).tanggalPinjam;
      return tb.compareTo(ta);
    });

    return activeBorrowings;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: const Center(child: Text('User belum login')),
      );
    }

    // ✅ PERUBAHAN: Hapus Scaffold dan AppBar
    // Langsung kembalikan konten body agar tidak ada AppBar ganda
    return Container(
      color: const Color(0xFFF8FAFC),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('inventory')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text('Tidak ada peminjaman aktif'),
            );
          }

          final activeBorrowings = _getActiveUserBorrowings(snap.data!, user.uid);

          if (activeBorrowings.isEmpty) {
            return const Center(
              child: Text(
                'Tidak ada peminjaman aktif saat ini',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeBorrowings.length,
            itemBuilder: (context, index) {
              final item = activeBorrowings[index];
              final lastRiwayat = item['riwayat'] as RiwayatPeminjaman;

              final categoryName = item['categoryName'] ?? '-';
              final itemName = item['itemName'] ?? '-';
              final serialNumber = item['serialNumber'] ?? '-';
              final labId = item['labId'] ?? '-';
              final labName = item['labName'] ?? '';
              final categoryId = item['categoryId'];
              final itemId = item['itemId'];

              final bool telat = _isTelat(lastRiwayat.tanggalHarusKembali);
              final labFull = '$labId - $labName';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: softPurple,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: primaryPurple.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // ================== GAMBAR BARANG (BISA DIKLIK) ==================
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('labs')
                              .doc(labId)
                              .collection('categories')
                              .doc(categoryId?.toString() ?? '')
                              .collection('item_types')
                              .doc(itemId?.toString() ?? '')
                              .snapshots(),
                          builder: (context, snapshot) {
                            String? imageUrl;
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>?;
                              imageUrl = data?['imageUrl'] as String?;
                            }

                            if (categoryId == null || itemId == null) {
                              return Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                                ),
                                child: const Center(
                                  child: Icon(Icons.image_not_supported_rounded,
                                      color: Colors.grey, size: 28),
                                ),
                              );
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
                                      ? DecorationImage(
                                          image: NetworkImage(imageUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: imageUrl == null || imageUrl.isEmpty
                                    ? const Center(
                                        child: Icon(Icons.image_not_supported_rounded,
                                            color: Colors.grey, size: 28),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 16),

                        // Info Barang + Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$categoryName • $itemName',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${lastRiwayat.quantity} ${item['satuan']}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: primaryPurple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _statusBadge(telat),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'SN: $serialNumber',
                                style: const TextStyle(
                                  color: grey700,
                                  fontSize: 12,
                                ),
                              ),
                              AutoSizeText(
                                labFull,
                                style: const TextStyle(
                                  color: grey700,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                minFontSize: 11,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (item['keterangan'] != null && item['keterangan'].toString().isNotEmpty) ...[
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
                                item['keterangan'],
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
                        const Icon(Icons.calendar_today,
                            size: 15, color: primaryPurple),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy HH:mm')
                              .format(lastRiwayat.tanggalPinjam.toDate()),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 15,
                          color: telat ? Colors.red : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Harus kembali: ${DateFormat('dd MMM yyyy').format(lastRiwayat.tanggalHarusKembali.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: telat ? Colors.red : Colors.orange.shade800,
                          ),
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
    );
  }

  Widget _statusBadge(bool telat) {
    if (telat) {
      return _badge('Telat', Colors.red.shade700);
    }
    return _badge('Dipinjam', Colors.orange.shade800);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}