import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageChannel {
  static const _channel = MethodChannel('com.finance.app/storage');

  static Future<bool> saveToDownloads(String subFolder, String fileName, List<int> bytes) async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('saveToDownloads', {
          'subFolder': subFolder,
          'fileName': fileName,
          'bytes': bytes,
        });
        return result != null;
      }
      // Fallback for other platforms
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, subFolder, fileName));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> openFile(String path) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openFile', {'path': path});
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> openFolder(String path) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openFolder', {'path': path});
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> hasStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('hasStoragePermission');
        return result == true;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('requestStoragePermission');
      }
    } catch (e) {
      // Ignore
    }
  }
}
