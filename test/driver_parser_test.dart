import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:control_patio/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extrae fields del texto de WhatsApp', () {
    const text = '''
BASE SUPERVISOR Monitoreo
AGRICOLA: KADIMA
PRODUCTOR: CORPORACION
MARIA ELENA CORMAEL C. LTDA.
PROVEEDOR:STAR LOGISTIC AND TRANSPORT SLAT S.A.
CHOFER: CRUZ CRUZ ALEXIS GABRIEL
CÉDULA:0928818582
CELULAR:0978694970
PLACA:UAA3387
DEPÓSITO:TERCON
DESTINO:DPWORLD POSORJA S.A.
CANT : 01
OPERACION: COLOCACION
''';

    final parsed = parseDriverText(text);

    expect(parsed.name, 'CRUZ CRUZ ALEXIS GABRIEL');
    expect(parsed.plate, 'UAA3387');
    expect(parsed.id, '0928818582');
    expect(parsed.phone, '0978694970');
    expect(parsed.operation, 'Colocación');
  });

  test('detecta inspeccion cuando viene en otra variante', () {
    const text = '''
OPERACION: INSPECCION
CHOFER: LUIS CARREÑO
CEDULA: 0982418095
TELÉFONO: 0994582983
PLACA: GBQ 672
''';

    final parsed = parseDriverText(text);

    expect(parsed.operation, 'Inspección');
    expect(parsed.name, 'LUIS CARREÑO');
    expect(parsed.plate, 'GBQ672');
    expect(parsed.id, '0982418095');
    expect(parsed.phone, '0994582983');
  });

  test('acepta alias de cédula y nombres con mayusculas/minusculas mixtas', () {
    const text = '''
chofer: juan carlos perez
CI: 0987654321
celular: 0999999999
placa: GBB 123
operacion: colocacion
''';

    final parsed = parseDriverText(text);

    expect(parsed.name, 'JUAN CARLOS PEREZ');
    expect(parsed.id, '0987654321');
    expect(parsed.phone, '0999999999');
    expect(parsed.plate, 'GBB123');
    expect(parsed.operation, 'Colocación');
  });

  test('extrae los datos del chofer y deja el cliente para escribirlo manualmente', () {
    const text = '''
CHOFER: juan carlos perez
CI: 0987654321
CELULAR: 0990011223
PLACA: GBB 123
CLIENTE: LOGISTICA ABC S.A.
OPERACION: INSPECCION
''';

    final parsed = parseDriverText(text);

    expect(parsed.name, 'JUAN CARLOS PEREZ');
    expect(parsed.id, '0987654321');
    expect(parsed.phone, '0990011223');
    expect(parsed.plate, 'GBB123');
    expect(parsed.client, isNull);
    expect(parsed.operation, 'Inspección');
  });

  test('detecta varios choferes en un mismo texto OCR', () {
    const text = '''
CHOFER: JUAN CARLOS PEREZ
CI: 0987654321
CELULAR: 0990011223
PLACA: GBB 123
OPERACION: INSPECCION
CHOFER: MARIA FERNANDA LOPEZ
CI: 0987654322
CELULAR: 0990011224
PLACA: GBB 124
OPERACION: COLOCACION
''';

    final parsed = parseDriverTextList(text);

    expect(parsed.length, 2);
    expect(parsed[0].name, 'JUAN CARLOS PEREZ');
    expect(parsed[0].id, '0987654321');
    expect(parsed[0].plate, 'GBB123');
    expect(parsed[0].phone, '0990011223');
    expect(parsed[1].name, 'MARIA FERNANDA LOPEZ');
    expect(parsed[1].id, '0987654322');
    expect(parsed[1].plate, 'GBB124');
    expect(parsed[1].phone, '0990011224');
  });

  test('mantiene un solo chofer cuando el nombre viene partido en dos líneas', () {
    const text = '''
BASE SUPERVISOR Monitoreo
AGRICOLA: KADIMA
PROVEEDOR:STAR LOGISTIC AND TRANSPORT SLAT S.A.
CHOFER: CRUZ CRUZ ALEXIS
GABRIEL
CÉDULA:0928818582
CELULAR:0978694970
PLACA:UAA3387
OPERACION: COLOCACION
''';

    final parsed = parseDriverTextList(text);

    expect(parsed.length, 1);
    expect(parsed[0].name, 'CRUZ CRUZ ALEXIS GABRIEL');
    expect(parsed[0].id, '0928818582');
    expect(parsed[0].phone, '0978694970');
    expect(parsed[0].plate, 'UAA3387');
    expect(parsed[0].operation, 'Colocación');
  });

  test('extrae choferes desde filas de Excel o CSV con cabeceras reales', () {
    final rows = [
      ['CHOFER', 'CÉDULA', 'CELULAR', 'PLACA'],
      ['CRUZ CRUZ ALEXIS GABRIEL', '0928818582', '0978694970', 'UAA3387'],
      ['MARIA FERNANDA LOPEZ', '0987654322', '0990011224', 'GBB124'],
    ];

    final parsed = parseDriverRowsFromTable(rows);

    expect(parsed.length, 2);
    expect(parsed[0].name, 'CRUZ CRUZ ALEXIS GABRIEL');
    expect(parsed[0].id, '0928818582');
    expect(parsed[0].phone, '0978694970');
    expect(parsed[0].plate, 'UAA3387');
    expect(parsed[1].name, 'MARIA FERNANDA LOPEZ');
    expect(parsed[1].id, '0987654322');
    expect(parsed[1].plate, 'GBB124');
  });

  test('lee CSV exportado por Excel con punto y coma', () {
    const csv = 'CHOFER;CÉDULA;CELULAR;PLACA\n'
        'CRUZ CRUZ ALEXIS GABRIEL;0928818582;0978694970;UAA3387\n'
        'MARIA FERNANDA LOPEZ;0987654322;0990011224;GBB124\n';

    final rows = readTableRowsFromFileBytes(utf8.encode(csv), 'csv');
    final parsed = parseDriverRowsFromTable(rows);

    expect(parsed.length, 2);
    expect(parsed[0].name, 'CRUZ CRUZ ALEXIS GABRIEL');
    expect(parsed[0].id, '0928818582');
    expect(parsed[0].phone, '0978694970');
    expect(parsed[0].plate, 'UAA3387');
    expect(parsed[1].name, 'MARIA FERNANDA LOPEZ');
    expect(parsed[1].id, '0987654322');
    expect(parsed[1].plate, 'GBB124');
  });

  test('lee una hoja Excel real con shared strings', () {
    final sharedStrings = [
      'CHOFER',
      'CÉDULA',
      'CELULAR',
      'PLACA',
      'CRUZ CRUZ ALEXIS GABRIEL',
      '0928818582',
      '0978694970',
      'UAA3387',
      'MARIA FERNANDA LOPEZ',
      '0987654322',
      '0990011224',
      'GBB124',
    ];

    final sharedStringsXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="12" uniqueCount="12">
  ${sharedStrings.map((value) => '<si><t>$value</t></si>').join()} 
</sst>
''';

    final sheetXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
      <c r="C1" t="s"><v>2</v></c>
      <c r="D1" t="s"><v>3</v></c>
    </row>
    <row r="2">
      <c r="A2" t="s"><v>4</v></c>
      <c r="B2" t="s"><v>5</v></c>
      <c r="C2" t="s"><v>6</v></c>
      <c r="D2" t="s"><v>7</v></c>
    </row>
    <row r="3">
      <c r="A3" t="s"><v>8</v></c>
      <c r="B3" t="s"><v>9</v></c>
      <c r="C3" t="s"><v>10</v></c>
      <c r="D3" t="s"><v>11</v></c>
    </row>
  </sheetData>
</worksheet>
''';

    final archive = Archive();
    final sharedBytes = utf8.encode(sharedStringsXml);
    final sheetBytes = utf8.encode(sheetXml);
    archive.addFile(ArchiveFile('xl/sharedStrings.xml', sharedBytes.length, sharedBytes));
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetBytes.length, sheetBytes));
    final bytes = ZipEncoder().encode(archive);

    final rows = readTableRowsFromFileBytes(bytes, 'xlsx');
    final parsed = parseDriverRowsFromTable(rows);

    expect(parsed.length, 2);
    expect(parsed[0].name, 'CRUZ CRUZ ALEXIS GABRIEL');
    expect(parsed[0].id, '0928818582');
    expect(parsed[0].phone, '0978694970');
    expect(parsed[0].plate, 'UAA3387');
    expect(parsed[1].name, 'MARIA FERNANDA LOPEZ');
    expect(parsed[1].id, '0987654322');
    expect(parsed[1].plate, 'GBB124');
  });
}
