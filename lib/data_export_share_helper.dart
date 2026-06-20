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
}) =>
    shareExportJsonAsText(json: json, shareText: shareText);
