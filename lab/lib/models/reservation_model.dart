import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationModel {
  // =============================================
  // STATUS RESERVASI
  // =============================================
  static const String dipesan = 'dipesan';
  static const String dibatalkan = 'dibatalkan';

  final String id;

  // =============================================
  // DATA MAHASISWA
  // =============================================
  final String uid;
  final String nama;
  final String nim;
  final String kelas;
  final String prodi;

  // =============================================
  // DATA LAB
  // =============================================
  final String labId;
  final String labName;

  // =============================================
  // DATA BARANG
  // =============================================
  final String categoryId;
  final String categoryName;

  final String itemId;
  final String itemName;

  final String satuan;

  /// Jumlah barang yang dipesan
  final int quantity;

  /// dipesan | dibatalkan
  final String status;

  /// Catatan tambahan (opsional)
  final String? catatan;

  /// Waktu mahasiswa melakukan reservasi
  final Timestamp createdAt;

  /// Tanggal rencana pengembalian
  final Timestamp tanggalHarusKembali;

  ReservationModel({
    required this.id,
    required this.uid,
    required this.nama,
    required this.nim,
    required this.kelas,
    required this.prodi,
    required this.labId,
    required this.labName,
    required this.categoryId,
    required this.categoryName,
    required this.itemId,
    required this.itemName,
    required this.satuan,
    required this.quantity,
    this.status = dipesan,
    this.catatan,
    required this.createdAt,
    required this.tanggalHarusKembali,
  });

  // =============================================
  // TO MAP
  // =============================================
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nama': nama,
      'nim': nim,
      'kelas': kelas,
      'prodi': prodi,
      'labId': labId,
      'labName': labName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'itemId': itemId,
      'itemName': itemName,
      'satuan': satuan,
      'quantity': quantity,
      'status': status,
      'catatan': catatan,
      'createdAt': createdAt,
      'tanggalHarusKembali': tanggalHarusKembali,
    };
  }

  // =============================================
  // FROM DOCUMENT
  // =============================================
  factory ReservationModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return ReservationModel(
      id: doc.id,
      uid: data['uid'] ?? '',
      nama: data['nama'] ?? '',
      nim: data['nim'] ?? '',
      kelas: data['kelas'] ?? '',
      prodi: data['prodi'] ?? '',
      labId: data['labId'] ?? '',
      labName: data['labName'] ?? '',
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      satuan: data['satuan'] ?? 'Unit',
      quantity: data['quantity'] ?? 1,
      status: data['status'] ?? dipesan,
      catatan: data['catatan'],
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      tanggalHarusKembali:
          data['tanggalHarusKembali'] as Timestamp? ?? Timestamp.now(),
    );
  }

  // =============================================
  // COPY WITH
  // =============================================
  ReservationModel copyWith({
    String? id,
    String? uid,
    String? nama,
    String? nim,
    String? kelas,
    String? prodi,
    String? labId,
    String? labName,
    String? categoryId,
    String? categoryName,
    String? itemId,
    String? itemName,
    String? satuan,
    int? quantity,
    String? status,
    String? catatan,
    Timestamp? createdAt,
    Timestamp? tanggalHarusKembali,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      nama: nama ?? this.nama,
      nim: nim ?? this.nim,
      kelas: kelas ?? this.kelas,
      prodi: prodi ?? this.prodi,
      labId: labId ?? this.labId,
      labName: labName ?? this.labName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      satuan: satuan ?? this.satuan,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      createdAt: createdAt ?? this.createdAt,
      tanggalHarusKembali:
          tanggalHarusKembali ?? this.tanggalHarusKembali,
    );
  }

  // =============================================
  // HELPER GETTERS
  // =============================================
  bool get isDipesan => status == dipesan;

  bool get isDibatalkan => status == dibatalkan;
}