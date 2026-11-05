import 'package:flutter_test/flutter_test.dart';

// Adjust this path if your test folder isn't next to lib/.
import 'package:spikescore/scoresheet/remarks_text.dart';

/// Every character is half the text size wide, which keeps the sums easy.
double measure(String s, double size) => s.length * size * 0.5;

void main() {
  // At size 6.0 a character is 3 wide, so 30 wide holds 10 characters.
  final tenWide = List<double>.filled(6, 30.0);

  group('wrapLines', () {
    test('short text stays on one line', () {
      expect(wrapLines('hello', tenWide, 6.0, measure), ['hello']);
    });

    test('wraps at spaces', () {
      expect(
        wrapLines('one two three four', tenWide, 6.0, measure),
        ['one two', 'three four'],
      );
    });

    test('splits a word that is wider than the line', () {
      expect(
        wrapLines('abcdefghijklmnop', tenWide, 6.0, measure),
        ['abcdefghij', 'klmnop'],
      );
    });

    test('keeps blank lines between paragraphs but drops trailing ones', () {
      expect(
        wrapLines('first\n\nsecond\n\n', tenWide, 6.0, measure),
        ['first', '', 'second'],
      );
    });

    test('uses each row\'s own width, and the last width beyond the list', () {
      // Row 1 is narrow (5 characters), later rows are 10.
      final widths = [15.0, 30.0];
      expect(
        wrapLines('aaa bbb ccc ddd eee fff', widths, 6.0, measure),
        ['aaa', 'bbb ccc', 'ddd eee', 'fff'],
      );
    });

    test('ignores carriage returns and extra spaces', () {
      expect(wrapLines('a   b\r\nc', tenWide, 6.0, measure), ['a b', 'c']);
    });
  });

  group('fitRemarks', () {
    test('empty or blank notes give nothing to print', () {
      expect(fitRemarks('', tenWide, measure).lines, isEmpty);
      expect(fitRemarks('  \n ', tenWide, measure).lines, isEmpty);
    });

    test('short notes use the biggest size', () {
      final fit = fitRemarks('Junior #7', tenWide, measure, maxSize: 6.5);
      expect(fit.size, 6.5);
      expect(fit.truncated, isFalse);
    });

    test('longer notes shrink to fit all six rows', () {
      // 60 characters needs more than 6 rows of 10 at size 6, but fits once smaller.
      final text = List.filled(12, 'abcde').join(' ');
      final fit = fitRemarks(text, tenWide, measure, maxSize: 6.5, minSize: 4.0);
      expect(fit.lines.length, lessThanOrEqualTo(6));
      expect(fit.size, lessThan(6.5));
      expect(fit.truncated, isFalse);
      // Nothing was lost: all twelve words are still there.
      expect(fit.lines.join(' ').split(' ').length, 12);
    });

    test('far too much text is cut off with dots, never overflows the rows', () {
      final fit = fitRemarks('word ' * 500, tenWide, measure);
      expect(fit.truncated, isTrue);
      expect(fit.lines.length, 6);
      expect(fit.lines.last.endsWith('...'), isTrue);
      expect(fit.size, 4.0);
      for (final line in fit.lines) {
        expect(measure(line, fit.size), lessThanOrEqualTo(30.0));
      }
    });
  });
}
