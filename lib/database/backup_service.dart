import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'database_helper.dart';
import 'bill_service.dart';

class BackupService {
  final _db = DatabaseHelper.instance;
  final _billService = BillService();

  Future<String> createBackup({String? password}) async {
    final dbPath = await _db.getDatabasePath();
    final backupFile = await _copyDatabase(dbPath);
    final bytes = await backupFile.readAsBytes();

    // Simple XOR encryption if password provided
    Uint8List data = bytes;
    if (password != null && password.isNotEmpty) {
      data = _xorEncrypt(bytes, password);
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = p.join(dir.path, 'backup_$timestamp.fin');
    await File(backupPath).writeAsBytes(data);
    return backupPath;
  }

  Future<void> restoreBackup(String filePath, {String? password}) async {
    final file = File(filePath);
    Uint8List data = await file.readAsBytes();

    if (password != null && password.isNotEmpty) {
      data = _xorEncrypt(data, password);
    }

    // Write to database
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

  Future<String> exportToCsv(int ledgerId, {String? startDate, String? endDate}) async {
    final bills = await _billService.getBills(ledgerId, startDate: startDate, endDate: endDate);

    final rows = <List<String>>[
      ['ID', '类型', '金额', '分类', '备注', '日期'],
    ];
    for (final bill in bills) {
      rows.add([
        bill.id.toString(),
        bill.type == 'expense' ? '支出' : '收入',
        bill.amount.toStringAsFixed(2),
        bill.category,
        bill.note,
        bill.date,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = p.join(dir.path, 'export_$timestamp.csv');
    await File(filePath).writeAsString(csvData, encoding: utf8);
    return filePath;
  }

  Future<String> exportToExcel(int ledgerId, {String? startDate, String? endDate}) async {
    final bills = await _billService.getBills(ledgerId, startDate: startDate, endDate: endDate);

    // Build a simple Excel file using basic XML format
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0"?>');
    buffer.writeln('<?mso-application progid="Excel.Sheet"?>');
    buffer.writeln('<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"');
    buffer.writeln(' xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');
    buffer.writeln('<Worksheet ss:Name="账单数据">');
    buffer.writeln('<Table>');

    // Header
    buffer.writeln('<Row>');
    for (final h in ['ID', '类型', '金额', '分类', '备注', '日期']) {
      buffer.writeln('<Cell><Data ss:Type="String">$h</Data></Cell>');
    }
    buffer.writeln('</Row>');

    // Data
    for (final bill in bills) {
      buffer.writeln('<Row>');
      buffer.writeln('<Cell><Data ss:Type="Number">${bill.id}</Data></Cell>');
      buffer.writeln('<Cell><Data ss:Type="String">${bill.type == 'expense' ? '支出' : '收入'}</Data></Cell>');
      buffer.writeln('<Cell><Data ss:Type="Number">${bill.amount}</Data></Cell>');
      buffer.writeln('<Cell><Data ss:Type="String">${bill.category}</Data></Cell>');
      buffer.writeln('<Cell><Data ss:Type="String">${bill.note}</Data></Cell>');
      buffer.writeln('<Cell><Data ss:Type="String">${bill.date}</Data></Cell>');
      buffer.writeln('</Row>');
    }

    buffer.writeln('</Table>');
    buffer.writeln('</Worksheet>');
    buffer.writeln('</Workbook>');

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = p.join(dir.path, 'export_$timestamp.xls');
    await File(filePath).writeAsString(buffer.toString(), encoding: utf8);
    return filePath;
  }
}
