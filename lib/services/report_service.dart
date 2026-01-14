import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/medicine.dart';
import '../models/log.dart';

class ReportService {
  Future<void> generateAndShareReport({
    required List<Medicine> medicines,
    required double overallAdherence,
    required int streak,
    required List<Log> recentLogs,
    required Map<int, String> medicineNames,
    String? patientName,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(now, patientName),
            pw.SizedBox(height: 20),
            _buildSummary(overallAdherence, streak, medicines.length),
            pw.SizedBox(height: 20),
            _buildMedicationList(medicines),
            pw.SizedBox(height: 20),
            _buildRecentActivity(recentLogs, medicineNames),
            pw.Divider(),
            _buildFooter(),
          ];
        },
      ),
    );

    // Save and Share
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/medtime_report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Here is my medication adherence report from MedTime.',
    );
  }

  pw.Widget _buildHeader(DateTime date, String? name) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'MedTime',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.Text(
              'Report Date: ${DateFormat('MMM d, yyyy').format(date)}',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          ],
        ),
        if (name != null && name.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Patient: $name',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ],
        pw.Divider(thickness: 1, color: PdfColors.grey300),
      ],
    );
  }

  pw.Widget _buildSummary(double adherence, int streak, int medCount) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Adherence', '${adherence.toStringAsFixed(1)}%'),
          _buildStatItem('Streak', '$streak Days'),
          _buildStatItem('Active Meds', '$medCount'),
        ],
      ),
    );
  }

  pw.Widget _buildStatItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _buildMedicationList(List<Medicine> medicines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Current Medications',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Medicine', 'Dosage', 'Frequency', 'Stock'],
          data: medicines.map((m) => [
            m.name,
            m.dosage,
            'Daily', // Simplifying since schedule is separate, ideal would be to lookup schedule
            m.currentStock.toString(),
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
          rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.center,
            3: pw.Alignment.centerRight,
          },
        ),
      ],
    );
  }

  pw.Widget _buildRecentActivity(List<Log> logs, Map<int, String> medNames) {
    // Sort logs by date descending and take last 20
    final sortedLogs = List<Log>.from(logs)
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    final displayLogs = sortedLogs.take(20).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Recent Activity (Last 20 Logs)',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Time', 'Medicine', 'Status'],
          data: displayLogs.map((l) {
            final medName = medNames[l.medicineId] ?? 'Med #${l.medicineId}';
            return [
              DateFormat('MMM d').format(l.scheduledTime),
              DateFormat('h:mm a').format(l.scheduledTime),
              medName,
              l.status.name.toUpperCase(),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        ),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 20),
        pw.Text(
          'Generated by MedTime App - Private & Offline',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
      ],
    );
  }
}
