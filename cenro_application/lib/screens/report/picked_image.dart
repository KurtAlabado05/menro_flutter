import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class PickedImage {
  final XFile file;
  final Uint8List? bytes;

  PickedImage({required this.file, this.bytes});

  bool get hasBytes => bytes != null;
}
