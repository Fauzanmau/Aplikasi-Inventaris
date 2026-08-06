import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:lab/utils/barcode_scanner_page.dart';
import '../../services/firestore_service.dart';
import '../../models/barang_model.dart';
import '../../models/reservation_model.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String labId;
  final String categoryId;
  final String categoryName;
  final String itemId;
  final String itemName;
  final bool isMahasiswa;

  const CategoryDetailScreen({
    super.key,
    required this.labId,
    required this.categoryId,
    required this.categoryName,
    required this.itemId,
    required this.itemName,
    this.isMahasiswa = false,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FirestoreService _fs = FirestoreService();

  static const primaryPurple = Color(0xFFA020F0);
  static const softPurple = Color(0xFFF3E8FF);

  String _keyword = '';
  String _filterStatus = 'Semua';

  Map<String, int> _reservedMap = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reservationSubscription;

  String _sanitizeSerialForDocId(String serial) {
    return serial.replaceAll('/', '_');
  }

  @override
  void initState() {
    super.initState();
    _listenToReservations();
  }

  void _listenToReservations() {
    _reservationSubscription = FirebaseFirestore.instance
        .collection('reservations')
        .where('labId', isEqualTo: widget.labId)
        .where('categoryId', isEqualTo: widget.categoryId)
        .where('status', isEqualTo: ReservationModel.dipesan)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      Map<String, int> newReservedMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final itemId = data['itemId'] as String;
        final qty = data['quantity'] as int? ?? 0;
        newReservedMap[itemId] = (newReservedMap[itemId] ?? 0) + qty;
      }

      setState(() {
        _reservedMap = newReservedMap;
      });
    });
  }

  @override
  void dispose() {
    _reservationSubscription?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  int _getRusakUnits(BarangModel barang) => barang.damagedQuantity;
  int _getDipesanUnits(BarangModel barang) => _reservedMap[barang.itemId] ?? 0;

  int _getDipinjamUnits(BarangModel barang) {
    final rusakUnits = _getRusakUnits(barang);
    final nonDamagedUnits = barang.totalQuantity - rusakUnits;
    final totalUnavailable = nonDamagedUnits - barang.availableQuantity;
    final dipesanUnits = _getDipesanUnits(barang);
    
    final dipinjam = totalUnavailable - dipesanUnits;
    return dipinjam.clamp(0, nonDamagedUnits);
  }

  int _getBaikUnits(BarangModel barang) {
    final rusakUnits = _getRusakUnits(barang);
    final dipesanUnits = _getDipesanUnits(barang);
    final dipinjamUnits = _getDipinjamUnits(barang);
    
    return (barang.totalQuantity - rusakUnits - dipesanUnits - dipinjamUnits)
        .clamp(0, barang.totalQuantity);
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

  void _showSnackBar({
    required String message,
    required IconData icon,
    required Color bgColor,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(String serialNumber) async {
    try {
      await _fs.deleteBarang(widget.labId, serialNumber);
      _showSnackBar(
        message: 'Barang SN $serialNumber berhasil dihapus',
        icon: Icons.check_circle_rounded,
        bgColor: primaryPurple,
      );
    } catch (e) {
      _showSnackBar(
        message: 'Gagal menghapus: ${e.toString().replaceAll('Exception: ', '')}',
        icon: Icons.error_outline_rounded,
        bgColor: Colors.red.shade700,
      );
    }
  }

  void _showDeleteConfirm(String serialNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Hapus',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        content: Text('Yakin ingin menghapus barang SN: $serialNumber?',
            style: const TextStyle(fontSize: 15.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w500))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(serialNumber);
            },
            child: const Text('Hapus',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BarangModel barang) {
    final serialCtrl = TextEditingController(text: barang.serialNumber);
    final keteranganCtrl = TextEditingController(text: barang.keterangan ?? '');
    String selectedItemId = barang.itemId;
    String selectedItemName = barang.itemName;
    String selectedCondition = barang.condition;
    final damagedCtrl = TextEditingController(text: barang.damagedQuantity.toString());
    final bool isSingleItem = barang.totalQuantity == 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: const Text('Edit Barang',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: serialCtrl,
                      enabled: false,
                      decoration: _inputDecoration('Serial Number').copyWith(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('labs')
                          .doc(widget.labId)
                          .collection('categories')
                          .doc(widget.categoryId)
                          .collection('item_types')
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, itemSnap) {
                        if (!itemSnap.hasData) {
                          return const CircularProgressIndicator();
                        }
                        final items = itemSnap.data!.docs;
                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedItemId.isNotEmpty ? selectedItemId : null,
                          decoration: _inputDecoration('Nama Barang'),
                          itemHeight: null,
                          items: items.map((doc) {
                            final name = (doc.data() as Map<String, dynamic>)['name'] ?? '';
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final selectedDoc = items.firstWhere((d) => d.id == value);
                            setDialogState(() {
                              selectedItemId = value;
                              selectedItemName = (selectedDoc.data() as Map<String, dynamic>)['name'] ?? '';
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedCondition,
                      decoration: _inputDecoration('Kondisi'),
                      items: const [
                        DropdownMenuItem(value: 'BAIK', child: Text('Baik')),
                        DropdownMenuItem(value: 'RUSAK', child: Text('Rusak')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCondition = value;
                            if (value == 'BAIK' && !isSingleItem) {
                              damagedCtrl.text = '0';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!isSingleItem && selectedCondition == 'RUSAK')
                      TextField(
                        controller: damagedCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Jumlah Unit Rusak (0-${barang.totalQuantity})'),
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: keteranganCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration('Keterangan (Opsional)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    int finalDamaged = 0;
                    if (isSingleItem) {
                      finalDamaged = (selectedCondition == 'RUSAK') ? 1 : 0;
                    } else if (selectedCondition == 'RUSAK') {
                      finalDamaged = int.tryParse(damagedCtrl.text.trim()) ?? 0;
                      finalDamaged = finalDamaged.clamp(0, barang.totalQuantity);
                    }

                    final int oldDamaged = barang.damagedQuantity;
                    final int oldGood = barang.totalQuantity - oldDamaged;
                    final int oldBorrowed = (oldGood - barang.availableQuantity).clamp(0, oldGood);
                    final int oldAvailable = barang.availableQuantity;

                    final int newDamaged = finalDamaged;
                    final int maxCanDamage = oldAvailable;
                    final int actualNewDamaged = newDamaged.clamp(0, oldDamaged + maxCanDamage);

                    final int newGood = barang.totalQuantity - actualNewDamaged;
                    final int newBorrowed = oldBorrowed.clamp(0, newGood);
                    final int newAvailable = (newGood - newBorrowed).clamp(0, newGood);

                    final String newCondition = (actualNewDamaged == barang.totalQuantity) ? 'RUSAK' : 'BAIK';
                    final String newKeterangan = keteranganCtrl.text.trim();

                    final bool noChange = selectedItemId == barang.itemId &&
                        actualNewDamaged == oldDamaged &&
                        newAvailable == oldAvailable &&
                        newKeterangan == (barang.keterangan ?? '');

                    if (noChange) {
                      Navigator.pop(context);
                      _showSnackBar(
                        message: 'Tidak ada perubahan',
                        icon: Icons.info_outline_rounded,
                        bgColor: Colors.blueGrey.shade700,
                      );
                      return;
                    }

                    if (newDamaged > oldDamaged + oldAvailable) {
                      _showSnackBar(
                        message: 'Hanya $oldAvailable unit yang tersedia untuk dirusak. Jumlah rusak disesuaikan.',
                        icon: Icons.warning_amber_rounded,
                        bgColor: Colors.orange.shade700,
                      );
                    }

                    try {
                      final ref = FirebaseFirestore.instance
                          .collection('labs')
                          .doc(widget.labId)
                          .collection('inventory')
                          .doc(_sanitizeSerialForDocId(barang.serialNumber));

                      await ref.update({
                        'itemId': selectedItemId,
                        'itemName': selectedItemName,
                        'condition': newCondition,
                        'availableQuantity': newAvailable,
                        'damagedQuantity': actualNewDamaged,
                        'keterangan': newKeterangan.isNotEmpty ? newKeterangan : null,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      Navigator.pop(context);
                      _showSnackBar(
                        message: 'Barang berhasil diperbarui',
                        icon: Icons.check_circle_rounded,
                        bgColor: primaryPurple,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      _showSnackBar(
                        message: 'Gagal update: ${e.toString().replaceAll('Exception: ', '')}',
                        icon: Icons.error_outline_rounded,
                        bgColor: Colors.red.shade700,
                      );
                    }
                  },
                  child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<BarangModel> _filterByStatus(List<BarangModel> docs) {
    if (_filterStatus == 'Semua') return docs;

    final result = <BarangModel>[];
    for (final barang in docs) {
      if (_matchesStatusFilter(barang)) {
        result.add(barang);
      }
    }
    return result;
  }

  bool _matchesStatusFilter(BarangModel barang) {
    if (_filterStatus == 'Semua') return true;

    final baikUnits = _getBaikUnits(barang);
    final dipesanUnits = _getDipesanUnits(barang);
    final dipinjamUnits = _getDipinjamUnits(barang);
    final rusakUnits = _getRusakUnits(barang);

    return switch (_filterStatus) {
      'Baik' => baikUnits > 0,
      'Dipesan' => dipesanUnits > 0,
      'Dipinjam' => dipinjamUnits > 0,
      'Rusak' => rusakUnits > 0,
      _ => true,
    };
  }

  List<BarangModel> _applyFilters(List<BarangModel> docs) {
    List<BarangModel> result = docs;

    // 1. Lakukan pencarian berdasarkan serialNumber menggunakan startsWith()
    if (_keyword.isNotEmpty) {
      final lowerKeyword = _keyword.toLowerCase();
      result = result.where((e) => 
        e.serialNumber.toLowerCase().startsWith(lowerKeyword)
      ).toList();
    }

    // 2. Kemudian menerapkan filter status
    return _filterByStatus(result);
  }

  Widget _summaryCard(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value.toString(),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 3),
            AutoSizeText(label,
                style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                minFontSize: 9),
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
                AutoSizeText('Detail Barang',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                    maxLines: 1, minFontSize: 17),
                AutoSizeText(catName,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.1),
                    maxLines: 1, minFontSize: 11),
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
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan saat memuat data'));
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<BarangModel> allItems = snapshot.data?.docs
                  .map((doc) => BarangModel.fromDocument(doc as DocumentSnapshot<Map<String, dynamic>>))
                  .toList() ??
              [];

          final filteredItems = _applyFilters(allItems);

          int countBaik = 0, countDipesan = 0, countDipinjam = 0, countRusak = 0;

          for (final barang in allItems) {
            countBaik += _getBaikUnits(barang);
            countDipesan += _getDipesanUnits(barang);
            countDipinjam += _getDipinjamUnits(barang);
            countRusak += _getRusakUnits(barang);
          }

          final displayTotal = countBaik + countDipesan + countDipinjam + countRusak;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: softPurple,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryPurple.withValues(alpha: 0.5), width: 1.2),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: primaryPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(displayTotal.toString(),
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryPurple)),
                          const SizedBox(height: 4),
                          const Text('Total Barang', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _summaryCard('Baik', countBaik, const Color(0xFF1976D2)),
                        const SizedBox(width: 6),
                        _summaryCard('Dipesan', countDipesan, Colors.purple.shade700),
                        const SizedBox(width: 6),
                        _summaryCard('Dipinjam', countDipinjam, Colors.orange.shade800),
                        const SizedBox(width: 6),
                        _summaryCard('Rusak', countRusak, Colors.red.shade700),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _statusDropdown(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: _inputDecoration('Cari Serial Number').copyWith(
                              hintText: 'Cari serial number...',
                              prefixIcon: const Icon(Icons.search_rounded, color: primaryPurple),
                            ),
                            onChanged: (value) => setState(() => _keyword = value.trim()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BarcodeScannerPage(
                                  onDetect: (sn) {
                                    _searchCtrl.text = sn;
                                    setState(() => _keyword = sn.trim());
                                  },
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: primaryPurple,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: allItems.isEmpty
                    ? const Center(child: Text('Tidak ada barang', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)))
                    : filteredItems.isEmpty
                        ? const Center(child: Text('Data tidak ditemukan', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) => _itemCard(filteredItems[index]),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemCard(BarangModel barang) {
    final dipesanUnits = _getDipesanUnits(barang);
    final dipinjamUnits = _getDipinjamUnits(barang);
    final rusakUnits = _getRusakUnits(barang);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
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
                    .doc(widget.labId)
                    .collection('categories')
                    .doc(barang.categoryId)
                    .collection('item_types')
                    .doc(barang.itemId)
                    .snapshots(),
                builder: (context, snapshot) {
                  String? imageUrl;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    imageUrl = data['imageUrl'] as String?;
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
                    Text('SN: ${barang.serialNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        children: [
                          TextSpan(text: barang.itemName),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: '(${barang.satuan})',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _statusBadges(barang, dipinjamUnits, rusakUnits, dipesanUnits),
                  ],
                ),
              ),
              if (!widget.isMahasiswa)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'edit') _showEditDialog(barang);
                    if (value == 'delete') _showDeleteConfirm(barang.serialNumber);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
                  ],
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
  }

  Widget _statusBadges(BarangModel barang, int dipinjamUnits, int rusakUnits, int dipesanUnits) {
    final total = barang.totalQuantity;

    if (rusakUnits == total) {
      return _badge('Rusak', Colors.red.shade700);
    }

    final badges = <Widget>[];

    if (rusakUnits > 0 && rusakUnits < total) {
      badges.add(_badge('Sebagian Rusak', Colors.red.shade700));
    }

    if (dipesanUnits == total && rusakUnits == 0 && dipinjamUnits == 0) {
      badges.add(_badge('Dipesan', Colors.purple.shade700));
    } else if (dipesanUnits > 0) {
      badges.add(_badge('Sebagian Dipesan', Colors.purple.shade700));
    }

    if (dipinjamUnits == total && rusakUnits == 0 && dipesanUnits == 0) {
      badges.add(_badge('Dipinjam', Colors.orange.shade800));
    } else if (dipinjamUnits > 0) {
      badges.add(_badge('Sebagian Dipinjam', Colors.orange.shade800));
    }

    if (badges.isEmpty) {
      badges.add(_badge('Baik', const Color(0xFF1976D2)));
    }

    if (badges.length == 1) return badges.first;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.start,
      children: badges,
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: AutoSizeText(
        text,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
        maxLines: 1,
        minFontSize: 10,
      ),
    );
  }

  Widget _statusDropdown() {
    const list = ['Semua', 'Baik', 'Dipesan', 'Dipinjam', 'Rusak'];
    return DropdownButtonFormField<String>(
      initialValue: _filterStatus,
      decoration: _inputDecoration('Status'),
      items: list.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (v) => setState(() => _filterStatus = v!),
      iconEnabledColor: primaryPurple,
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPurple)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPurple)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryPurple, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}