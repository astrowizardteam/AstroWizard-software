import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'storage.dart';
import 'xml_io.dart';

/// Writes [json] to a temporary .json file and opens the device share sheet
/// (WhatsApp, email, Drive, Bluetooth ...).
Future<void> shareJsonFile(String json, String baseName) =>
    _shareText(json, baseName, 'json', 'application/json');

/// Same as [shareJsonFile] but XML.
Future<void> shareXmlFile(String xml, String baseName) =>
    _shareText(xml, baseName, 'xml', 'application/xml');

Future<void> _shareText(String body, String baseName, String ext, String mime) async {
  final safe = baseName.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
  final f = File('${Directory.systemTemp.path}/${safe.isEmpty ? 'kundli' : safe}.$ext');
  await f.writeAsString(body, flush: true);
  await Share.shareXFiles([XFile(f.path, mimeType: mime)],
      subject: 'AstroWizard Kundali', text: 'AstroWizard Kundali chart file');
}

/// Import problem with a short look at the file, so the cause can be seen.
class ImportFailure implements Exception {
  final String message;
  final String preview;
  const ImportFailure(this.message, this.preview);
}

String _utf16(List<int> b, bool le) {
  final units = <int>[
    for (var i = 0; i + 1 < b.length; i += 2) le ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1],
  ];
  return String.fromCharCodes(units);
}

/// Text of a chart file: UTF-8 (with or without BOM) and UTF-16 (common for XML
/// saved by Windows software) are both understood.
String decodeChartBytes(List<int> b) {
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
    return utf8.decode(b.sublist(3), allowMalformed: true);
  }
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) return _utf16(b.sublist(2), true);
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) return _utf16(b.sublist(2), false);
  // No BOM: UTF-16 text has a zero byte beside every ASCII character.
  var zeroEven = 0, zeroOdd = 0;
  final n = b.length < 200 ? b.length : 200;
  for (var i = 0; i < n; i++) {
    if (b[i] == 0) {
      if (i.isEven) {
        zeroEven++;
      } else {
        zeroOdd++;
      }
    }
  }
  if (zeroOdd > n / 4) return _utf16(b, true);
  if (zeroEven > n / 4) return _utf16(b, false);
  return utf8.decode(b, allowMalformed: true);
}

/// Imports charts from the text of a .json or .xml file. Returns the count.
Future<int> importChartText(String text) async {
  final preview = text.trimLeft().replaceAll(RegExp(r'[\u0000-\u001F]'), ' ');
  final p = preview.length > 300 ? preview.substring(0, 300) : preview;
  final m = RegExp(r'[<{\[]').firstMatch(text);
  if (m == null) {
    throw ImportFailure('This is not a JSON or XML chart file.', p);
  }
  final body = text.substring(m.start);
  try {
    if (body.startsWith('<')) return await ChartStore.importCharts(chartsFromXml(body));
    return await ChartStore.importJson(body);
  } on FormatException catch (e) {
    throw ImportFailure(e.message, p);
  }
}

/// Lets the user pick a .json or .xml file (from Files, WhatsApp downloads, Drive ...)
/// and merges its charts. Returns the number imported, or null if cancelled.
/// Throws [ImportFailure] for files that cannot be read as charts.
Future<int?> pickAndImportCharts() async {
  final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  if (res == null || res.files.isEmpty) return null;
  final f = res.files.first;
  var bytes = f.bytes;
  if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
  if (bytes == null) throw const ImportFailure('Could not read the file.', '');
  return importChartText(decodeChartBytes(bytes));
}
