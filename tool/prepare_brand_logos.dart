import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  for (final name in ['ecomap_logo', 'baliwag_seal']) {
    final source = File('assets/images/ui/$name.png');
    final decoded = image.decodePng(source.readAsBytesSync());
    if (decoded == null) {
      throw FormatException('Cannot decode ${source.path}');
    }
    var left = decoded.width;
    var top = decoded.height;
    var right = -1;
    var bottom = -1;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        if (decoded.getPixel(x, y).a <= 16) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < left || bottom < top) {
      throw FormatException('No visible logo in ${source.path}');
    }
    final cropped = image.copyCrop(
      decoded,
      x: left,
      y: top,
      width: right - left + 1,
      height: bottom - top + 1,
    );
    final resized = image.copyResize(
      cropped,
      width: cropped.width >= cropped.height ? 448 : null,
      height: cropped.height >= cropped.width ? 448 : null,
      interpolation: image.Interpolation.cubic,
    );
    final canvas = image.Image(width: 512, height: 512, numChannels: 4);
    image.compositeImage(
      canvas,
      resized,
      dstX: (512 - resized.width) ~/ 2,
      dstY: (512 - resized.height) ~/ 2,
    );
    final target = File('assets/images/ui/${name}_display.png');
    target.writeAsBytesSync(image.encodePng(canvas));
    stdout.writeln('Prepared ${target.path}');
  }
}
