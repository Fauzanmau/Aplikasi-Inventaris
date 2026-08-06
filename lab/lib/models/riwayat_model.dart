import 'package:cloud_firestore/cloud_firestore.dart';

class RiwayatPeminjaman {
  final String uidPeminjam;
  final String peminjam;
  final String nim;
  final String kelas;
  final Timestamp tanggalPinjam;
  final Timestamp tanggalHarusKembali;
  final int quantity;

  RiwayatPeminjaman({
    required this.uidPeminjam,
    required this.peminjam,
    required this.nim,
    required this.kelas,
    required this.tanggalPinjam,
    required this.tanggalHarusKembali,
    this.quantity = 1,
  });

  //////////////////////////////////////////////////////////
  /// TO MAP
  //////////////////////////////////////////////////////////
  Map<String, dynamic> toMap() {
    return {
      'uidPeminjam': uidPeminjam,
      'peminjam': peminjam,
      'nim': nim,
      'kelas': kelas,
      'tanggalPinjam': tanggalPinjam,
      'tanggalHarusKembali': tanggalHarusKembali,
      'quantity': quantity,
    };
  }

  //////////////////////////////////////////////////////////
  /// FROM MAP (SAFE & CONSISTENT)
  //////////////////////////////////////////////////////////
  factory RiwayatPeminjaman.fromMap(Map<String, dynamic> map) {
    return RiwayatPeminjaman(
      uidPeminjam: map['uidPeminjam'] ?? '',
      peminjam: map['peminjam'] ?? '',
      nim: map['nim'] ?? '',
      kelas: map['kelas'] ?? '',
      tanggalPinjam: map['tanggalPinjam'] as Timestamp? ?? Timestamp.now(),
      tanggalHarusKembali:
          map['tanggalHarusKembali'] as Timestamp? ?? Timestamp.now(),
      quantity: map['quantity'] ?? 1,
    );
  }

  //////////////////////////////////////////////////////////
  /// COPY WITH
  //////////////////////////////////////////////////////////
  RiwayatPeminjaman copyWith({
    String? uidPeminjam,
    String? peminjam,
    String? nim,
    String? kelas,
    Timestamp? tanggalPinjam,
    Timestamp? tanggalHarusKembali,
    int? quantity,
  }) {
    return RiwayatPeminjaman(
      uidPeminjam: uidPeminjam ?? this.uidPeminjam,
      peminjam: peminjam ?? this.peminjam,
      nim: nim ?? this.nim,
      kelas: kelas ?? this.kelas,
      tanggalPinjam: tanggalPinjam ?? this.tanggalPinjam,
      tanggalHarusKembali: tanggalHarusKembali ?? this.tanggalHarusKembali,
      quantity: quantity ?? this.quantity,
    );
  }
}