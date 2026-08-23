import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts ordinary addresses', () {
      expect(Validators.email('student@university.edu'), isNull);
      expect(Validators.email('first.last+tag@sub.example.co.uk'), isNull);
    });

    test('rejects malformed addresses', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('no-at-sign'), isNotNull);
      expect(Validators.email('trailing@dot.'), isNotNull);
      expect(Validators.email('@nolocal.com'), isNotNull);
      expect(Validators.email('spaces in@example.com'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('accepts a long password with letters and digits', () {
      expect(Validators.password('semester2026plan'), isNull);
    });

    test('rejects passwords that are too short', () {
      expect(Validators.password('short1'), isNotNull);
    });

    test('rejects passwords missing a letter or a digit', () {
      expect(Validators.password('1234567890123'), isNotNull);
      expect(Validators.password('abcdefghijklm'), isNotNull);
    });

    test('rejects an empty password', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password(null), isNotNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('passes only when both entries match', () {
      expect(Validators.confirmPassword('abc123defg', 'abc123defg'), isNull);
      expect(Validators.confirmPassword('abc123defg', 'abc123defh'), isNotNull);
    });
  });

  group('Validators.sanitize', () {
    test('trims and collapses runs of whitespace', () {
      expect(Validators.sanitize('  Research   paper  '), 'Research paper');
      expect(Validators.sanitize('a\t\tb\nc'), 'a b c');
    });

    test('clips to the maximum length', () {
      expect(Validators.sanitize('abcdefghij', maxLength: 4), 'abcd');
    });

    test('returns an empty string for null', () {
      expect(Validators.sanitize(null), '');
    });

    test('leaves values that would be dangerous in raw SQL intact', () {
      // Statements are parameterised, so quotes are data, not syntax; the
      // sanitiser must not silently mangle a legitimate title.
      expect(
        Validators.sanitize("Dean's list report"),
        "Dean's list report",
      );
    });
  });

  group('Validators.sanitizeMultiline', () {
    test('keeps line breaks but normalises spacing', () {
      expect(
        Validators.sanitizeMultiline('  line one   \n  line two  '),
        'line one \n line two',
      );
    });
  });

  group('Validators.requiredText', () {
    test('rejects blank values and accepts real ones', () {
      expect(Validators.requiredText('   ', field: 'Title'), isNotNull);
      expect(Validators.requiredText('Title', field: 'Title'), isNull);
    });
  });
}
