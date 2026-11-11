import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void exportJsonFile(String jsonStr, String filename) {
  final bytes = utf8.encode(jsonStr);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void importJsonFile(void Function(String jsonStr) onLoaded, void Function(String error) onError) {
  final input = html.FileUploadInputElement()..accept = '.json';
  input.click();
  input.onChange.listen((event) {
    final file = input.files?.first;
    if (file == null) return;
    final reader = html.FileReader();
    reader.readAsText(file);
    reader.onLoadEnd.listen((_) {
      try {
        onLoaded(reader.result as String);
      } catch (e) {
        onError(e.toString());
      }
    });
  });
}

void pickImageFile(void Function(Uint8List bytes) onLoaded, void Function(String error) onError) {
  final input = html.FileUploadInputElement()..accept = 'image/png,image/jpeg,image/webp';
  input.click();
  input.onChange.listen((event) {
    final file = input.files?.first;
    if (file == null) return;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        if (result is Uint8List) {
          onLoaded(result);
        } else if (result is List<int>) {
          onLoaded(Uint8List.fromList(result));
        } else {
          onError('Could not read image');
        }
      } catch (e) {
        onError(e.toString());
      }
    });
  });
}
