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

/// Lets the user pick a .json or .xml file (from Files, WhatsApp downloads, Drive ...)
/// and merges its charts. Returns the number imported, or null if cancelled.
/// Throws [FormatException] for files that are not chart files.
Future<int?> pickAndImportCharts() async {
  final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  if (res == null || res.files.isEmpty) return null;
  final bytes = res.files.first.bytes;
  if (bytes == null) throw const FormatException('Could not read the file');
  final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
  if (text.trimLeft().startsWith('<')) {
    return ChartStore.importCharts(chartsFromXml(text));
  }
  return ChartStore.importJson(text);
}
