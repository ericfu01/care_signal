import 'dart:io';

import 'package:share_plus/share_plus.dart';

Future<void> shareExportJsonAsText({
  required String json,
  required String shareText,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      text: json,
      subject: 'Care Signal data export',
      title: shareText,
    ),
  );
}

Future<void> shareExportJson({
  required String json,
  required String fileName,
  required String shareText,
}) async {
  final file = File('${Directory.systemTemp.path}/$fileName');
  await file.writeAsString(json);

  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          mimeType: 'application/json',
          name: fileName,
        ),
      ],
      subject: 'Care Signal data export',
      text: shareText,
    ),
  );
}
