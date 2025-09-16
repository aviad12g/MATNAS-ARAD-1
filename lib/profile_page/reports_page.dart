import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../models/activity_definition.dart';
import '../models/attendance_session.dart';
import '../models/student.dart';
import '../state/app_state.dart';
import 'web_file_saver.dart' if (dart.library.io) 'web_file_saver_stub.dart';

class AttendanceReportPage extends StatefulWidget {
  const AttendanceReportPage({super.key});

  @override
  State<AttendanceReportPage> createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  String? _selectedActivityId;
  String? _selectedGroupId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy', 'he');
  final DateFormat _keyFormatter = DateFormat('yyyy-MM-dd');

  List<Student> _students = <Student>[];
  List<DateTime> _dates = <DateTime>[];
  Map<String, Map<DateTime, AttendanceStatus?>> _matrix =
      <String, Map<DateTime, AttendanceStatus?>>{};
  Map<String, double> _percentages = <String, double>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.read<AppState>();
    if (_selectedActivityId == null && appState.activities.isNotEmpty) {
      _selectedActivityId = appState.activities.first.id;
    }
    if (_selectedActivityId != null && _selectedGroupId == null) {
      final groups = appState.groupsForActivity(_selectedActivityId!);
      if (groups.isNotEmpty) {
        _selectedGroupId = groups.first.id;
      }
    }
  }

  Future<void> _selectDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('he'),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _generateReport() async {
    if (_selectedActivityId == null || _selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש לבחור פעילות וקבוצה לפני יצירת דו"ח.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _students = <Student>[];
      _dates = <DateTime>[];
      _matrix = <String, Map<DateTime, AttendanceStatus?>>{};
      _percentages = <String, double>{};
    });

    try {
      final appState = context.read<AppState>();
      final students = appState.studentsFor(
        _selectedActivityId!,
        _selectedGroupId!,
      );
      final dates = _buildDateRange(_startDate, _endDate);
      final sessions = appState.sessionsInRange(
        _selectedActivityId!,
        _selectedGroupId!,
        _startDate,
        _endDate,
      );
      final sessionsByDate = {
        for (final session in sessions)
          _keyFormatter.format(session.date): session,
      };

      final matrix = <String, Map<DateTime, AttendanceStatus?>>{};
      for (final student in students) {
        matrix[student.id] = {for (final date in dates) date: null};
      }

      for (final date in dates) {
        final session = sessionsByDate[_keyFormatter.format(date)];
        if (session == null) {
          continue;
        }
        for (final student in students) {
          matrix[student.id]![date] =
              session.statuses[student.id] ?? AttendanceStatus.absent;
        }
      }

      final percentages = <String, double>{};
      for (final student in students) {
        final entries = matrix[student.id]!;
        int totalSessions = 0;
        int presentCount = 0;
        entries.forEach((date, status) {
          if (status != null) {
            totalSessions++;
            if (status == AttendanceStatus.present) {
              presentCount++;
            }
          }
        });
        percentages[student.id] =
            totalSessions == 0 ? 0 : (presentCount / totalSessions) * 100;
      }

      setState(() {
        _students = students;
        _dates = dates;
        _matrix = matrix;
        _percentages = percentages;
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('אירעה שגיאה בעת יצירת הדו"ח: $error')),
      );
    }
  }

  List<DateTime> _buildDateRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(endDate)) {
      days.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activities = appState.activities;
    final groups =
        _selectedActivityId != null
            ? appState.groupsForActivity(_selectedActivityId!)
            : <GroupDefinition>[];

    return Scaffold(
      appBar: AppBar(title: const Text('דו"חות נוכחות')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            value: _selectedActivityId,
                            decoration: const InputDecoration(
                              labelText: 'פעילות',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                activities
                                    .map(
                                      (activity) => DropdownMenuItem(
                                        value: activity.id,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(activity.name),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedActivityId = value;
                                _selectedGroupId = null;
                              });
                            },
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<String>(
                            value: _selectedGroupId,
                            decoration: const InputDecoration(
                              labelText: 'קבוצה',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                groups
                                    .map(
                                      (group) => DropdownMenuItem(
                                        value: group.id,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(group.name),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() => _selectedGroupId = value);
                            },
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('מתאריך'),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () => _selectDate(isStart: true),
                              icon: const Icon(Icons.date_range),
                              label: Text(_dateFormatter.format(_startDate)),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('עד תאריך'),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () => _selectDate(isStart: false),
                              icon: const Icon(Icons.event),
                              label: Text(_dateFormatter.format(_endDate)),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _generateReport,
                          icon: const Icon(Icons.assessment_outlined),
                          label: const Text('יצירת דו"ח'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              _matrix.isEmpty || _isLoading
                                  ? null
                                  : _exportToExcel,
                          icon: const Icon(Icons.table_chart_outlined),
                          label: const Text('ייצוא ל-Excel'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _matrix.isEmpty || _isLoading
                                  ? null
                                  : _exportToCsv,
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('ייצוא ל-CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _matrix.isEmpty || _isLoading
                                  ? null
                                  : _exportToPdf,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('ייצוא ל-PDF'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _matrix.isEmpty
                      ? Center(
                        child: Text(
                          'עדיין לא נוצר דו"ח. בחרו פעילות וקבוצה ולחצו על "יצירת דו"ח".',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                      : Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _ReportTable(
                            students: _students,
                            dates: _dates,
                            matrix: _matrix,
                            percentages: _percentages,
                            dateFormatter: _dateFormatter,
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      setState(() => _isLoading = true);
      final excel = excel_lib.Excel.createExcel();
      final sheet = excel['נוכחות'];
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          )
          .value = excel_lib.TextCellValue(
        'דו"ח נוכחות - ${_dateFormatter.format(_startDate)} עד ${_dateFormatter.format(_endDate)}',
      );

      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
          )
          .value = excel_lib.TextCellValue('שם החניך/ה');
      for (var i = 0; i < _dates.length; i++) {
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: i + 1,
                rowIndex: 2,
              ),
            )
            .value = excel_lib.TextCellValue(_dateFormatter.format(_dates[i]));
      }
      sheet
          .cell(
            excel_lib.CellIndex.indexByColumnRow(
              columnIndex: _dates.length + 1,
              rowIndex: 2,
            ),
          )
          .value = excel_lib.TextCellValue('אחוז נוכחות');

      for (var row = 0; row < _students.length; row++) {
        final student = _students[row];
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: row + 3,
              ),
            )
            .value = excel_lib.TextCellValue(student.fullName);
        for (var col = 0; col < _dates.length; col++) {
          final status = _matrix[student.id]![_dates[col]];
          final text = _statusLabel(status);
          sheet
              .cell(
                excel_lib.CellIndex.indexByColumnRow(
                  columnIndex: col + 1,
                  rowIndex: row + 3,
                ),
              )
              .value = excel_lib.TextCellValue(text);
        }
        sheet
            .cell(
              excel_lib.CellIndex.indexByColumnRow(
                columnIndex: _dates.length + 1,
                rowIndex: row + 3,
              ),
            )
            .value = excel_lib.TextCellValue(
          '${_percentages[student.id]?.toStringAsFixed(1) ?? '0'}%',
        );
      }

      final bytes = excel.encode()!;
      final fileName =
          'attendance_${_keyFormatter.format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        await saveFileWeb(
          Uint8List.fromList(bytes),
          fileName,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('הקובץ ירד בהצלחה.')));
      } else {
        final path = await _choosePath(fileName: fileName, extension: 'xlsx');
        if (path != null) {
          final file = io.File(path);
          await file.writeAsBytes(bytes, flush: true);
          await OpenFile.open(path);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('הקובץ נשמר ב-$path')));
        }
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('אירעה שגיאה בייצוא Excel: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportToCsv() async {
    try {
      setState(() => _isLoading = true);
      final rows = <List<String>>[];
      final header = <String>['שם החניך/ה'];
      header.addAll(_dates.map(_dateFormatter.format));
      header.add('אחוז נוכחות');
      rows.add(header);

      for (final student in _students) {
        final row = <String>[student.fullName];
        for (final date in _dates) {
          row.add(_statusLabel(_matrix[student.id]![date]));
        }
        row.add('${_percentages[student.id]?.toStringAsFixed(1) ?? '0'}%');
        rows.add(row);
      }

      final csvConverter = const ListToCsvConverter();
      final csvData = csvConverter.convert(rows);
      final bytes = utf8.encode(csvData);
      final fileName = 'attendance_${_keyFormatter.format(DateTime.now())}.csv';

      if (kIsWeb) {
        await saveFileWeb(Uint8List.fromList(bytes), fileName, 'text/csv');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('קובץ CSV ירד בהצלחה.')));
      } else {
        final path = await _choosePath(fileName: fileName, extension: 'csv');
        if (path != null) {
          final file = io.File(path);
          await file.writeAsBytes(bytes, flush: true);
          await OpenFile.open(path);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('קובץ CSV נשמר ב-$path')));
        }
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('אירעה שגיאה בייצוא CSV: $error')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportToPdf() async {
    try {
      setState(() => _isLoading = true);
      final pdf = pw.Document();
      // Using built-in fonts instead of Google Fonts for PDF
      final regularFont = pw.Font.helvetica();
      final boldFont = pw.Font.helveticaBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(
                      'דו"ח נוכחות',
                      style: pw.TextStyle(font: boldFont, fontSize: 22),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'תקופה: ${_dateFormatter.format(_startDate)} - ${_dateFormatter.format(_endDate)}',
                      style: pw.TextStyle(font: regularFont, fontSize: 14),
                    ),
                    pw.SizedBox(height: 18),
                    _buildPdfTable(regularFont, boldFont),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'attendance_${_keyFormatter.format(DateTime.now())}.pdf';

      if (kIsWeb) {
        await saveFileWeb(bytes, fileName, 'application/pdf');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('קובץ PDF ירד בהצלחה.')));
      } else {
        final path = await _choosePath(fileName: fileName, extension: 'pdf');
        if (path != null) {
          final file = io.File(path);
          await file.writeAsBytes(bytes, flush: true);
          await OpenFile.open(path);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('קובץ PDF נשמר ב-$path')));
        }
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('אירעה שגיאה בייצוא PDF: $error')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  pw.Table _buildPdfTable(pw.Font regularFont, pw.Font boldFont) {
    final headerCells = <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          'שם החניך/ה',
          style: pw.TextStyle(font: boldFont, fontSize: 10),
        ),
      ),
      ..._dates.map(
        (date) => pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            _dateFormatter.format(date),
            style: pw.TextStyle(font: boldFont, fontSize: 9),
          ),
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          'אחוז נוכחות',
          style: pw.TextStyle(font: boldFont, fontSize: 10),
        ),
      ),
    ];

    final dataRows =
        _students.map((student) {
          final cells = <pw.Widget>[
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                student.fullName,
                style: pw.TextStyle(font: regularFont, fontSize: 9),
              ),
            ),
            ..._dates.map((date) {
              final status = _matrix[student.id]![date];
              final text = _statusLabel(status);
              final color =
                  status == AttendanceStatus.present
                      ? PdfColors.green
                      : status == AttendanceStatus.absent
                      ? PdfColors.red
                      : PdfColors.grey700;
              return pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Center(
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 9,
                      color: color,
                    ),
                  ),
                ),
              );
            }),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                '${_percentages[student.id]?.toStringAsFixed(1) ?? '0'}%',
                style: pw.TextStyle(font: regularFont, fontSize: 9),
              ),
            ),
          ];
          return pw.TableRow(children: cells);
        }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
      children: [pw.TableRow(children: headerCells), ...dataRows],
    );
  }

  Future<String?> _choosePath({
    required String fileName,
    required String extension,
  }) async {
    if (io.Platform.isAndroid || io.Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$fileName';
    }
    final result = await FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    return result;
  }

  String _statusLabel(AttendanceStatus? status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'נוכח';
      case AttendanceStatus.absent:
        return 'חסר';
      default:
        return '-';
    }
  }
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.students,
    required this.dates,
    required this.matrix,
    required this.percentages,
    required this.dateFormatter,
  });

  final List<Student> students;
  final List<DateTime> dates;
  final Map<String, Map<DateTime, AttendanceStatus?>> matrix;
  final Map<String, double> percentages;
  final DateFormat dateFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: theme.textTheme.bodyMedium,
        columns: [
          const DataColumn(label: Text('שם החניך/ה')),
          ...dates.map(
            (date) => DataColumn(label: Text(dateFormatter.format(date))),
          ),
          const DataColumn(label: Text('אחוז נוכחות')),
        ],
        rows:
            students.map((student) {
              final cells = <DataCell>[
                DataCell(Text(student.fullName)),
                ...dates.map((date) {
                  final status = matrix[student.id]![date];
                  final text =
                      status == AttendanceStatus.present
                          ? 'נוכח'
                          : status == AttendanceStatus.absent
                          ? 'חסר'
                          : '-';
                  final color =
                      status == AttendanceStatus.present
                          ? Colors.green[700]
                          : status == AttendanceStatus.absent
                          ? Colors.red[700]
                          : Colors.grey[600];
                  return DataCell(
                    Center(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  );
                }),
                DataCell(
                  Text(
                    '${percentages[student.id]?.toStringAsFixed(1) ?? '0'}%',
                  ),
                ),
              ];
              return DataRow(cells: cells);
            }).toList(),
      ),
    );
  }
}
