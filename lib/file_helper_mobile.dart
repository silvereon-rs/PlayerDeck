import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

void exportJsonFile(String jsonStr, String filename) async {
  try {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonStr);
  } catch (_) {}
}

void importJsonFile(void Function(String jsonStr) onLoaded, void Function(String error) onError) {
  onError('Import file selection requires a file picker');
}

void pickImageFile(void Function(Uint8List bytes) onLoaded, void Function(String error) onError) {
  onError('Image selection requires an image picker');
}
