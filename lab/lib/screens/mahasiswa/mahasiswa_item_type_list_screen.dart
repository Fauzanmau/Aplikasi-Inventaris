import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../models/barang_model.dart';
import '../../services/firestore_service.dart';
import 'mahasiswa_category_detail_screen.dart';

class MahasiswaItemTypeListScreen extends StatefulWidget {
  final String labId;
  final String categoryId;
  final String categoryName;

  const MahasiswaItemTypeListScreen({
    super.key,
    required this.labId,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<MahasiswaItemTypeListScreen> createState() =>
      _MahasiswaItemTypeListScreenState();
}

class _MahasiswaItemTypeListScreenState
    extends State<MahasiswaItemTypeListScreen> {
  static const primaryPurple = Color(0xFFA020F0);
  final FirestoreService _fs = FirestoreService();

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
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catId = widget.categoryId;

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
              .doc(catId)
              .snapshots(),
          builder: (context, snapshot) {
            String categoryName = widget.categoryName;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              categoryName = data['name'] ?? widget.categoryName;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AutoSizeText(
                  categoryName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  minFontSize: 17,
                ),
                AutoSizeText(
                  "Laboratorium ${widget.labId}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
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
            .collection('categories')
            .doc(catId)
            .collection('item_types')
            .orderBy('name')
            .snapshots(),
        builder: (context, itemTypeSnap) {

          if (!itemTypeSnap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryPurple),
            );
          }

          if (itemTypeSnap.data!.docs.isEmpty) {
            return const Center(
              child: Text('Belum ada nama barang di kategori ini',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final itemTypeDocs = itemTypeSnap.data!.docs;

          return StreamBuilder<List<BarangModel>>(
            stream: _fs.getBarangByLab(widget.labId),
            builder: (context, inventorySnap) {

              if (!inventorySnap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryPurple),
                );
              }

              final allItems = inventorySnap.data ?? [];

              final itemsInCategory = allItems
                  .where((item) => item.categoryId == catId)
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: itemTypeDocs.length,
                itemBuilder: (context, index) {

                  final doc = itemTypeDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final itemName = data['name'] ?? '';
                  final itemId = doc.id;
                  final imageUrl = data['imageUrl'];
                  final satuan = data['satuan'] ?? 'Unit'; // ✅ AMBIL SATUAN DARI FIRESTORE

                  itemsInCategory
                      .where((item) =>
                          item.itemId == itemId &&
                          item.condition == 'BAIK' &&
                          item.availableQuantity > 0)
                      .fold<int>(
                        0,
                        (total, item) =>
                            total + item.availableQuantity,
                      );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ✅ TANPA STREAM (lebih ringan)
                          GestureDetector(
                            onTap: () {
                              if (imageUrl != null &&
                                  imageUrl.toString().isNotEmpty) {
                                _viewFullImage(imageUrl);
                              }
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: primaryPurple.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                                image: imageUrl != null &&
                                        imageUrl.toString().isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: imageUrl == null
                                  ? const Center(
                                      child: Icon(
                                        Icons.image_not_supported_rounded,
                                        color: Colors.grey,
                                        size: 32,
                                      ),
                                    )
                                  : null,
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                AutoSizeText(
                                  itemName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 3,
                                  minFontSize: 13,
                                ),
                                const SizedBox(height: 6),
                                // ✅ PERBAIKAN: Tampilkan satuan dalam format Satuan: (Unit) italic abu-abu
                                RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Satuan: '),
                                      TextSpan(
                                        text: '($satuan)',
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

                          IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: primaryPurple,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MahasiswaCategoryDetailScreen(
                                    labId: widget.labId,
                                    categoryId: catId,
                                    categoryName: widget.categoryName,
                                    itemId: itemId,
                                    itemName: itemName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}