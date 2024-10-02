// pdf_download_web.dart

import 'dart:typed_data';
import 'dart:html' as html;

void downloadPdfWeb(Uint8List pdfBytes) {
  final blob = html.Blob([pdfBytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', 'Desk_Report.pdf')
    ..click();
  html.Url.revokeObjectUrl(url);
}
