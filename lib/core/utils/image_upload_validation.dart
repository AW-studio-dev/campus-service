import 'dart:typed_data';

const maxImageUploadSizeBytes = 5 * 1024 * 1024;

String? detectImageMimeType(Uint8List bytes) {
  const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length >= pngSignature.length) {
    var isPng = true;
    for (var index = 0; index < pngSignature.length; index++) {
      if (bytes[index] != pngSignature[index]) {
        isPng = false;
        break;
      }
    }
    if (isPng) return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  return null;
}

bool isValidImageUpload(Uint8List bytes) {
  return bytes.isNotEmpty &&
      bytes.length <= maxImageUploadSizeBytes &&
      detectImageMimeType(bytes) != null;
}
