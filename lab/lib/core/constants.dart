class AppConstants {
  AppConstants._(); // mencegah instance

  // ========================
  // ROLE
  // ========================
  static const String roleAdmin = 'admin';
  static const String roleMahasiswa = 'mahasiswa';

  static const List<String> roles = [
    roleAdmin,
    roleMahasiswa,
  ];

  // ========================
  // KONDISI BARANG
  // ========================
  static const String kondisiBaik = 'BAIK';
  static const String kondisiRusak = 'RUSAK';

  static const List<String> kondisiList = [
    kondisiBaik,
    kondisiRusak,
  ];
}
