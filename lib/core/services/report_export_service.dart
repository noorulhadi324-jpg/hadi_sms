import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ReportExportService {
  static Future<File> exportPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    String? schoolName,
  }) async {
    final document = pw.Document();
    final generated = DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (schoolName != null && schoolName.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
              child: pw.Text(schoolName),
            ),
          pw.Text('Generated: ${generated.toLocal()}'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(5),
            border: pw.TableBorder.all(color: PdfColors.grey400),
          ),
        ],
      ),
    );

    return _saveBytes(
      Uint8List.fromList(await document.save()),
      _safeFileName(title, 'pdf'),
    );
  }

  static Future<File> exportExcel({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    String? schoolName,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[title.length > 25 ? title.substring(0, 25) : title];

    final allRows = <List<String>>[
      if (schoolName != null && schoolName.trim().isNotEmpty) [schoolName],
      ['Generated', DateTime.now().toLocal().toString()],
      headers,
      ...rows,
    ];

    for (final row in allRows) {
      sheet.appendRow(row.map<TextCellValue>((value) => TextCellValue(value)).toList());
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception('Excel file could not be generated.');

    return _saveBytes(Uint8List.fromList(bytes), _safeFileName(title, 'xlsx'));
  }

  static Future<void> shareFile(File file, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
      ),
    );
  }

  static Future<File> _saveBytes(Uint8List bytes, String name) async {
    final directory = await getApplicationDocumentsDirectory();
    final reportsDirectory = Directory('${directory.path}/HADI_SMS_Reports');
    if (!await reportsDirectory.exists()) {
      await reportsDirectory.create(recursive: true);
    }
    final file = File('${reportsDirectory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String _safeFileName(String title, String extension) {
    final clean = title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    return '${clean.isEmpty ? 'HADI_Report' : clean}_$stamp.$extension';
  }
}
