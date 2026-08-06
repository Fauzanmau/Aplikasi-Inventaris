import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lab/core/constants.dart';
import 'riwayat_model.dart';

class BarangModel {
  final String id;
  final String serialNumber;
  final String labId;
  final String labName;

  final String categoryId;
  final String categoryName;

  final String itemId;
  final String itemName;

  final String condition;
  final int totalQuantity;
  final int availableQuantity;
  final int damagedQuantity;

  final String satuan; // ✅ FIELD BARU: Satuan barang (Unit, Pak, Rim, dll)

  final String? keterangan; // ✅ FIELD: Keterangan kondisi/komponen

  // ✅ FIELD BARU: Untuk sinkronisasi gambar dari item_types ke inventory
  final String? imageUrl;
  final String? imagePublicId;

  final Timestamp tanggalInput;
  final Timestamp? updatedAt;
  final List<RiwayatPeminjaman> riwayat;

  BarangModel({
    required this.id,
    required this.serialNumber,
    required this.labId,
    required this.labName,
    required this.categoryId,
    required this.categoryName,
    required this.itemId,
    required this.itemName,
    required this.condition,
    required this.totalQuantity,
    required this.availableQuantity,
    required this.damagedQuantity,
    this.satuan = 'Unit', // ✅ DEFAULT VALUE: 'Unit' jika tidak diset
    this.keterangan,
    this.imageUrl,        // ✅ FIELD BARU
    this.imagePublicId,   // ✅ FIELD BARU
    required this.tanggalInput,
    required this.riwayat,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'serialNumber': serialNumber,
      'labId': labId,
      'labName': labName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'itemId': itemId,
      'itemName': itemName,
      'condition': condition,
      'totalQuantity': totalQuantity,
      'availableQuantity': availableQuantity,
      'damagedQuantity': damagedQuantity,
      'satuan': satuan, // ✅ SIMPAN KE FIRESTORE
      'keterangan': keterangan,
      'imageUrl': imageUrl,         // ✅ SIMPAN KE FIRESTORE
      'imagePublicId': imagePublicId, // ✅ SIMPAN KE FIRESTORE
      'tanggalInput': tanggalInput,
      'updatedAt': updatedAt,
      'riwayat': riwayat.map((e) => e.toMap()).toList(),
    };
  }

  factory BarangModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return BarangModel(
      id: doc.id,
      serialNumber: data['serialNumber'] ?? '',
      labId: data['labId'] ?? '',
      labName: data['labName'] ?? '',
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      condition: data['condition'] ?? AppConstants.kondisiBaik,
      totalQuantity: data['totalQuantity'] ?? 1,
      availableQuantity: data['availableQuantity'] ?? 1,
      damagedQuantity: data['damagedQuantity'] ?? 0,
      // ✅ BACA DARI FIRESTORE: Jika null (data lama), pakai default 'Unit'
      satuan: data['satuan'] ?? 'Unit',
      keterangan: data['keterangan'],
      // ✅ BACA IMAGE DARI FIRESTORE
      imageUrl: data['imageUrl'] as String?,
      imagePublicId: data['imagePublicId'] as String?,
      tanggalInput:
          data['tanggalInput'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp?,
      riwayat: (data['riwayat'] as List<dynamic>? ?? [])
          .map((e) => RiwayatPeminjaman.fromMap(
              Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  BarangModel copyWith({
    String? serialNumber,
    String? labId,
    String? labName,
    String? categoryId,
    String? categoryName,
    String? itemId,
    String? itemName,
    String? condition,
    int? totalQuantity,
    int? availableQuantity,
    int? damagedQuantity,
    String? satuan, // ✅ FIELD BARU
    String? keterangan,
    String? imageUrl,         // ✅ FIELD BARU
    String? imagePublicId,    // ✅ FIELD BARU
    Timestamp? tanggalInput,
    Timestamp? updatedAt,
    List<RiwayatPeminjaman>? riwayat,
  }) {
    return BarangModel(
      id: id,
      serialNumber: serialNumber ?? this.serialNumber,
      labId: labId ?? this.labId,
      labName: labName ?? this.labName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      condition: condition ?? this.condition,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      damagedQuantity: damagedQuantity ?? this.damagedQuantity,
      satuan: satuan ?? this.satuan, // ✅ UPDATE SATUAN
      keterangan: keterangan ?? this.keterangan,
      imageUrl: imageUrl ?? this.imageUrl,         // ✅ UPDATE IMAGE URL
      imagePublicId: imagePublicId ?? this.imagePublicId, // ✅ UPDATE IMAGE PUBLIC ID
      tanggalInput: tanggalInput ?? this.tanggalInput,
      updatedAt: updatedAt ?? this.updatedAt,
      riwayat: riwayat ?? this.riwayat,
    );
  }

  // =============================================
  // HELPER GETTERS
  // =============================================
  bool get isRusak => condition == 'RUSAK';
  bool get sedangDipinjam => totalQuantity > availableQuantity;
  bool get isBulk => totalQuantity > 1;
  bool get hasKeterangan => keterangan != null && keterangan!.isNotEmpty;

  int get totalRusak => isRusak ? totalQuantity : damagedQuantity;
  
  // ✅ HELPER BARU: Format display dengan satuan
  String get quantityDisplay => '$totalQuantity $satuan';
  String get availableDisplay => '$availableQuantity $satuan';
}