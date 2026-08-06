import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/riwayat_model.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  static const primaryPurple = Color(0xFFA020F0);
  static const softPurple = Color(0xFFF3E8FF);

  String _selectedLab = 'Semua';
  Timer? _timer;

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

  // ================== VIEW FULL IMAGE (Reusable) ==================
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

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ PERUBAHAN: Hapus Scaffold dan AppBar
    // Langsung kembalikan konten body agar tidak ada AppBar ganda
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          _buildFilterLab(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('inventory')
                  .snapshots(),
              builder: (context, inventorySnap) {
                if (inventorySnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!inventorySnap.hasData || inventorySnap.data!.docs.isEmpty) {
                  return const Center(child: Text('Tidak ada data inventory'));
                }

                final activeBorrowings = _processActiveBorrowings(inventorySnap.data!.docs);

                if (activeBorrowings.isEmpty) {
                  return const Center(
                    child: Text(
                      'Tidak ada peminjaman aktif saat ini',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                activeBorrowings.sort((a, b) {
                  final ta = (a['riwayat'] as RiwayatPeminjaman).tanggalPinjam;
                  final tb = (b['riwayat'] as RiwayatPeminjaman).tanggalPinjam;
                  return tb.compareTo(ta);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeBorrowings.length,
                  itemBuilder: (context, index) {
                    final item = activeBorrowings[index];
                    final r = item['riwayat'] as RiwayatPeminjaman;
                    final bool telat = _isTelat(r.tanggalHarusKembali);
                    final labFull = '${item['labId']} - ${item['labName']}';

                    return _buildBorrowingCard(
                      item: item,
                      riwayat: r,
                      telat: telat,
                      labFull: labFull,
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

  List<Map<String, dynamic>> _processActiveBorrowings(List<QueryDocumentSnapshot> docs) {
    final activeBorrowings = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final labId = data['labId'] ?? '';
      final labName = data['labName'] ?? '';
      final serialNumber = data['serialNumber'] ?? '-';
      final categoryName = data['categoryName'] ?? '-';
      final itemName = data['itemName'] ?? '-';
      final satuan = data['satuan'] ?? 'Unit';
      final keterangan = data['keterangan'] as String?;

      if (_selectedLab != 'Semua' && labId != _selectedLab) continue;

      final List<dynamic> riwayatList = data['riwayat'] ?? [];
      for (final r in riwayatList) {
        final riwayatMap = r as Map<String, dynamic>;
        final riwayat = RiwayatPeminjaman.fromMap(riwayatMap);

        activeBorrowings.add({
          'labId': labId,
          'labName': labName,
          'serialNumber': serialNumber,
          'categoryName': categoryName,
          'itemName': itemName,
          'satuan': satuan,
          'keterangan': keterangan,
          'inventoryDocId': doc.id,
          'categoryId': data['categoryId'],
          'itemId': data['itemId'],
          'riwayat': riwayat,
        });
      }
    }

    return activeBorrowings;
  }

  // ================== CARD PEMINJAMAN ==================
  Widget _buildBorrowingCard({
    required Map<String, dynamic> item,
    required RiwayatPeminjaman riwayat,
    required bool telat,
    required String labFull,
  }) {
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
              // ================== GAMBAR BARANG (BISA DIKLIK) ==================
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('labs')
                    .doc(item['labId'] ?? '')
                    .collection('categories')
                    .doc(item['categoryId'] ?? '')
                    .collection('item_types')
                    .doc(item['itemId'] ?? '')
                    .snapshots(),
                builder: (context, snapshot) {
                  String? imageUrl;

                  if (item['categoryId'] == null || 
                      item['itemId'] == null || 
                      item['categoryId'].toString().isEmpty || 
                      item['itemId'].toString().isEmpty) {
                    return Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28),
                      ),
                    );
                  }

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

              // Info Barang
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['categoryName']} • ${item['itemName']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${riwayat.quantity} ${item['satuan']}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SN: ${item['serialNumber']}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                    // ✅ DIPERBAIKI: Ubah maxLines dari 1 menjadi 2 agar teks laboratorium tidak terpotong
                    AutoSizeText(
                      labFull,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      maxLines: 2,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              _statusBadge(telat),
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

          // ================== INFO MAHASISWA DENGAN FOTO PROFIL (BISA DIKLIK) ==================
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(riwayat.uidPeminjam)
                .snapshots(),
            builder: (context, userSnap) {
              String namaLengkap = riwayat.peminjam;
              String nim = riwayat.nim;
              String kelas = riwayat.kelas;
              String prodi = '';
              String? photoUrl;

              if (userSnap.hasData && userSnap.data!.exists) {
                final userData = userSnap.data!.data() as Map<String, dynamic>;
                namaLengkap = userData['namaLengkap'] ?? riwayat.peminjam;
                nim = userData['nim'] ?? riwayat.nim;
                kelas = userData['kelas'] ?? riwayat.kelas;
                prodi = userData['prodi'] ?? '';
                photoUrl = userData['photoUrl'] as String?;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Tanggal Pinjam & Harus Kembali
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 15, color: primaryPurple),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd MMM yyyy HH:mm').format(riwayat.tanggalPinjam.toDate()),
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
                'Harus kembali: ${DateFormat('dd MMM yyyy').format(riwayat.tanggalHarusKembali.toDate())}',
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
  }

  Widget _statusBadge(bool telat) {
    if (telat) return _badge('Telat', Colors.red.shade700);
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

  // ================== FILTER LABORATORIUM ==================
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
                return const DropdownMenuItem(value: 'Semua', child: Text('Semua'));
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
}