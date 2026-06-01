import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'database_helper.dart';
import 'bill_service.dart';
import 'storage_channel.dart';

class BackupResult {
  final String path;
  final String subFolder;
  final String fileName;
  BackupResult({required this.path, required this.subFolder, required this.fileName});
}

class BackupService {
  final _db = DatabaseHelper.instance;
  final _billService = BillService();

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}_${d.hour.toString().padLeft(2, '0')}-${d.minute.toString().padLeft(2, '0')}';
  }

  Future<BackupResult> createBackup({String? password}) async {
    final dbPath = await _db.getDatabasePath();
    final backupFile = await _copyDatabase(dbPath);
    final bytes = await backupFile.readAsBytes();

    Uint8List data = bytes;
    if (password != null && password.isNotEmpty) {
      data = _xorEncrypt(bytes, password);
    }

    final date = _formatDateTime(DateTime.now());
    final fileName = '记一笔_备份_$date.db';
    final subFolder = '备份';

    await StorageChannel.saveToDownloads(subFolder, fileName, data);

    // Build the path for display / open
    final filePath = '/storage/emulated/0/Download/记一笔/$subFolder/$fileName';
    return BackupResult(path: filePath, subFolder: subFolder, fileName: fileName);
  }

  Future<void> restoreBackup(String filePath, {String? password}) async {
    final file = File(filePath);
    Uint8List data = await file.readAsBytes();

    if (password != null && password.isNotEmpty) {
      data = _xorEncrypt(data, password);
    }

    await _db.closeDatabase();

    final dbPath = await _db.getDatabasePath();
    await File(dbPath).writeAsBytes(data);
  }

  Future<File> _copyDatabase(String sourcePath) async {
    final tempDir = await getTemporaryDirectory();
    final destPath = p.join(tempDir.path, 'db_backup_temp.db');
    await File(sourcePath).copy(destPath);
    return File(destPath);
  }

  Uint8List _xorEncrypt(Uint8List data, String key) {
    final keyBytes = utf8.encode(key);
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      result[i] = data[i] ^ keyBytes[i % keyBytes.length];
    }
    return result;
  }

  Future<BackupResult> exportToCsv(int ledgerId, {String? startDate, String? endDate, String? customName}) async {
    final bills = await _billService.getBills(ledgerId, startDate: startDate, endDate: endDate);

    final rows = <List<String>>[
      ['日期', '类型', '分类', '金额', '备注'],
    ];
    for (final bill in bills) {
      rows.add([
        bill.date,
        bill.type == 'expense' ? '支出' : '收入',
        bill.category,
        bill.amount.toStringAsFixed(2),
        bill.note,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final name = customName ?? '记一笔_账单导出_${_formatDate(DateTime.now())}';
    final fileName = '$name.csv';
    final subFolder = '导出';

    final bytes = Uint8List.fromList(utf8.encode(csvData));
    await StorageChannel.saveToDownloads(subFolder, fileName, bytes);

    final filePath = '/storage/emulated/0/Download/记一笔/$subFolder/$fileName';
    return BackupResult(path: filePath, subFolder: subFolder, fileName: fileName);
  }

  Future<BackupResult> exportToExcel(int ledgerId, {String? startDate, String? endDate, String? customName}) async {
    final bills = await _billService.getBills(ledgerId, startDate: startDate, endDate: endDate);

    final excel = Excel.createExcel();
    final sheet = excel['账单数据'];

    final thinBorder = Border(borderStyle: BorderStyle.Thin);

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('FF4472C4'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );

    final incomeStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF27AE60'),
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );

    final expenseStyle = CellStyle(
      fontColorHex: ExcelColor.fromHexString('FFE74C3C'),
      leftBorder: thinBorder,
      rightBorder: thinBorder,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
    );

    final headers = ['日期', '类型', '分类', '金额', '备注'];
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = headerStyle;
      cell.value = TextCellValue(headers[col]);
    }

    for (int i = 0; i < bills.length; i++) {
      final bill = bills[i];
      final isIncome = bill.type == 'income';
      final rowStyle = isIncome ? incomeStyle : expenseStyle;
      final row = i + 1;

      final values = [
        TextCellValue(bill.date),
        TextCellValue(isIncome ? '收入' : '支出'),
        TextCellValue(bill.category),
        DoubleCellValue(bill.amount),
        TextCellValue(bill.note),
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.cellStyle = rowStyle;
        cell.value = values[col];
      }
    }

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 8);
    sheet.setColumnWidth(2, 10);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 28);

    final bytes = excel.encode()!;
    final name = customName ?? '记一笔_账单导出_${_formatDate(DateTime.now())}';
    final fileName = '$name.xlsx';
    final subFolder = '导出';

    await StorageChannel.saveToDownloads(subFolder, fileName, bytes);

    final filePath = '/storage/emulated/0/Download/记一笔/$subFolder/$fileName';
    return BackupResult(path: filePath, subFolder: subFolder, fileName: fileName);
  }

  Future<void> cleanupOldBackups() async {
    // Cleanup is handled by the system; app-private backups can still be cleaned
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(docDir.path, 'backups'));
      if (!await backupDir.exists()) return;
      final threshold = DateTime.now().subtract(const Duration(days: 30));
      await for (final entity in backupDir.list()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith('记一笔_备份_') && (name.endsWith('.db') || name.endsWith('.fin'))) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(threshold)) {
              await entity.delete();
            }
          }
        }
      }
    } catch (_) {}
  }
}
