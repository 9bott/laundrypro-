// Generates a tight-crop PNG for Android adaptive foreground only (run after editing source logo).
import 'dart:io';

import 'package:image/image.dart';

void main() {
  final root = Directory.current;
  final srcPath = File('${root.path}/assets/images/app_logo.png');
  final outPath = File('${root.path}/assets/images/app_logo_adaptive_foreground.png');

  final src = decodeImage(srcPath.readAsBytesSync());
  if (src == null) {
    stderr.writeln('Missing or invalid ${srcPath.path}');
    exit(1);
  }

  final trimmed = trim(src, mode: TrimMode.transparent);
  final side = trimmed.width > trimmed.height ? trimmed.width : trimmed.height;
  final pad = (side * 0.06).round().clamp(2, 64);
  final out = Image(
    width: trimmed.width + 2 * pad,
    height: trimmed.height + 2 * pad,
    numChannels: 4,
  );
  fill(out, color: ColorRgba8(0, 0, 0, 0));
  compositeImage(out, trimmed, dstX: pad, dstY: pad);

  outPath.writeAsBytesSync(encodePng(out));
  stdout.writeln('Wrote ${outPath.path} (${out.width}x${out.height})');
}
