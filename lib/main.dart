import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

const navy = Color(0xFF12233F);
const orange = Color(0xFFF26B38);
const canvas = Color(0xFFF6F7F9);
const ink = Color(0xFF18283F);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ControlPatioApp());
}

class _ShiftLoadingView extends StatefulWidget {
  const _ShiftLoadingView({required this.shiftLabel});

  final String shiftLabel;

  @override
  State<_ShiftLoadingView> createState() => _ShiftLoadingViewState();
}

class _ShiftLoadingViewState extends State<_ShiftLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF12233F),
            const Color(0xFF1A2F4F),
            orange.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * 3.141592653589793,
                child: child,
              );
            },
            child: Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Color(0x7AFFFFFF),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buscando turno...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.shiftLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cargando jornada y validando datos…',
                  style: TextStyle(
                    color: Color(0xFFEAEFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Driver {
  Driver({
    required this.id,
    required this.name,
    required this.plate,
    required this.phone,
    required this.client,
    required this.operation,
    this.arrival = 'PENDIENTE',
    this.call = 'PENDIENTE',
  });
  final String id;
  final String name;
  final String plate;
  final String phone;
  final String client;
  String? operation;
  String arrival;
  String call;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'plate': plate,
    'phone': phone,
    'client': client,
    'operation': operation ?? 'Inspección',
    'arrival': arrival,
    'call': call,
  };
  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['id'] as String,
    name: json['name'] as String,
    plate: json['plate'] as String,
    phone: json['phone'] as String,
    client: json['client'] as String,
    operation: json['operation'] as String? ?? 'Inspección',
    arrival: json['arrival'] as String? ?? 'PENDIENTE',
    call: json['call'] as String? ?? 'PENDIENTE',
  );
}

class DriverParseResult {
  const DriverParseResult({
    this.name,
    this.id,
    this.plate,
    this.phone,
    this.client,
    this.operation,
  });

  final String? name;
  final String? id;
  final String? plate;
  final String? phone;
  final String? client;
  final String? operation;
}

String _cleanValue(String raw) {
  final value = raw
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ\- ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final cleaned = value.replaceAll(
    RegExp(
      r'(?:\s+(?:C[ÉE]DULA|CEDULA|CELULAR|TEL[ÉE]FONO|TELEFONO|PLACA|PATENTE|DEP[ÓO]SITO|DESTINO|CANT|OPERACI[ÓO]N|OPERACION))+$',
      caseSensitive: false,
    ),
    '',
  ).trim();

  return cleaned.isEmpty ? cleaned : cleaned.toUpperCase();
}

String _normalizeDriverOperation(String value) {
  final cleaned = value.trim().toLowerCase();
  if (cleaned.contains('coloc')) return 'Colocación';
  if (cleaned.contains('insp')) return 'Inspección';
  return value.trim();
}

String _stripDiacritics(String text) {
  return text
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ü', 'U')
      .replaceAll('Ñ', 'N')
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}

String _normalizeFieldKey(String label) {
  final normalized = _stripDiacritics(label)
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');

  if (normalized.contains('CHOFER') || normalized.contains('CONDUCTOR') || normalized.contains('NOMBRE') || normalized.contains('OPERADOR')) {
    return 'NAME';
  }
  if (normalized == 'CI' || normalized == 'CED' || normalized == 'CEDULA' || normalized.contains('IDENTIDAD') || normalized == 'ID') {
    return 'ID';
  }
  if (normalized.contains('PLACA') || normalized.contains('PATENTE')) {
    return 'PLATE';
  }
  if (normalized.contains('CELULAR') || normalized.contains('TELEF') || normalized.contains('MOVIL')) {
    return 'PHONE';
  }
  if (normalized.contains('OPERACION')) {
    return 'OPERATION';
  }
  if (normalized.contains('CLIENTE') || normalized.contains('PROVEEDOR') || normalized.contains('PRODUCTOR') || normalized.contains('DEPOSITO') || normalized.contains('DESTINO') || normalized.contains('CANT')) {
    return 'IGNORE';
  }
  return '';
}

String? _tableCellValue(Object? value) {
  if (value == null) return null;
  final string = value.toString().trim();
  return string.isEmpty ? null : string;
}

String? _valueAtRow(List<String> row, int? index) {
  if (index == null || index < 0 || index >= row.length) return null;
  return _tableCellValue(row[index]);
}

String _normalizeTableHeader(String value) {
  return _stripDiacritics(value)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _xlsxCellText(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<List<String>> _rowsFromXlsxBytes(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final sharedStrings = <String>[];

  for (final file in archive) {
    final name = file.name.toLowerCase();
    if (!name.endsWith('sharedstrings.xml')) continue;
    final xml = utf8.decode(file.content as List<int>);
    final texts = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
        .allMatches(xml)
        .map((match) => _xlsxCellText(match.group(1) ?? ''))
        .where((value) => value.isNotEmpty)
        .toList();
    sharedStrings.addAll(texts);
  }

  final rows = <List<String>>[];
  for (final file in archive) {
    final name = file.name.toLowerCase();
    if (!name.contains('worksheets/') || !name.endsWith('.xml')) {
      continue;
    }

    final xml = utf8.decode(file.content as List<int>);
    final rowMatches = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(xml);

    for (final rowMatch in rowMatches) {
      final rowXml = rowMatch.group(1) ?? '';
      final cellMatches = RegExp(r'<c\b[^>]*>(.*?)</c>', dotAll: true).allMatches(rowXml);
      final cells = <String>[];

      for (final cellMatch in cellMatches) {
        final fullCellXml = cellMatch.group(0) ?? '';
        final type = RegExp(r't="([^"]+)"').firstMatch(fullCellXml)?.group(1) ?? '';
        final valueXml = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(fullCellXml)?.group(1) ?? '';

        String value = '';
        if (type == 's' && valueXml.isNotEmpty) {
          final index = int.tryParse(valueXml) ?? -1;
          value = index >= 0 && index < sharedStrings.length ? sharedStrings[index] : '';
        } else if (type == 'inlineStr') {
          value = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
              .allMatches(fullCellXml)
              .map((match) => match.group(1) ?? '')
              .join(' ');
        } else if (type == 'b') {
          value = valueXml == '1' ? 'TRUE' : 'FALSE';
        } else if (valueXml.isNotEmpty) {
          value = valueXml;
        } else {
          value = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
              .allMatches(fullCellXml)
              .map((match) => match.group(1) ?? '')
              .join(' ');
        }

        cells.add(_xlsxCellText(value));
      }

      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }
  }

  return rows;
}

bool _looksLikeDriverTable(List<List<String>> rows) {
  if (rows.isEmpty) return false;
  final header = rows.first
      .map((cell) => _normalizeTableHeader(cell))
      .join(' ');
  return header.contains('chofer') ||
      header.contains('cedula') ||
      header.contains('celular') ||
      header.contains('placa');
}

List<List<String>> _parseDelimitedRows(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (normalized.isEmpty) return const [];

  final lines = normalized.split('\n').where((line) => line.trim().isNotEmpty).toList();
  if (lines.isEmpty) return const [];

  final counts = <String, int>{';': 0, ',': 0, '\t': 0};
  for (final line in lines.take(5)) {
    for (final delimiter in counts.keys) {
      counts[delimiter] = counts[delimiter]! + line.split(delimiter).length - 1;
    }
  }

  final entries = counts.entries.toList();
  entries.sort((a, b) => b.value.compareTo(a.value));
  final delimiter = entries.isNotEmpty ? entries.first.key : ';';

  final rows = <List<String>>[];
  for (final line in lines) {
    final cells = line.split(delimiter).map((value) {
      final trimmed = value.trim();
      if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length >= 2) {
        return trimmed.substring(1, trimmed.length - 1).trim();
      }
      return trimmed;
    }).toList();
    rows.add(cells);
  }

  return rows;
}

List<List<String>> readTableRowsFromFileBytes(List<int> bytes, String extension) {
  final normalizedExt = extension.toLowerCase();

  if (normalizedExt == 'csv' || normalizedExt == 'txt') {
    final text = utf8.decode(bytes, allowMalformed: true);
    final rows = _parseDelimitedRows(text);
    if (_looksLikeDriverTable(rows)) {
      return rows;
    }
    return const [];
  }

  if (normalizedExt == 'xlsx' || normalizedExt == 'xlsm') {
    return _rowsFromXlsxBytes(bytes);
  }

  return const [];
}

List<DriverParseResult> parseDriverRowsFromTable(List<List<String>> rows) {
  if (rows.isEmpty) return const [];

  final header = rows.first;
  final indexes = <String, int>{};

  for (var i = 0; i < header.length; i++) {
    final normalized = _normalizeTableHeader(header[i]);
    if (normalized.contains('chofer') || normalized.contains('conductor') || normalized.contains('nombre')) {
      indexes['NAME'] = i;
    } else if (normalized.contains('cedula') || normalized.contains('ci') || normalized.contains('identidad') || normalized.contains('id')) {
      indexes['ID'] = i;
    } else if (normalized.contains('placa') || normalized.contains('patente')) {
      indexes['PLATE'] = i;
    } else if (normalized.contains('celular') || normalized.contains('telefono') || normalized.contains('movil') || normalized.contains('tel')) {
      indexes['PHONE'] = i;
    } else if (normalized.contains('operacion')) {
      indexes['OPERATION'] = i;
    }
  }

  if (indexes.isEmpty) return const [];

  final results = <DriverParseResult>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.isEmpty || row.every((cell) => cell.trim().isEmpty)) {
      continue;
    }

    final name = _valueAtRow(row, indexes['NAME']);
    final id = _valueAtRow(row, indexes['ID']);
    final plate = _valueAtRow(row, indexes['PLATE']);
    final phone = _valueAtRow(row, indexes['PHONE']);
    final operation = _valueAtRow(row, indexes['OPERATION']);

    if (name == null && id == null && plate == null && phone == null && operation == null) {
      continue;
    }

    results.add(
      DriverParseResult(
        name: name == null || name.isEmpty ? 'CHOFER SIN NOMBRE' : name.trim(),
        id: id == null || id.isEmpty ? null : id.replaceAll(RegExp(r'[^0-9]'), ''),
        plate: plate == null || plate.isEmpty ? null : plate.replaceAll(RegExp(r'\s+'), '').toUpperCase(),
        phone: phone == null || phone.isEmpty ? null : phone.replaceAll(RegExp(r'[^0-9]'), ''),
        operation: operation == null || operation.isEmpty ? null : _normalizeDriverOperation(operation),
      ),
    );
  }

  return results;
}

List<DriverParseResult> parseDriverTextList(String rawText) {
  final text = rawText
      .replaceAll('\r', '\n')
      .trim();

  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final records = <Map<String, String>>[];
  final current = <String, String>{};
  final labelPattern = RegExp(
    r'^(CHOFER|CONDUCTOR|NOMBRE\s+COMPLETO|NOMBRE|OPERADOR|CÉDULA|CEDULA|CI|IDENTIDAD|ID|CELULAR|CEL|TELÉFONO|TELEFONO|TEL|MÓVIL|MOVIL|PLACA|PATENTE|CLIENTE|PROVEEDOR|PRODUCTOR|DEP[ÓO]SITO|DEST[ÍI]NO|CANT|OPERACI[ÓO]N)\s*[:\-]?\s*(.+)$',
    caseSensitive: false,
  );

  for (final line in lines) {
    final match = labelPattern.firstMatch(line);
    if (match == null) {
      final continuation = _cleanValue(line).trim();
      if (current.isNotEmpty && current.containsKey('NAME') && continuation.isNotEmpty && !current.containsKey('ID') && !current.containsKey('PLATE') && !current.containsKey('PHONE') && !current.containsKey('OPERATION')) {
        current['NAME'] = '${current['NAME']} $continuation'.trim();
        continue;
      }

      if (current.isNotEmpty) {
        records.add(Map<String, String>.from(current));
        current.clear();
      }
      continue;
    }

    final rawLabel = match.group(1) ?? '';
    final label = _normalizeFieldKey(rawLabel);
    if (label.isEmpty || label == 'IGNORE') continue;

    final value = _cleanValue(match.group(2) ?? '').trim();
    if (value.isEmpty) continue;

    if (label == 'NAME' && current.containsKey('NAME') && current.isNotEmpty) {
      records.add(Map<String, String>.from(current));
      current.clear();
    }

    current[label] = value;

    if (label == 'OPERATION' && current.containsKey('NAME')) {
      records.add(Map<String, String>.from(current));
      current.clear();
    }
  }

  if (current.isNotEmpty) {
    records.add(Map<String, String>.from(current));
  }

  final results = <DriverParseResult>[];
  for (final record in records) {
    final name = record['NAME'];
    final id = record['ID']?.replaceAll(RegExp(r'[^0-9]'), '');
    final plate = record['PLATE']?.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final phone = record['PHONE']?.replaceAll(RegExp(r'[^0-9]'), '');
    final operation = record['OPERATION'] == null
        ? null
        : _normalizeDriverOperation(record['OPERATION']!);

    final item = DriverParseResult(
      name: name == null || name.isEmpty ? null : name,
      id: id == null || id.isEmpty ? null : id,
      plate: plate == null || plate.isEmpty ? null : plate,
      phone: phone == null || phone.isEmpty ? null : phone,
      client: null,
      operation: operation == '' ? null : operation,
    );

    if (item.name != null || item.id != null || item.plate != null || item.phone != null || item.operation != null) {
      results.add(item);
    }
  }

  return results;
}

DriverParseResult parseDriverText(String rawText) {
  final parsed = parseDriverTextList(rawText);
  if (parsed.isEmpty) {
    return const DriverParseResult();
  }
  return parsed.first;
}

class ControlPatioApp extends StatelessWidget {
  const ControlPatioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Control Patio',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF3F6FB),
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        brightness: Brightness.light,
      ),
      fontFamily: 'Trebuchet MS',
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.blueGrey.shade50, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blueGrey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: orange, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFE3D8),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
    ),
    home: const ControlHome(),
  );
}

class ControlHome extends StatefulWidget {
  const ControlHome({super.key});

  @override
  State<ControlHome> createState() => _ControlHomeState();
}

class _ControlHomeState extends State<ControlHome> {
  final drivers = <Driver>[];
  final history = <Map<String, dynamic>>[];
  final inspectors = <String>[];
  final selected = <String>{};
  final journeyDriverIds = <String>{};
  final driverSearchController = TextEditingController();
  int tab = 0;
  String shift = '';
  String operation = 'Inspección';
  DateTime? shiftDate;
  bool loading = true;
  String sheetsUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    driverSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('drivers') ?? <String>[];
    if (!mounted) return;
    setState(() {
      drivers
        ..clear()
        ..addAll(
          saved.map(
            (item) => Driver.fromJson(jsonDecode(item) as Map<String, dynamic>),
          ),
        );
      history
        ..clear()
        ..addAll(
          (prefs.getStringList('history') ?? <String>[]).map(
            (item) => jsonDecode(item) as Map<String, dynamic>,
          ),
        );
      shift = prefs.getString('shift') ?? '';
      sheetsUrl = prefs.getString('sheetsUrl') ?? '';
      operation = prefs.getString('operation') ?? 'Inspección';
      inspectors
        ..clear()
        ..addAll(prefs.getStringList('inspectors') ?? <String>[]);
      journeyDriverIds
        ..clear()
        ..addAll(prefs.getStringList('journeyDriverIds') ?? <String>[]);
      if (journeyDriverIds.isEmpty &&
          (prefs.getString('shift') ?? '').isNotEmpty) {
        journeyDriverIds.addAll(drivers.map((driver) => driver.id));
      }
      shiftDate = DateTime.tryParse(prefs.getString('shiftDate') ?? '');
      loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'drivers',
      drivers.map((driver) => jsonEncode(driver.toJson())).toList(),
    );
    await prefs.setString('shift', shift);
    await prefs.setString('sheetsUrl', sheetsUrl);
    await prefs.setString('operation', operation);
    await prefs.setStringList('inspectors', inspectors);
    await prefs.setStringList('journeyDriverIds', journeyDriverIds.toList());
    await prefs.setStringList(
      'history',
      history.map((record) => jsonEncode(record)).toList(),
    );
    if (shiftDate != null) {
      await prefs.setString('shiftDate', shiftDate!.toIso8601String());
    } else {
      await prefs.remove('shiftDate');
    }
  }

  Future<void> _newShift() async {
    var isLoading = false;
    var selectedShift = '';
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final navigator = Navigator.of(dialogContext);

          Future<void> handleSelect(String option) async {
            if (isLoading) return;
            setDialogState(() {
              isLoading = true;
              selectedShift = option;
            });
            await Future<void>.delayed(const Duration(milliseconds: 300));
            if (!navigator.mounted) return;
            navigator.pop(option);
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FAFF),
                    Color(0xFFF4F7FB),
                    Color(0xFFF9F2EA),
                  ],
                ),
                border: Border.all(color: const Color(0xFFE6EAF2), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: navy.withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          navy,
                          navy.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.schedule_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Preparar jornada',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Selecciona el turno que vas a coordinar.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF52677A),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Column(
                    children: [
                      Row(
                        key: const ValueKey('options'),
                        children: [
                          Expanded(
                            child: _shiftOptionCard(
                              label: 'DÍA',
                              hours: '07:00 - 19:00',
                              color: const Color(0xFF0284C7),
                              isSelected: selectedShift == 'DÍA',
                              onPressed: () => handleSelect('DÍA'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _shiftOptionCard(
                              label: 'NOCHE',
                              hours: '19:00 - 07:00',
                              color: const Color(0xFF312E81),
                              isSelected: selectedShift == 'NOCHE',
                              onPressed: () => handleSelect('NOCHE'),
                            ),
                          ),
                        ],
                      ),
                      if (isLoading)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF12233F).withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: _ShiftLoadingView(shiftLabel: selectedShift),
                        )
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (choice == null) return;
    setState(() {
      shift = choice;
      shiftDate = DateTime.now();
      selected.clear();
      journeyDriverIds
        ..clear()
        ..addAll(drivers.map((driver) => driver.id));
      inspectors.clear();
      for (final driver in drivers) {
        driver.arrival = 'PENDIENTE';
        driver.call = 'PENDIENTE';
      }
    });
    await _save();
  }

  Widget _shiftOptionCard({
    required String label,
    required String hours,
    required Color color,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return AnimatedScale(
      scale: isSelected ? 1.04 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(16),
            transform: Matrix4.translationValues(
              0.0,
              isSelected ? -2.0 : 0.0,
              0.0,
            ),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.08),
                        Colors.white,
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF7F9FC),
                      ],
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.22),
                width: isSelected ? 2.2 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? color.withValues(alpha: 0.22)
                      : color.withValues(alpha: 0.08),
                  blurRadius: isSelected ? 20 : 10,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  hours,
                  style: TextStyle(
                    color: isSelected ? color : navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editInspectors() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => InspectorDialog(initialInspectors: inspectors),
    );
    if (result == null) return;
    setState(() {
      inspectors
        ..clear()
        ..addAll(result);
    });
    await _save();
  }

  Future<void> _processImportedExcelRows(List<int> bytes, String extension) async {
    final rows = readTableRowsFromFileBytes(bytes, extension);
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para importar desde Excel, usa un archivo CSV o XLSX/XLSM.')),
        );
      }
      return;
    }

    final parsed = parseDriverRowsFromTable(rows);
    if (parsed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El archivo no trae columnas válidas de chofer, cédula, teléfono o placa.')),
        );
      }
      return;
    }

    final imported = parsed
        .where((entry) => entry.name != null || entry.id != null || entry.phone != null || entry.plate != null)
        .map(
          (entry) => Driver(
            id: entry.id ?? '',
            name: entry.name ?? 'CHOFER SIN NOMBRE',
            plate: entry.plate ?? '',
            phone: entry.phone ?? '',
            client: '',
            operation: entry.operation ?? operation,
          ),
        )
        .where((driver) => driver.id.isNotEmpty || driver.name != 'CHOFER SIN NOMBRE' || driver.plate.isNotEmpty || driver.phone.isNotEmpty)
        .toList();

    if (imported.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron choferes válidos en el archivo.')),
        );
      }
      return;
    }

    final valid = <Driver>[];
    for (final driver in imported) {
      final exists = drivers.any((item) => item.id.isNotEmpty && item.id == driver.id);
      if (exists) continue;
      valid.add(driver);
    }

    setState(() => drivers.addAll(valid));
    await _save();

    if (mounted) {
      final message = valid.length == 1
          ? 'Chofer importado desde Excel.'
          : 'Se importaron ${valid.length} choferes desde Excel.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _importDriversFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'xlsx', 'xlsm'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (file.path == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo leer el archivo seleccionado.')),
            );
          }
          return;
        }
        final data = await File(file.path!).readAsBytes();
        await _processImportedExcelRows(data, file.extension ?? '');
        return;
      }

      await _processImportedExcelRows(bytes, file.extension ?? '');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo importar el Excel: $error')),
        );
      }
    }
  }

  /// Abre un diálogo para configurar la URL pública CSV del Google Sheet.
  Future<void> _setSheetsUrl() async {
    final ctrl = TextEditingController(text: sheetsUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configurar Google Sheets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega la URL de publicación CSV de tu Google Sheet.\n\n'
              'En Google Sheets:\n'
              'Archivo → Compartir → Publicar en la web → CSV → Copiar enlace',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'URL pública CSV',
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => sheetsUrl = result);
    await _save();
    if (mounted && result.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL de Sheets guardada.')),
      );
    }
  }

  /// Descarga el CSV del Google Sheet y muestra un diálogo para seleccionar
  /// qué choferes importar y asignarles un cliente.
  Future<void> _importDriversFromSheets() async {
    if (sheetsUrl.isEmpty) {
      await _setSheetsUrl();
      if (sheetsUrl.isEmpty) return;
    }

    // Mostrar loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Descargando datos de Sheets...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );
    }

    List<List<dynamic>> rows;
    try {
      final uri = Uri.parse(sheetsUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final csvStr = response.body;
      rows = const CsvToListConverter(eol: '\n').convert(csvStr);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar Sheets: $e')),
        );
      }
      return;
    }

    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El Sheet está vacío o no tiene datos.')),
        );
      }
      return;
    }

    // Detectar columnas por encabezado (primera fila)
    final header = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    int colId = -1, colName = -1, colPhone = -1;
    for (var i = 0; i < header.length; i++) {
      final h = _stripDiacritics(header[i]);
      if (colId < 0 && (h.contains('cedula') || h.contains('ci') || h == 'id')) colId = i;
      if (colName < 0 && (h.contains('nombre') || h.contains('name'))) colName = i;
      if (colPhone < 0 && (h.contains('telef') || h.contains('cel') || h.contains('phone') || h.contains('movil'))) colPhone = i;
    }
    // Si no detectó, usar posiciones 0,1,2 por defecto
    if (colId < 0) colId = 0;
    if (colName < 0) colName = 1;
    if (colPhone < 0) colPhone = 2;

    final sheetDrivers = rows.skip(1).where((r) => r.length > colName).map((r) {
      final id = colId < r.length ? r[colId].toString().trim() : '';
      final name = colName < r.length ? r[colName].toString().trim().toUpperCase() : 'SIN NOMBRE';
      final phone = colPhone < r.length ? r[colPhone].toString().trim() : '';
      return _SheetsDriverEntry(id: id, name: name, phone: phone);
    }).where((e) => e.name.isNotEmpty && e.name != 'SIN NOMBRE').toList();

    if (sheetDrivers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron choferes en el Sheet.')),
        );
      }
      return;
    }

    // Mostrar diálogo de selección
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _SheetsImportDialog(
        entries: sheetDrivers,
        existingIds: drivers.map((d) => d.id).toSet(),
        defaultOperation: operation,
        onImport: (selected) async {
          if (selected.isEmpty) return;
          final valid = selected.where((d) => !drivers.any((e) => e.id.isNotEmpty && e.id == d.id)).toList();
          setState(() => drivers.addAll(valid));
          await _save();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${valid.length} chofer(es) importado(s) desde Sheets.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _addDriver() async {
    final driver = await showDialog<Driver>(
      context: context,
      builder: (_) => DriverDialog(operation: operation),
    );
    if (driver == null) return;
    if (drivers.any((item) => item.id == driver.id)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La cédula ya existe en la base.')),
        );
      }
      return;
    }
    setState(() => drivers.add(driver));
    await _save();
  }

  Future<void> _editDriver(Driver current) async {
    final updated = await showDialog<Driver>(
      context: context,
      builder: (_) => DriverDialog(
        operation: current.operation ?? 'Inspección',
        initialDriver: current,
      ),
    );
    if (updated == null) return;
    final duplicate = drivers.any(
      (item) => item.id == updated.id && item.id != current.id,
    );
    if (duplicate) {
      _showAlert(
        'Cédula duplicada',
        'Ya existe otro chofer con esa cédula.',
        DialogType.warning,
      );
      return;
    }
    final index = drivers.indexOf(current);
    if (index < 0) return;
    setState(() {
      drivers[index] = updated;
      if (journeyDriverIds.remove(current.id)) journeyDriverIds.add(updated.id);
    });
    await _save();
  }

  Future<void> _deleteDriver(Driver driver) async {
    var confirmed = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'Eliminar chofer',
      desc:
          'Se eliminará ${driver.name} de ${driver.client} en ${driver.operation ?? 'Inspección'}. Esta acción no se puede deshacer.',
      btnCancelText: 'Cancelar',
      btnOkText: 'Eliminar',
      btnCancelOnPress: () {},
      btnOkOnPress: () => confirmed = true,
    ).show();
    if (!confirmed) return;
    setState(() {
      drivers.remove(driver);
      selected.remove(driver.id);
      journeyDriverIds.remove(driver.id);
    });
    await _save();
  }

  void _showAlert(String title, String description, DialogType type) {
    AwesomeDialog(
      context: context,
      dialogType: type,
      animType: AnimType.scale,
      title: title,
      desc: description,
      btnOkText: 'Aceptar',
      btnOkOnPress: () {},
    ).show();
  }

  Future<void> _addSelected() async {
    if (shift.isEmpty) {
      await _newShift();
      return;
    }
    setState(() {
      journeyDriverIds.addAll(selected);
      selected.clear();
      tab = 0;
    });
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choferes agregados a la jornada actual.'),
        ),
      );
    }
  }

  Future<void> _closeDay() async {
    if (journeyDriverIds.isEmpty || shift.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prepara una jornada y agrega choferes primero.'),
        ),
      );
      return;
    }
    if (inspectors.isEmpty) {
      _showAlert(
        'Inspectores sin registrar',
        'Agrega los inspectores de turno antes de cerrar la jornada.',
        DialogType.warning,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar jornada'),
        content: const Text(
          'Se guardará un registro del día con Inspección y Colocación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar día'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final record = {
      'closedAt': DateTime.now().toIso8601String(),
      'date': _date(shiftDate ?? DateTime.now()),
      'shift': shift,
      'inspectors': List<String>.from(inspectors),
      'drivers': drivers
          .where((driver) => journeyDriverIds.contains(driver.id))
          .map((driver) => driver.toJson())
          .toList(),
    };
    setState(() {
      history.insert(0, record);
      journeyDriverIds.clear();
      selected.clear();
      inspectors.clear();
      shift = '';
      shiftDate = null;
    });
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jornada guardada en el historial.')),
      );
      setState(() => tab = 3);
    }
  }

  Future<void> _generateDailyPdf() async {
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay operaciones para generar el PDF.'),
        ),
      );
      return;
    }

    try {
      final document = pw.Document();
      final date = _date(DateTime.now());
      if (journeyDriverIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selecciona choferes para la jornada antes de generar el PDF.',
            ),
          ),
        );
        return;
      }
      final operations = ['Inspección', 'Colocación'];
      document.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'CONTROL PATIO MARIA',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: pdf.PdfColors.blue900,
                ),
              ),
              pw.Text(
                'REPORTE DIARIO  $date  |  FORMATO A4',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 22),
            pw.Text(
              'Operaciones realizadas',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              shift.isEmpty
                  ? 'Sin turno especificado'
                  : 'Turno: $shift  |  ${shift == 'DÍA' ? '07:00 - 19:00' : '19:00 - 07:00'}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: pdf.PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              inspectors.isEmpty
                  ? 'Inspectores: no registrados'
                  : 'Inspectores: ${inspectors.join(', ')}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: pdf.PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 20),
            ...operations.map(_pdfOperationSection),
            ..._pdfHandoverSection(),
          ],
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfPreview(
            build: (format) async => document.save(),
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            pdfFileName: 'control_patio_$date.pdf',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $error')),
      );
    }
  }

  pw.Widget _pdfOperationSection(String name) {
    final operationDrivers = drivers
        .where(
          (driver) =>
              journeyDriverIds.contains(driver.id) &&
              (driver.operation ?? 'Inspección') == name,
        )
        .toList();
    final clients = <String, List<Driver>>{};
    for (final driver in operationDrivers) {
      clients.putIfAbsent(driver.client, () => []).add(driver);
    }
    final arrivedCount = operationDrivers
        .where((driver) => driver.arrival == 'LLEGÓ')
        .length;
    final answeredCount = operationDrivers
        .where((driver) => driver.call == 'CONTESTÓ')
        .length;
    final rows = <pw.Widget>[
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        color: pdf.PdfColors.blue900,
        child: pw.Text(
          name.toUpperCase(),
          style: pw.TextStyle(
            color: pdf.PdfColors.white,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        'Programados: ${operationDrivers.length}   |   Llegaron: $arrivedCount   |   Contestaron: $answeredCount',
        style: const pw.TextStyle(fontSize: 9),
      ),
      pw.SizedBox(height: 10),
    ];
    if (clients.isEmpty) {
      rows.add(
        pw.Text(
          'No se registraron choferes en esta operación.',
          style: const pw.TextStyle(fontSize: 9, color: pdf.PdfColors.grey700),
        ),
      );
    } else {
      for (final entry in clients.entries) {
        rows.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
            child: pw.Text(
              'CLIENTE: ${entry.key}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: pdf.PdfColors.orange800,
              ),
            ),
          ),
        );
        rows.add(
          pw.TableHelper.fromTextArray(
            headers: const [
              'Chofer',
              'ID / Cédula',
              'Placa',
              'Llegada',
              'Llamada',
            ],
            data: entry.value
                .map(
                  (driver) => [
                    driver.name,
                    driver.id,
                    driver.plate,
                    driver.arrival,
                    driver.call,
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: pdf.PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: pdf.PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(5),
            border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: .5),
          ),
        );
      }
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [...rows, pw.SizedBox(height: 20)],
    );
  }

  List<pw.Widget> _pdfHandoverSection() {
    final pending = drivers.where((driver) {
      if (!journeyDriverIds.contains(driver.id)) return false;
      return driver.arrival != 'LLEGÓ' || driver.call == 'NO CONTESTÓ';
    }).toList();
    final rows = <pw.Widget>[
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        color: pdf.PdfColors.orange800,
        child: pw.Text(
          'CONSIGNA PARA LA GUARDIA ENTRANTE',
          style: pw.TextStyle(
            color: pdf.PdfColors.white,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        pending.isEmpty
            ? 'Sin observaciones pendientes. Todas las unidades llegaron y los choferes respondieron.'
            : 'Revisar y dar seguimiento a las siguientes novedades:',
        style: const pw.TextStyle(fontSize: 9),
      ),
      pw.SizedBox(height: 8),
    ];
    if (pending.isNotEmpty) {
      rows.add(
        pw.TableHelper.fromTextArray(
          headers: const [
            'Operación',
            'Cliente',
            'Chofer',
            'Observación',
            'Acción pendiente',
          ],
          data: pending.map((driver) {
            final observations = <String>[];
            final actions = <String>[];
            if (driver.arrival != 'LLEGÓ') {
              observations.add('Unidad pendiente de llegada');
              actions.add('Dar seguimiento a llegada');
            }
            if (driver.call == 'NO CONTESTÓ') {
              observations.add('El chofer no contestó');
              actions.add('Volver a llamar');
            }
            return [
              driver.operation ?? 'Inspección',
              driver.client,
              driver.name,
              observations.join('. '),
              actions.join('. '),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: pdf.PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: pdf.PdfColors.blueGrey800,
          ),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.all(5),
          border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: .5),
        ),
      );
    }
    return [...rows, pw.SizedBox(height: 20)];
  }

  Iterable<Driver> get activeDrivers => drivers.where(
    (driver) =>
        journeyDriverIds.contains(driver.id) &&
        (driver.operation ?? 'Inspección') == operation,
  );
  int get assigned => activeDrivers.length;
  int get arrived =>
      activeDrivers.where((driver) => driver.arrival == 'LLEGÓ').length;
  int get answered =>
      activeDrivers.where((driver) => driver.call == 'CONTESTÓ').length;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: navy,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(orange),
                strokeWidth: 3.5,
              ),
              SizedBox(height: 20),
              Text(
                'CONTROL PATIO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final pages = [
      _journeyPage(),
      _driversPage(),
      _reportPage(),
      _historyPage(),
    ];
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF12233F),
                Color(0xFF1A2F4F),
                Color(0xFF0F1F38),
              ],
            ),
          ),
        ),
        title: const Text(
          'CONTROL PATIO',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            fontSize: 15,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _generateDailyPdf,
            tooltip: 'Generar PDF del día',
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),

          IconButton(
            onPressed: _closeDay,
            tooltip: 'Cerrar jornada y guardar historial',
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF4F7FB),
              Color(0xFFF1F5FF),
              Color(0xFFF7F1EB),
            ],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: tab,
            children: pages,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Jornada',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Choferes',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Reporte',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
      floatingActionButton: tab == 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  onPressed: _addDriver,
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Nuevo chofer'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  onPressed: _importDriversFromSheets,
                  backgroundColor: const Color(0xFF1B7F4A),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Importar Sheets'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  onPressed: _importDriversFromExcel,
                  backgroundColor: const Color(0xFF1F355D),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Importar Excel'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _setSheetsUrl,
                  backgroundColor: const Color(0xFF4A4A4A),
                  foregroundColor: Colors.white,
                  mini: true,
                  tooltip: 'Configurar URL de Sheets',
                  child: const Icon(Icons.settings_outlined, size: 18),
                ),
              ],
            )
          : null,
    );
  }

  Widget _journeyPage() {
    final visible = drivers
        .where(
          (driver) =>
              journeyDriverIds.contains(driver.id) &&
              (driver.operation ?? 'Inspección') == operation,
        )
        .toList();
    final total = activeDrivers.length;
    final arrivedCount = arrived;

    return ListView(
      key: const PageStorageKey('journey_page'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _journeyHero(total, arrivedCount),
        const SizedBox(height: 14),
        _inspectorsCard(),
        const SizedBox(height: 14),
        _operationSwitch(),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              height: 22,
              width: 4,
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Seguimiento en patio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: navy,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: navy.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${visible.length} ${visible.length == 1 ? 'unidad' : 'unidades'}',
                style: TextStyle(
                  color: navy.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (drivers.isEmpty)
          _empty(
            'Aún no hay choferes',
            'Agrega choferes desde la pestaña Choferes para armar tu jornada.',
            Icons.local_shipping_outlined,
          )
        else if (visible.isEmpty)
          _empty(
            'Jornada sin unidades',
            'No hay choferes de $operation en esta jornada. Selecciónalos en la pestaña Choferes.',
            Icons.playlist_add_check_circle_outlined,
          )
        else
          ...visible.map(_driverCard),
      ],
    );
  }

  Widget _journeyHero(int total, int arrivedCount) {
    final hasShift = shift.isNotEmpty;
    final isDay = shift == 'DÍA';
    final progress = total == 0 ? 0.0 : arrivedCount / total;
    final percent = (progress * 100).round();

    final heroTitle = !hasShift
        ? 'Sin jornada'
        : isDay
            ? 'Jornada de Día'
            : 'Jornada de Noche';

    final heroSubtitle = !hasShift
        ? 'Toca para seleccionar turno'
        : isDay
            ? '07:00 - 19:00'
            : '19:00 - 07:00';

    final gradientColors = !hasShift
        ? const [
            Color(0xFF16294A),
            Color(0xFF1C355E),
            Color(0xFF12233F),
          ]
        : isDay
            ? const [
                Color(0xFF1E3A8A),
                Color(0xFF2563EB),
                Color(0xFF38BDF8),
              ]
            : const [
                Color(0xFF0B1322),
                Color(0xFF161C3D),
                Color(0xFF351C56),
              ];

    final iconColor = !hasShift
        ? Colors.white
        : isDay
            ? const Color(0xFFFEF08A)
            : const Color(0xFFA5B4FC);

    final iconBgColor = !hasShift
        ? Colors.white.withValues(alpha: 0.10)
        : isDay
            ? Colors.white.withValues(alpha: 0.20)
            : const Color(0xFFA5B4FC).withValues(alpha: 0.18);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _newShift,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: navy.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -28,
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: -36,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDay ? const Color(0xFF38BDF8) : const Color(0xFF818CF8)).withValues(alpha: 0.15),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'JORNADA ACTIVA',
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const Spacer(),
                        if (shiftDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 10.5,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _date(shiftDate),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            !hasShift
                                ? Icons.access_time_filled_rounded
                                : isDay
                                    ? Icons.wb_sunny_rounded
                                    : Icons.nightlight_round,
                            color: iconColor,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                heroTitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: .3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                heroSubtitle,
                                style: TextStyle(
                                  color: isDay
                                      ? const Color(0xFFE0F2FE)
                                      : const Color(0xFFC7D2FE),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Text(
                            operation.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!hasShift)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _newShift,
                          style: FilledButton.styleFrom(
                            backgroundColor: orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text(
                            'Iniciar jornada',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Row(
                        children: [
                          const Text(
                            'Llegadas confirmadas',
                            style: TextStyle(
                              color: Color(0xFFCBD9F2),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$arrivedCount / $total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· $percent%',
                            style: TextStyle(
                              color: isDay ? const Color(0xFFE0F2FE) : orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: isDay ? 0.25 : 0.14),
                            valueColor: AlwaysStoppedAnimation(
                              isDay ? Colors.white : orange,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inspectorsCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _editInspectors,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: navy.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_pin_circle_outlined,
                      color: orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Inspectores de turno',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: navy,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (inspectors.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: navy,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${inspectors.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: navy.withValues(alpha: 0.45),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (inspectors.isEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 15,
                      color: orange.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Toca para registrar los inspectores',
                      style: TextStyle(
                        color: navy.withValues(alpha: 0.5),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: inspectors
                      .map(
                        (name) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F6FD),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: navy.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 13,
                                color: navy,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                name,
                                style: const TextStyle(
                                  color: navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _operationSwitch() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: navy.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _operationPill('Inspección', Icons.fact_check_outlined),
          ),
          Expanded(child: _operationPill('Colocación', Icons.build_outlined)),
        ],
      ),
    );
  }

  Widget _operationPill(String value, IconData icon) {
    final isSelected = operation == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isSelected
            ? null
            : () async {
                setState(() => operation = value);
                await _save();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? navy : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.white : navy.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : navy.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driversPage() {
    final query = driverSearchController.text.trim().toLowerCase();
    final operationDrivers = drivers
        .where((driver) => (driver.operation ?? 'Inspección') == operation)
        .where((driver) {
          if (query.isEmpty) return true;
          final cedula = driver.id.toLowerCase();
          final nombre = driver.name.toLowerCase();
          return cedula.contains(query) || nombre.contains(query);
        })
        .toList();
    final clients = <String, List<Driver>>{};
    for (final driver in operationDrivers) {
      clients.putIfAbsent(driver.client, () => []).add(driver);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 100),
      children: [
        const Text(
          'Base permanente',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Selecciona las unidades para la jornada actual.',
          style: TextStyle(color: Colors.blueGrey.shade600),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: driverSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por cédula o nombre',
            prefixIcon: const Icon(Icons.search_outlined),
            suffixIcon: driverSearchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      driverSearchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Inspección',
              label: Text('Inspección'),
              icon: Icon(Icons.fact_check_outlined),
            ),
            ButtonSegment(
              value: 'Colocación',
              label: Text('Colocación'),
              icon: Icon(Icons.build_outlined),
            ),
          ],
          selected: {operation},
          onSelectionChanged: (value) async {
            setState(() => operation = value.first);
            await _save();
          },
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                operation == 'Inspección'
                    ? Icons.fact_check_outlined
                    : Icons.build_outlined,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                'CHOFERES DE $operation',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (operationDrivers.isEmpty)
          _empty(
            'Base vacía',
            query.isEmpty
                ? 'Registra el primer chofer con el botón inferior.'
                : 'No se encontraron coincidencias por "$query".',
            Icons.person_search_outlined,
          )
        else
          ...clients.entries.map(
            (entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
                ...entry.value.map(
                  (driver) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    color: Colors.white,
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: selected.contains(driver.id),
                          onChanged: (value) => setState(
                            () => value == true
                                ? selected.add(driver.id)
                                : selected.remove(driver.id),
                          ),
                          activeColor: orange,
                          title: Text(
                            driver.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${driver.plate}\nID ${driver.id}  ·  ${driver.phone}',
                          ),
                          isThreeLine: true,
                          secondary: CircleAvatar(
                            backgroundColor: const Color(0xFFFFE3D8),
                            foregroundColor: orange,
                            child: Text(
                              driver.name.isEmpty
                                  ? '?'
                                  : driver.name[0].toUpperCase(),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () => _editDriver(driver),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Editar'),
                              ),
                              TextButton.icon(
                                onPressed: () => _deleteDriver(driver),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (operationDrivers.isNotEmpty)
          FilledButton.icon(
            onPressed: selected.isEmpty ? null : _addSelected,
            icon: const Icon(Icons.playlist_add_check),
            label: Text('Agregar ${selected.length} seleccionados a jornada'),
          ),
      ],
    );
  }

  Widget _driverCard(Driver driver) {
    final hasArrived = driver.arrival == 'LLEGÓ';
    final noAnswer = driver.call == 'NO CONTESTÓ';
    final accent = hasArrived
        ? const Color(0xFF12855B)
        : noAnswer
        ? const Color(0xFFC4322B)
        : orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: navy.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            driver.name.isEmpty
                                ? '?'
                                : driver.name[0].toUpperCase(),
                            style: TextStyle(
                              color: accent,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: navy,
                                  fontSize: 15.5,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: navy.withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      driver.plate,
                                      style: const TextStyle(
                                        color: navy,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      driver.client,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: navy.withValues(alpha: 0.5),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasArrived
                                    ? Icons.check_circle_rounded
                                    : noAnswer
                                    ? Icons.phone_missed_rounded
                                    : Icons.schedule_rounded,
                                size: 12,
                                color: accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                hasArrived ? 'EN PATIO' : 'EN ESPERA',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdown(
                            'Llegada',
                            driver.arrival,
                            ['PENDIENTE', 'LLEGÓ'],
                            (value) {
                              setState(() => driver.arrival = value!);
                              _save();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dropdown(
                            'Llamada',
                            driver.call,
                            ['PENDIENTE', 'CONTESTÓ', 'NO CONTESTÓ'],
                            (value) {
                              setState(() => driver.call = value!);
                              _save();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) {
    final current = values.contains(value) ? value : values.first;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 7, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: navy.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: navy.withValues(alpha: 0.42),
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 1),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              isDense: true,
              value: current,
              borderRadius: BorderRadius.circular(14),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: navy.withValues(alpha: 0.45),
              ),
              style: const TextStyle(fontSize: 12.5),
              items: values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        item,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _statusColor(item),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
    'LLEGÓ' || 'CONTESTÓ' => const Color(0xFF12855B),
    'NO CONTESTÓ' => const Color(0xFFC4322B),
    _ => navy,
  };

  Widget _reportPage() {
    final noAnswer = activeDrivers
        .where((driver) => driver.call == 'NO CONTESTÓ')
        .length;
    final pending = activeDrivers
        .where(
          (driver) => driver.arrival != 'LLEGÓ' || driver.call == 'NO CONTESTÓ',
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 80),
      children: [
        const Text(
          'Reporte de coordinación',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Resumen en tiempo real de la jornada.',
          style: TextStyle(color: Colors.blueGrey.shade600),
        ),
        const SizedBox(height: 22),
        _reportRow(
          'Unidades programadas',
          '$assigned',
          Icons.local_shipping_outlined,
          navy,
        ),
        _reportRow(
          'Unidades que llegaron',
          '$arrived',
          Icons.check_circle_outline,
          Colors.green.shade700,
        ),
        _reportRow(
          'Pendientes de llegar',
          '${assigned - arrived}',
          Icons.schedule,
          orange,
        ),
        _reportRow(
          'Choferes que contestaron',
          '$answered',
          Icons.phone_in_talk_outlined,
          Colors.blue.shade700,
        ),
        _reportRow(
          'No contestaron',
          '$noAnswer',
          Icons.phone_missed_outlined,
          Colors.red.shade700,
        ),
        const SizedBox(height: 24),
        const Text(
          'Consigna',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            pending.isEmpty
                ? 'Sin novedades pendientes.'
                : pending
                      .map(
                        (driver) =>
                            '• ${driver.name}: ${driver.arrival != 'LLEGÓ' ? 'pendiente de llegada' : 'volver a llamar'}',
                      )
                      .join('\n'),
            style: const TextStyle(height: 1.7, color: navy),
          ),
        ),
      ],
    );
  }

  Widget _reportRow(String label, String value, IconData icon, Color color) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: navy,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
  Widget _historyPage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 80),
    children: [
      const Text(
        'Historial',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Las jornadas cerradas aparecerán aquí.',
        style: TextStyle(color: Colors.blueGrey.shade600),
      ),
      const SizedBox(height: 26),
      if (history.isEmpty)
        _empty(
          'Sin jornadas cerradas',
          'Pulsa el archivo superior para guardar la jornada actual.',
          Icons.archive_outlined,
        )
      else
        ...history.map((record) {
          final savedDrivers = (record['drivers'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          final inspection = savedDrivers
              .where(
                (driver) =>
                    (driver['operation'] ?? 'Inspección') == 'Inspección',
              )
              .length;
          final placement = savedDrivers
              .where((driver) => driver['operation'] == 'Colocación')
              .length;
          return Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFE3D8),
                foregroundColor: orange,
                child: Icon(Icons.event_available_outlined),
              ),
              title: Text(
                '${record['date'] ?? 'Fecha sin registro'} · ${record['shift'] ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              subtitle: Text(
                'Inspección: $inspection choferes  ·  Colocación: $placement choferes\nInspectores: ${((record['inspectors'] as List<dynamic>?) ?? []).join(', ')}',
              ),
            ),
          );
        }),
    ],
  );
  Widget _empty(String title, String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Icon(icon, size: 48, color: orange),
        const SizedBox(height: 15),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.blueGrey.shade600, height: 1.4),
        ),
      ],
    ),
  );
  String _date(DateTime? date) => date == null
      ? ''
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class InspectorDialog extends StatefulWidget {
  const InspectorDialog({super.key, required this.initialInspectors});

  final List<String> initialInspectors;

  @override
  State<InspectorDialog> createState() => _InspectorDialogState();
}

class _InspectorDialogState extends State<InspectorDialog> {
  late final TextEditingController controller;
  late final List<String> names;
  final focusNode = FocusNode();
  String? error;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    names = widget.initialInspectors
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  /// Incluye el nombre que quedó escrito en el campo al guardar.
  List<String> _result() {
    final pending = controller.text.trim();
    final result = List<String>.of(names);
    final exists = result.any(
      (name) => name.toLowerCase() == pending.toLowerCase(),
    );
    if (pending.isNotEmpty && !exists) result.add(pending);
    return result;
  }

  void _add() {
    final value = controller.text.trim();
    if (value.isEmpty) {
      setState(() => error = 'Escribe un nombre para agregarlo.');
      return;
    }
    final exists = names.any(
      (name) => name.toLowerCase() == value.toLowerCase(),
    );
    if (exists) {
      setState(() => error = 'Ese inspector ya está en la lista.');
      return;
    }
    setState(() {
      names.add(value);
      controller.clear();
      error = null;
    });
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FAFF),
              Color(0xFFF4F7FB),
              Color(0xFFF9F2EA),
            ],
          ),
          border: Border.all(color: const Color(0xFFE6EAF2), width: 1),
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 16),
            const Text(
              'Agrega los inspectores que cubren esta jornada.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF52677A),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _input(),
            if (error != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 15, color: orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Flexible(child: names.isEmpty ? _emptyState() : _list()),
            const SizedBox(height: 18),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [navy, navy.withValues(alpha: 0.9)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_pin_circle_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Inspectores',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: orange,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: orange.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '${names.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            style: const TextStyle(
              color: navy,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              hintText: 'Nombre del inspector',
              hintStyle: TextStyle(
                color: navy.withValues(alpha: 0.35),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.badge_outlined,
                size: 20,
                color: navy.withValues(alpha: 0.45),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: navy.withValues(alpha: 0.18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: navy.withValues(alpha: 0.18)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: orange, width: 1.8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: navy,
          borderRadius: BorderRadius.circular(16),
          elevation: 3,
          shadowColor: navy.withValues(alpha: 0.35),
          child: InkWell(
            onTap: _add,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              height: 52,
              width: 52,
              child: Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: navy.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 34,
            color: navy.withValues(alpha: 0.28),
          ),
          const SizedBox(height: 10),
          Text(
            'Sin inspectores registrados',
            style: TextStyle(
              color: navy.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: names.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final name = names[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: navy.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: navy.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [navy, navy.withValues(alpha: 0.78)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  names.removeAt(index);
                  error = null;
                }),
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: orange.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: navy.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, _result()),
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
              shadowColor: navy.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: const Text(
              'Guardar',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class DriverDialog extends StatefulWidget {
  const DriverDialog({super.key, required this.operation, this.initialDriver});
  final String operation;
  final Driver? initialDriver;

  @override
  State<DriverDialog> createState() => _DriverDialogState();
}

class _DriverDialogState extends State<DriverDialog> {
  final formKey = GlobalKey<FormState>();
  final fields = List.generate(5, (_) => TextEditingController());
  late String selectedOperation;

  static const _fieldLabels = [
    'Cédula o ID',
    'Nombre del chofer',
    'Placa del vehículo',
    'Celular',
    'Cliente',
  ];

  static const _fieldHints = [
    'Ej. V-12345678',
    'Nombre y apellido',
    'Ej. AB123CD',
    'Ej. 0412 123 4567',
    'Empresa o destino',
  ];

  static const _fieldIcons = [
    Icons.badge_outlined,
    Icons.person_outline_rounded,
    Icons.local_shipping_outlined,
    Icons.phone_outlined,
    Icons.business_outlined,
  ];

  @override
  void initState() {
    super.initState();
    selectedOperation = widget.initialDriver?.operation ?? widget.operation;
    final driver = widget.initialDriver;
    if (driver != null) {
      fields[0].text = driver.id;
      fields[1].text = driver.name;
      fields[2].text = driver.plate;
      fields[3].text = driver.phone;
      fields[4].text = driver.client;
    }
  }

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Driver(
        id: fields[0].text.trim(),
        name: fields[1].text.trim(),
        plate: fields[2].text.trim().toUpperCase(),
        phone: fields[3].text.trim(),
        client: fields[4].text.trim(),
        operation: selectedOperation,
        arrival: widget.initialDriver?.arrival ?? 'PENDIENTE',
        call: widget.initialDriver?.call ?? 'PENDIENTE',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialDriver != null;
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenWidth > 680 ? 560 : 520),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: navy.withValues(alpha: 0.22),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isEditing),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height - 190,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Datos del chofer',
                          style: TextStyle(
                            color: navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Completa la información para registrarlo en la jornada.',
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.62),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...List.generate(
                          fields.length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 13),
                            child: TextFormField(
                              controller: fields[index],
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: index == fields.length - 1
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              keyboardType: index == 3
                                  ? TextInputType.phone
                                  : TextInputType.text,
                              onFieldSubmitted: index == fields.length - 1
                                  ? (_) => _save()
                                  : null,
                              decoration: InputDecoration(
                                labelText: _fieldLabels[index],
                                hintText: _fieldHints[index],
                                prefixIcon: Icon(_fieldIcons[index]),
                                floatingLabelStyle: const TextStyle(
                                  color: navy,
                                  fontWeight: FontWeight.w800,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 17,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Este campo es obligatorio';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Tipo de operación',
                          style: TextStyle(
                            color: navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0F7),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              _operationChoice(
                                'Inspección',
                                Icons.search_rounded,
                              ),
                              _operationChoice(
                                'Colocación',
                                Icons.build_outlined,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildActions(isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 19, 14, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12233F), Color(0xFF274B7A)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: Icon(
              isEditing
                  ? Icons.edit_outlined
                  : Icons.person_add_alt_1_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Editar chofer' : 'Nuevo chofer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isEditing
                      ? 'Actualiza sus datos de registro'
                      : 'Registra una unidad para la jornada',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Cerrar',
            color: Colors.white,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _operationChoice(String label, IconData icon) {
    final selected = selectedOperation == label;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedOperation = label),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.10),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? orange : navy.withValues(alpha: 0.58),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? navy : navy.withValues(alpha: 0.64),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(bool isEditing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE7EDF5))),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: navy.withValues(alpha: 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
              label: Text(
                isEditing ? 'Guardar cambios' : 'Registrar chofer',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Google Sheets import helpers
// ---------------------------------------------------------------------------

class _SheetsDriverEntry {
  const _SheetsDriverEntry({
    required this.id,
    required this.name,
    required this.phone,
  });
  final String id;
  final String name;
  final String phone;
}

class _SheetsImportDialog extends StatefulWidget {
  const _SheetsImportDialog({
    required this.entries,
    required this.existingIds,
    required this.defaultOperation,
    required this.onImport,
  });

  final List<_SheetsDriverEntry> entries;
  final Set<String> existingIds;
  final String defaultOperation;
  final Future<void> Function(List<Driver> selected) onImport;

  @override
  State<_SheetsImportDialog> createState() => _SheetsImportDialogState();
}

class _SheetsImportDialogState extends State<_SheetsImportDialog> {
  late final Set<int> _selected;
  final _clientCtrl = TextEditingController();
  String _operation = 'Inspección';
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _operation = widget.defaultOperation;
    // Pre-seleccionar los que no existen todavía
    _selected = {
      for (var i = 0; i < widget.entries.length; i++)
        if (!widget.existingIds.contains(widget.entries[i].id)) i,
    };
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.table_chart_outlined, color: Color(0xFF1B7F4A)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Importar desde Sheets')),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cliente
            TextField(
              controller: _clientCtrl,
              decoration: const InputDecoration(
                labelText: 'Cliente (opcional)',
                hintText: 'Ej: TRANSTEINER',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.business_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            // Operación
            DropdownButtonFormField<String>(
              initialValue: _operation,
              decoration: const InputDecoration(
                labelText: 'Operación',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.construction_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Inspección', child: Text('Inspección')),
                DropdownMenuItem(value: 'Colocación', child: Text('Colocación')),
              ],
              onChanged: (v) => setState(() => _operation = v ?? _operation),
            ),
            const SizedBox(height: 10),
            // Contador
            Text(
              '${_selected.length} de ${widget.entries.length} seleccionados',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            // Lista de choferes
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.entries.length,
                itemBuilder: (ctx, i) {
                  final entry = widget.entries[i];
                  final alreadyExists = widget.existingIds.contains(entry.id);
                  final isChecked = _selected.contains(i);
                  return CheckboxListTile(
                    dense: true,
                    value: isChecked,
                    enabled: !alreadyExists,
                    onChanged: alreadyExists
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _selected.add(i);
                              } else {
                                _selected.remove(i);
                              }
                            }),
                    title: Text(
                      entry.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: alreadyExists ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      '${entry.id.isNotEmpty ? 'Céd: ${entry.id}' : 'Sin cédula'}${entry.phone.isNotEmpty ? '  •  Tel: ${entry.phone}' : ''}${alreadyExists ? '  •  Ya existe' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: alreadyExists ? Colors.grey : Colors.grey[600],
                      ),
                    ),
                    secondary: CircleAvatar(
                      radius: 16,
                      backgroundColor: alreadyExists
                          ? Colors.grey[200]
                          : const Color(0xFF1B7F4A).withValues(alpha: 0.12),
                      child: Text(
                        entry.name.isNotEmpty ? entry.name[0] : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: alreadyExists ? Colors.grey : const Color(0xFF1B7F4A),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _importing
              ? null
              : () => setState(() {
                    if (_selected.length == widget.entries.where((e) => !widget.existingIds.contains(e.id)).length) {
                      _selected.clear();
                    } else {
                      _selected.addAll([
                        for (var i = 0; i < widget.entries.length; i++)
                          if (!widget.existingIds.contains(widget.entries[i].id)) i,
                      ]);
                    }
                  }),
          child: const Text('Selec. todos'),
        ),
        FilledButton(
          onPressed: _importing || _selected.isEmpty
              ? null
              : () async {
                  setState(() => _importing = true);
                  final toImport = _selected.map((i) {
                    final e = widget.entries[i];
                    return Driver(
                      id: e.id,
                      name: e.name,
                      plate: '',
                      phone: e.phone,
                      client: _clientCtrl.text.trim().toUpperCase(),
                      operation: _operation,
                    );
                  }).toList();
                  await widget.onImport(toImport);
                  if (context.mounted) Navigator.pop(context);
                },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B7F4A)),
          child: _importing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Importar ${_selected.length}'),
        ),
      ],
    );
  }
}
