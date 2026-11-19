import 'package:ez_menu/core/logic/csv_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvCodec.parse', () {
    test('simple rows', () {
      expect(CsvCodec.parse('a,b,c\n1,2,3\n'), [
        ['a', 'b', 'c'],
        ['1', '2', '3'],
      ]);
    });
    test('quoted fields with commas and escaped quotes', () {
      expect(CsvCodec.parse('name,desc\n"Fries, large","He said ""hi"""\n'), [
        ['name', 'desc'],
        ['Fries, large', 'He said "hi"'],
      ]);
    });
    test('line break inside quotes', () {
      expect(CsvCodec.parse('"a\nb",c'), [
        ['a\nb', 'c'],
      ]);
    });
    test('BOM and CRLF', () {
      expect(CsvCodec.parse('﻿a,b\r\n1,2\r\n'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });
    test('lone CR line endings', () {
      expect(CsvCodec.parse('a,b\r1,2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });
    test('detects semicolon and tab delimiters', () {
      expect(CsvCodec.parse('a;b\n1;2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(CsvCodec.parse('a\tb\n1\t2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });
    test('a comma inside quotes does not decide the delimiter', () {
      expect(CsvCodec.detectDelimiter('"a,b,c";d\n'), ';');
    });
    test('skips blank lines, keeps empty cells', () {
      expect(CsvCodec.parse('a,b\n\n1,2\n'), hasLength(2));
      expect(CsvCodec.parse('a,,c'), [
        ['a', '', 'c'],
      ]);
      expect(CsvCodec.parse('a,b,'), [
        ['a', 'b', ''],
      ]);
    });
    test('no trailing newline', () {
      expect(CsvCodec.parse('a,b'), [
        ['a', 'b'],
      ]);
    });
    test('empty input', () {
      expect(CsvCodec.parse(''), isEmpty);
      expect(CsvCodec.parse('\n\n'), isEmpty);
    });
    test('Bangla text survives', () {
      expect(CsvCodec.parse('নাম,দাম\nকাচ্চি বিরিয়ানি,৩৮০'), [
        ['নাম', 'দাম'],
        ['কাচ্চি বিরিয়ানি', '৩৮০'],
      ]);
    });
  });

  group('CsvCodec.encode', () {
    test('quotes only when needed', () {
      expect(
        CsvCodec.encode([
          ['a', 'b,c', 'd"e'],
        ]),
        'a,"b,c","d""e"\r\n',
      );
    });
    test('neutralises spreadsheet formulas but keeps plain numbers', () {
      expect(
        CsvCodec.encode([
          ['=SUM(A1)', '-5', '-abc', '@x', '+1'],
        ]),
        "'=SUM(A1),-5,'-abc,'@x,+1\r\n",
      );
    });
    test('BOM is optional', () {
      expect(
        CsvCodec.encode([
          ['a'],
        ], bom: true).startsWith('﻿'),
        isTrue,
      );
      expect(
        CsvCodec.encode([
          ['a'],
        ]).startsWith('﻿'),
        isFalse,
      );
    });
    test('round trip keeps awkward cells', () {
      final rows = [
        ['name', 'note'],
        ['Fries, "large"', 'line1\nline2'],
        [' padded ', ''],
        ['কাচ্চি', '৩৮০'],
      ];
      expect(CsvCodec.parse(CsvCodec.encode(rows)), rows);
    });
  });
}
