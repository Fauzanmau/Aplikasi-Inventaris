import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; 
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/barang_model.dart';
import '../services/firestore_service.dart';

// Theme colors - consistent with CategoryDetailScreen
const primaryPurple = Color(0xFFA020F0);
const softPurple = Color(0xFFF3E8FF);
const red700 = Color(0xFFD32F2F);   // PDF accent
const green700 = Color(0xFF388E3C); // Excel accent
const blue700 = Color(0xFF1976D2);  // Good/Baik accent
const orange800 = Color(0xFFE65100); // Borrowed/Dipinjam accent

// ✅ Model for Summary (aggregated per Item Name) - Internal naming: English | UI: Indonesian
class _ItemSummary {
  final String categoryName;
  final String itemName;
  final String unit; // UI: "Satuan"
  final int totalQuantity; // UI: "Total Qty"
  final int good; // UI: "Baik"
  final int borrowed; // UI: "Dipinjam"
  final int damaged; // UI: "Rusak"

  _ItemSummary({
    required this.categoryName,
    required this.itemName,
    required this.unit,
    required this.totalQuantity,
    required this.good,
    required this.borrowed,
    required this.damaged,
  });
}

// ✅ Model for Detail (per Serial Number) - Internal naming: English | UI: Indonesian
class _ItemDetail {
  final String serialNumber;
  final String categoryName;
  final String itemName;
  final String unit; // UI: "Satuan"
  final int quantity; // UI: "Qty" (per SN, not aggregated total)
  final int good; // UI: "Baik"
  final int borrowed; // UI: "Dipinjam"
  final int damaged; // UI: "Rusak"
  final String notes; // UI: "Keterangan"

  _ItemDetail({
    required this.serialNumber,
    required this.categoryName,
    required this.itemName,
    required this.unit,
    required this.quantity,
    required this.good,
    required this.borrowed,
    required this.damaged,
    required this.notes,
  });
}

class ExportService {
  // ====================== SHOW EXPORT BOTTOM SHEET ======================
  static void showExport({
    required BuildContext context,
    required String labId,
    required List<BarangModel> data,
    String? filterCategoryName,
    String? filterItemName,
    String? filterStatus,
  }) async {
    final fs = FirestoreService();
    final categorySnap = await fs.getCategoriesRef(labId).get();

    if (categorySnap.docs.isEmpty) {
      _showSnackBar(
        // ignore: use_build_context_synchronously
        context: context,
        message: 'Tidak ada kategori untuk diekspor',
        icon: Icons.error_outline_rounded,
        bgColor: Colors.grey.shade800,
      );
      return;
    }

    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    String fileBase = '${labId}_EXPORT_$dateStr';

    if (filterItemName != null && filterItemName != 'Semua' && filterItemName.isNotEmpty) {
      fileBase = '${labId}_${filterItemName}_$dateStr';
    } else if (filterCategoryName != null && filterCategoryName != 'Semua' && filterCategoryName.isNotEmpty) {
      fileBase = '${labId}_${filterCategoryName}_$dateStr';
    } else if (filterStatus != null && filterStatus != 'Semua' && filterStatus.isNotEmpty) {
      fileBase = '${labId}_${filterStatus}_$dateStr';
    }

    fileBase = fileBase.toUpperCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

    showModalBottomSheet(
      // ignore: use_build_context_synchronously
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                'Pilih Format Export',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
              title: const Text('Export PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportToPdf(context, fileBase, data, labId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green, size: 30),
              title: const Text('Export Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel(context, fileBase, data, labId);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ====================== SNACKBAR ======================
  static void _showSnackBar({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color bgColor,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    if (!context.mounted) return;
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

  // ====================== UNIT CALCULATION HELPERS ======================
  // ✅ Naming consistency with CategoryDetailScreen: English internal | Indonesian UI

  /// Returns the count of units in damaged condition.
  /// UI Label: "Rusak"
  static int _getDamagedUnits(BarangModel barang) => barang.damagedQuantity;

  /// Calculates the count of units currently borrowed.
  /// Formula: (total - damaged) - available, with clamp validation for safety.
  /// UI Label: "Dipinjam"
  static int _getBorrowedUnits(BarangModel barang) {
    final damagedUnits = _getDamagedUnits(barang);
    final nonDamagedUnits = barang.totalQuantity - damagedUnits;
    return (nonDamagedUnits - barang.availableQuantity).clamp(0, nonDamagedUnits);
  }

  /// Calculates the count of units in good condition (not damaged and not borrowed).
  /// Formula: total - damaged - borrowed, with clamp validation.
  /// UI Label: "Baik"
  static int _getGoodUnits(BarangModel barang) {
    final damagedUnits = _getDamagedUnits(barang);
    final borrowedUnits = _getBorrowedUnits(barang);
    return (barang.totalQuantity - damagedUnits - borrowedUnits)
        .clamp(0, barang.totalQuantity);
  }

  // ✅ FUNGSI: Build Summary aggregated per Item Name - Internal: English | UI: Indonesian
  static Future<List<_ItemSummary>> _buildItemSummary(
    String labId,
    List<BarangModel> inventoryData,
  ) async {
    final fs = FirestoreService();
    final summaryMap = <String, _ItemSummary>{};
    
    try {
      // Fetch all categories & item_types from master data
      final categoriesSnap = await fs.getCategoriesRef(labId).orderBy('name').get();
      
      for (var catDoc in categoriesSnap.docs) {
        final catData = catDoc.data() as Map<String, dynamic>;
        final categoryName = (catData['name'] ?? 'Tanpa Kategori').toString();
        final categoryId = catDoc.id;
        
        final itemsSnap = await fs.getItemTypesRef(labId, categoryId).orderBy('name').get();
        
        for (var itemDoc in itemsSnap.docs) {
          final itemData = itemDoc.data() as Map<String, dynamic>;
          final itemName = (itemData['name'] ?? 'Tanpa Nama Barang').toString();
          final unit = (itemData['satuan'] ?? 'Unit').toString();
          final itemId = itemDoc.id;
          
          // Find all inventory items matching this category + item type
          final matchingItems = inventoryData.where((b) => 
            b.categoryId == categoryId && b.itemId == itemId
          ).toList();
          
          // Aggregate statistics - Internal naming: English
          int totalQuantity = 0, totalGood = 0, totalBorrowed = 0, totalDamaged = 0;
          
          for (final barang in matchingItems) {
            final good = _getGoodUnits(barang);      // UI: "Baik"
            final borrowed = _getBorrowedUnits(barang); // UI: "Dipinjam"
            final damaged = _getDamagedUnits(barang);   // UI: "Rusak"
            
            totalQuantity += barang.totalQuantity;
            totalGood += good;
            totalBorrowed += borrowed;
            totalDamaged += damaged;
          }
          
          // If no items found, still display with zero values
          final key = '$categoryId|$itemId';
          summaryMap[key] = _ItemSummary(
            categoryName: categoryName,
            itemName: itemName,
            unit: unit,
            totalQuantity: totalQuantity,
            good: totalGood,      // UI: "Baik"
            borrowed: totalBorrowed, // UI: "Dipinjam"
            damaged: totalDamaged,   // UI: "Rusak"
          );
        }
      }
    } catch (_) {
      // Fallback: aggregate from inventory data only if master fetch fails
      for (final barang in inventoryData) {
        final key = '${barang.categoryId}|${barang.itemId}';
        if (!summaryMap.containsKey(key)) {
          final good = _getGoodUnits(barang);
          final borrowed = _getBorrowedUnits(barang);
          final damaged = _getDamagedUnits(barang);
          
          summaryMap[key] = _ItemSummary(
            categoryName: barang.categoryName.isNotEmpty ? barang.categoryName : 'Tanpa Kategori',
            itemName: barang.itemName.isNotEmpty ? barang.itemName : 'Tanpa Nama Barang',
            unit: barang.satuan.isNotEmpty ? barang.satuan : 'Unit',
            totalQuantity: barang.totalQuantity,
            good: good,
            borrowed: borrowed,
            damaged: damaged,
          );
        }
      }
    }
    
    final result = summaryMap.values.toList();
    result.sort((a, b) {
      final catComp = a.categoryName.compareTo(b.categoryName);
      if (catComp != 0) return catComp;
      return a.itemName.compareTo(b.itemName);
    });
    
    return result;
  }

  // ✅ FUNGSI: Build Detail per Serial Number - Internal: English | UI: Indonesian
  static Future<List<_ItemDetail>> _buildItemDetails(
    String labId,
    List<BarangModel> inventoryData,
  ) async {
    final fs = FirestoreService();
    final details = <_ItemDetail>[];
    
    try {
      // Fetch master data for consistent unit labels
      final categoriesSnap = await fs.getCategoriesRef(labId).get();
      final itemTypesMap = <String, String>{}; // itemId -> unit
      
      for (var catDoc in categoriesSnap.docs) {
        final categoryId = catDoc.id;
        final itemsSnap = await fs.getItemTypesRef(labId, categoryId).get();
        for (var itemDoc in itemsSnap.docs) {
          final data = itemDoc.data() as Map<String, dynamic>;
          final itemId = itemDoc.id;
          final unit = (data['satuan'] ?? 'Unit').toString();
          itemTypesMap['$categoryId|$itemId'] = unit;
        }
      }
      
      // Process each inventory item
      for (final barang in inventoryData) {
        final key = '${barang.categoryId}|${barang.itemId}';
        final unit = barang.satuan.isNotEmpty ? barang.satuan : (itemTypesMap[key] ?? 'Unit');
        final good = _getGoodUnits(barang);         // UI: "Baik"
        final borrowed = _getBorrowedUnits(barang); // UI: "Dipinjam"
        final damaged = _getDamagedUnits(barang);   // UI: "Rusak"
        final notes = barang.keterangan?.isNotEmpty ?? false ? barang.keterangan! : '-';
        
        details.add(_ItemDetail(
          serialNumber: barang.serialNumber,
          categoryName: barang.categoryName.isNotEmpty ? barang.categoryName : 'Tanpa Kategori',
          itemName: barang.itemName.isNotEmpty ? barang.itemName : 'Tanpa Nama Barang',
          unit: unit,
          quantity: barang.totalQuantity, // ✅ Quantity per SN, not aggregated total
          good: good,         // UI: "Baik"
          borrowed: borrowed, // UI: "Dipinjam"
          damaged: damaged,   // UI: "Rusak"
          notes: notes,       // UI: "Keterangan"
        ));
      }
    } catch (_) {
      // Fallback without master data
      for (final barang in inventoryData) {
        final good = _getGoodUnits(barang);
        final borrowed = _getBorrowedUnits(barang);
        final damaged = _getDamagedUnits(barang);
        final notes = barang.keterangan?.isNotEmpty ?? false ? barang.keterangan! : '-';
        
        details.add(_ItemDetail(
          serialNumber: barang.serialNumber,
          categoryName: barang.categoryName.isNotEmpty ? barang.categoryName : 'Tanpa Kategori',
          itemName: barang.itemName.isNotEmpty ? barang.itemName : 'Tanpa Nama Barang',
          unit: barang.satuan.isNotEmpty ? barang.satuan : 'Unit',
          quantity: barang.totalQuantity,
          good: good,
          borrowed: borrowed,
          damaged: damaged,
          notes: notes,
        ));
      }
    }
    
    // Sort: Category → Item Name → Serial Number
    details.sort((a, b) {
      final catComp = a.categoryName.compareTo(b.categoryName);
      if (catComp != 0) return catComp;
      final itemComp = a.itemName.compareTo(b.itemName);
      if (itemComp != 0) return itemComp;
      return a.serialNumber.compareTo(b.serialNumber);
    });
    
    return details;
  }

  // ====================== SAVE & SHARE HELPER ======================
  static Future<void> _saveAndShareFile({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      final xFile = XFile(file.path, mimeType: mimeType);

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xFile],
        text: 'Laporan Inventaris Laboratorium - $fileName',
        subject: 'Export Inventaris Lab',
      );
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(
          context: context,
          message: 'Gagal membagikan file: $e',
          icon: Icons.error_outline_rounded,
          bgColor: red700,
        );
      }
    }
  }

  // ====================== AUTO-FIT COLUMNS FOR EXCEL ======================
  static void _autoFitColumns(Sheet sheet, int maxColumns, int maxRows, {Map<int, double>? maxWidths}) {
    for (int col = 0; col < maxColumns; col++) {
      double maxWidth = maxWidths?[col] ?? 10.0;
      
      for (int row = 0; row < maxRows; row++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        if (cell.value != null) {
          final cellValue = cell.value.toString();
          final width = (cellValue.length * 1.1).toDouble();
          if (width > maxWidth) {
            maxWidth = width;
          }
        }
      }
      
      final limit = maxWidths?[col] ?? 50.0;
      if (maxWidth > limit) maxWidth = limit;
      sheet.setColumnWidth(col, maxWidth);
    }
  }

  // ====================== PDF EXPORT ======================
  static Future<void> _exportToPdf(
    BuildContext context,
    String fileBase,
    List<BarangModel> data,
    String labId,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final labDoc = await firestore.collection('labs').doc(labId).get();
    final labName = labDoc.data()?['name'] ?? 'Laboratorium';

    final pdf = pw.Document();
    final now = DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now());

    // ✅ Build Summary & Detail separately - Internal: English | UI: Indonesian
    final summaries = await _buildItemSummary(labId, data);
    final details = await _buildItemDetails(labId, data);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              children: [
                pw.Text('LAPORAN INVENTARIS LABORATORIUM',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('$labId - $labName | Tanggal: $now',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Divider(color: PdfColors.grey400, thickness: 1),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ✅ SECTION 1: Summary per Item (Aggregated) - UI labels in Indonesian
          pw.Text('1. Ringkasan per Barang',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (summaries.isEmpty)
            pw.Text('Tidak ada data barang yang terdaftar.',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
          else
            _buildSummaryTable(summaries),

          pw.SizedBox(height: 24),

          // ✅ SECTION 2: Detail per Serial Number - UI labels in Indonesian
          pw.Text('2. Detail per Serial Number',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (details.isEmpty)
            pw.Text('Tidak ada data serial number yang terdaftar.',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
          else
            ..._buildDetailPdf(details),
        ],
      ),
    );

    final bytes = await pdf.save();
    final uint8Bytes = Uint8List.fromList(bytes);
    final fileName = '$fileBase.pdf';

    final String? savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan PDF',
      fileName: fileName,
      bytes: uint8Bytes,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (savedPath != null && context.mounted) {
      _showSnackBar(
        context: context,
        message: 'PDF berhasil disimpan:\n$savedPath',
        icon: Icons.picture_as_pdf_rounded,
        bgColor: red700,
        duration: const Duration(seconds: 5),
      );
    }

    await _saveAndShareFile(
      // ignore: use_build_context_synchronously
      context: context,
      bytes: uint8Bytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }

  // ====================== BUILD SUMMARY TABLE (PDF) - UI: Indonesian ======================
  static pw.Widget _buildSummaryTable(List<_ItemSummary> summaries) {
    // Group by Category
    final grouped = <String, List<_ItemSummary>>{};
    for (final item in summaries) {
      grouped.putIfAbsent(item.categoryName, () => []).add(item);
    }
    final sortedCats = grouped.keys.toList()..sort();
    
    final widgets = <pw.Widget>[];
    
    for (final cat in sortedCats) {
      final catItems = grouped[cat]!;
      
      widgets.add(
        pw.Text('Kategori: $cat',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );
      widgets.add(pw.SizedBox(height: 4));
      
      widgets.add(
        pw.Table(
          border: pw.TableBorder.all(width: 1, color: PdfColors.black),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.0), // Nama Barang
            1: pw.FlexColumnWidth(0.7), // Satuan
            2: pw.FlexColumnWidth(0.8), // Total Qty
            3: pw.FlexColumnWidth(0.8), // Baik
            4: pw.FlexColumnWidth(0.9), // Dipinjam
            5: pw.FlexColumnWidth(0.8), // Rusak
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _pdfHeaderCell('Nama Barang'),
                _pdfHeaderCell('Satuan'),
                _pdfHeaderCell('Total Qty'),
                _pdfHeaderCell('Baik'),
                _pdfHeaderCell('Dipinjam'),
                _pdfHeaderCell('Rusak'),
              ],
            ),
            ...catItems.map((item) {
              return pw.TableRow(
                children: [
                  _pdfCellCenter(item.itemName),
                  _pdfCell(item.unit),
                  _pdfCell(item.totalQuantity.toString()),
                  _pdfCell(item.good.toString()),      // UI: "Baik"
                  _pdfCell(item.borrowed.toString()),  // UI: "Dipinjam"
                  _pdfCell(item.damaged.toString()),   // UI: "Rusak"
                ],
              );
            }),
          ],
        ),
      );
      widgets.add(pw.SizedBox(height: 12));
    }
    
    return pw.Column(children: widgets);
  }

  // ====================== BUILD DETAIL TABLE (PDF) - UI: Indonesian ======================
  static List<pw.Widget> _buildDetailPdf(List<_ItemDetail> details) {
    // Group by Category → Item Name
    final grouped = <String, Map<String, List<_ItemDetail>>>{};
    for (final item in details) {
      grouped.putIfAbsent(item.categoryName, () => {});
      grouped[item.categoryName]!.putIfAbsent(item.itemName, () => []).add(item);
    }
    
    final sortedCats = grouped.keys.toList()..sort();
    final widgets = <pw.Widget>[];
    
    for (final cat in sortedCats) {
      final itemsMap = grouped[cat]!;
      final sortedItems = itemsMap.keys.toList()..sort();
      
      for (final itemName in sortedItems) {
        final snList = itemsMap[itemName]!;
        
        widgets.add(
          pw.Text(itemName,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        );
        widgets.add(pw.SizedBox(height: 4));
        
        widgets.add(
          pw.Table(
            border: pw.TableBorder.all(width: 1, color: PdfColors.black),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2), // SN
              1: pw.FlexColumnWidth(1.3), // Kategori
              2: pw.FlexColumnWidth(1.5), // Nama Barang
              3: pw.FlexColumnWidth(0.7), // Satuan
              4: pw.FlexColumnWidth(0.7), // Qty (per SN)
              5: pw.FlexColumnWidth(0.7), // Baik
              6: pw.FlexColumnWidth(0.8), // Dipinjam
              7: pw.FlexColumnWidth(0.7), // Rusak
              8: pw.FlexColumnWidth(1.8), // Keterangan
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('SN'),
                  _pdfHeaderCell('Kategori'),
                  _pdfHeaderCell('Nama Barang'),
                  _pdfHeaderCell('Satuan'),
                  _pdfHeaderCell('Qty'),
                  _pdfHeaderCell('Baik'),
                  _pdfHeaderCell('Dipinjam'),
                  _pdfHeaderCell('Rusak'),
                  _pdfHeaderCell('Keterangan'),
                ],
              ),
              ...snList.map((item) {
                return pw.TableRow(
                  children: [
                    _pdfCell(item.serialNumber),
                    _pdfCellCenter(item.categoryName),
                    _pdfCellCenter(item.itemName),
                    _pdfCell(item.unit),
                    _pdfCell(item.quantity.toString()), // Qty per SN
                    _pdfCell(item.good.toString()),     // UI: "Baik"
                    _pdfCell(item.borrowed.toString()), // UI: "Dipinjam"
                    _pdfCell(item.damaged.toString()),  // UI: "Rusak"
                    _pdfCellCenter(item.notes),         // UI: "Keterangan"
                  ],
                );
              }),
            ],
          ),
        );
        widgets.add(pw.SizedBox(height: 12));
      }
    }
    return widgets;
  }

  // ====================== EXCEL EXPORT - UI: Indonesian ======================
  static Future<void> _exportToExcel(
    BuildContext context,
    String fileBase,
    List<BarangModel> data,
    String labId,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final labDoc = await firestore.collection('labs').doc(labId).get();
    final labName = labDoc.data()?['name'] ?? 'Laboratorium';

    final excel = Excel.createExcel();
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
    );

    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final title = '$labId - $labName';

    // ✅ Build Summary & Detail - Internal: English | UI: Indonesian
    final summaries = await _buildItemSummary(labId, data);
    final details = await _buildItemDetails(labId, data);

    // ==================== SHEET 1: Ringkasan per Item ====================
    final sheetSummary = excel['Ringkasan_Item'];
    sheetSummary.appendRow([TextCellValue('LAPORAN INVENTARIS - $title')]);
    sheetSummary.appendRow([TextCellValue('Tanggal: $now')]);
    sheetSummary.appendRow([]);
    
    // Header row - UI labels in Indonesian
    final headerSummary = [
      TextCellValue('Kategori'), TextCellValue('Nama Barang'), TextCellValue('Satuan'),
      TextCellValue('Total Qty'), TextCellValue('Baik'), TextCellValue('Dipinjam'),
      TextCellValue('Rusak')
    ];
    sheetSummary.appendRow(headerSummary);
    for (int col = 0; col < headerSummary.length; col++) {
      sheetSummary.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3)).cellStyle = headerStyle;
    }
    
    for (final item in summaries) {
      sheetSummary.appendRow([
        TextCellValue(item.categoryName),
        TextCellValue(item.itemName),
        TextCellValue(item.unit),
        TextCellValue(item.totalQuantity.toString()),
        TextCellValue(item.good.toString()),      // UI: "Baik"
        TextCellValue(item.borrowed.toString()),  // UI: "Dipinjam"
        TextCellValue(item.damaged.toString()),   // UI: "Rusak"
      ]);
    }
    _autoFitColumns(sheetSummary, 7, summaries.length + 4, maxWidths: {
      0: 20.0, 1: 30.0, 2: 10.0, 3: 10.0, 4: 8.0, 5: 10.0, 6: 8.0,
    });

    // ==================== SHEET 2: Detail per Serial Number ====================
    final sheetDetail = excel['Detail_SN'];
    sheetDetail.appendRow([TextCellValue('LAPORAN INVENTARIS - $title')]);
    sheetDetail.appendRow([TextCellValue('Tanggal: $now')]);
    sheetDetail.appendRow([]);
    
    // Header row - UI labels in Indonesian
    final headerDetail = [
      TextCellValue('SN'), TextCellValue('Kategori'), TextCellValue('Nama Barang'),
      TextCellValue('Satuan'), TextCellValue('Qty'), TextCellValue('Baik'),
      TextCellValue('Dipinjam'), TextCellValue('Rusak'), TextCellValue('Keterangan')
    ];
    sheetDetail.appendRow(headerDetail);
    for (int col = 0; col < headerDetail.length; col++) {
      sheetDetail.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3)).cellStyle = headerStyle;
    }
    
    for (final item in details) {
      sheetDetail.appendRow([
        TextCellValue(item.serialNumber),
        TextCellValue(item.categoryName),
        TextCellValue(item.itemName),
        TextCellValue(item.unit),
        TextCellValue(item.quantity.toString()), // Qty per SN
        TextCellValue(item.good.toString()),     // UI: "Baik"
        TextCellValue(item.borrowed.toString()), // UI: "Dipinjam"
        TextCellValue(item.damaged.toString()),  // UI: "Rusak"
        TextCellValue(item.notes),               // UI: "Keterangan"
      ]);
    }
    _autoFitColumns(sheetDetail, 9, details.isEmpty ? 5 : details.length + 4, maxWidths: {
      0: 18.0, 1: 20.0, 2: 25.0, 3: 10.0, 4: 8.0,
      5: 8.0, 6: 10.0, 7: 8.0, 8: 30.0,
    });

    final bytes = excel.encode();
    if (bytes == null) return;

    final uint8Bytes = Uint8List.fromList(bytes);
    final fileName = '$fileBase.xlsx';

    final String? savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Excel',
      fileName: fileName,
      bytes: uint8Bytes,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (savedPath != null && context.mounted) {
      _showSnackBar(
        context: context,
        message: 'Excel berhasil disimpan:\n$savedPath',
        icon: Icons.table_chart_rounded,
        bgColor: green700,
        duration: const Duration(seconds: 5),
      );
    }

    await _saveAndShareFile(
      // ignore: use_build_context_synchronously
      context: context,
      bytes: uint8Bytes,
      fileName: fileName,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  // Helper: Header cell styling for PDF tables
  static pw.Widget _pdfHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Helper: Regular cell with center alignment
  static pw.Widget _pdfCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8.5),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Helper: Cell with center alignment (for text fields)
  static pw.Widget _pdfCellCenter(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8.5),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}