import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../services/media/photo_metadata_service.dart';
import '../../services/media/report_photo_upload_queue.dart';

class PickedImage {
  final XFile file;
  final Uint8List? bytes;
  final PhotoMetadata? metadata;
  final ReportPhotoUpload? upload;

  PickedImage({required this.file, this.bytes, this.metadata, this.upload});

  bool get hasBytes => bytes != null;
}
