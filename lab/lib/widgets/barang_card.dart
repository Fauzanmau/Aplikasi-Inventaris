import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';   // ← Tambahkan ini
import '../models/barang_model.dart';

class BarangCard extends StatelessWidget {
  final BarangModel barang;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const BarangCard({
    super.key,
    required this.barang,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  String get statusText {
    if (barang.condition == 'RUSAK') {
      return 'Rusak';
    }
    if (barang.availableQuantity == 0) {
      return 'Habis';
    }
    if (barang.availableQuantity < barang.totalQuantity) {
      return 'Dipinjam Sebagian';
    }
    return 'Tersedia';
  }

  Color get statusColor {
    if (barang.condition == 'RUSAK') {
      return Colors.red.shade700;
    }
    if (barang.availableQuantity == 0) {
      return Colors.grey.shade700;
    }
    if (barang.availableQuantity < barang.totalQuantity) {
      return Colors.orange.shade700;
    }
    return Colors.green.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KATEGORI
              AutoSizeText(
                barang.categoryName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                minFontSize: 14,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // NAMA BARANG
              if (barang.itemName.isNotEmpty)
                AutoSizeText(
                  barang.itemName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  minFontSize: 13,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 8),

              // SERIAL NUMBER
              AutoSizeText(
                'SN: ${barang.serialNumber}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                maxLines: 1,
                minFontSize: 12,
              ),

              const SizedBox(height: 12),

              // Status + Stok Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(38),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AutoSizeText(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      minFontSize: 11,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Stok jika bulk
                  if (barang.isBulk)
                    Expanded(
                      child: AutoSizeText(
                        '${barang.availableQuantity}/${barang.totalQuantity} tersedia',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        minFontSize: 11,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const Spacer(),

                  // Action Buttons
                  if (onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                      onPressed: onEdit,
                    ),

                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Hapus',
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}