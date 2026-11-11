import 'dart:typed_data';

void exportJsonFile(String jsonStr, String filename) {
  throw UnsupportedError('Platform not supported');
}

void importJsonFile(void Function(String jsonStr) onLoaded, void Function(String error) onError) {
  throw UnsupportedError('Platform not supported');
}

void pickImageFile(void Function(Uint8List bytes) onLoaded, void Function(String error) onError) {
  throw UnsupportedError('Platform not supported');
}
