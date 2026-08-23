/// Input rules shared by forms and repositories.
///
/// The repository re-runs these instead of trusting the widget layer, so a
/// programming mistake in the UI cannot write malformed rows.
abstract final class Validators {
  static final RegExp _email = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  static const int minPasswordLength = 10;
  static const int maxTextLength = 2000;

  static String? name(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please enter your full name.';
    if (trimmed.length < 2) return 'Name is too short.';
    if (trimmed.length > 80) return 'Name must be 80 characters or fewer.';
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please enter your email address.';
    if (trimmed.length > 254) return 'Email address is too long.';
    if (!_email.hasMatch(trimmed)) return 'Enter a valid email address.';
    return null;
  }

  /// Length is the dominant factor in resisting offline guessing, so the rule
  /// favours a longer passphrase over a short one padded with symbols.
  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Please enter a password.';
    if (password.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    if (password.length > 128) return 'Password must be 128 characters or fewer.';
    if (!password.contains(RegExp('[A-Za-z]'))) {
      return 'Include at least one letter.';
    }
    if (!password.contains(RegExp('[0-9]'))) {
      return 'Include at least one number.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? requiredText(String? value, {String field = 'This field'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$field is required.';
    if (trimmed.length > maxTextLength) return '$field is too long.';
    return null;
  }

  static String? optionalText(String? value, {String field = 'This field'}) {
    if ((value ?? '').trim().length > maxTextLength) {
      return '$field is too long.';
    }
    return null;
  }

  /// Collapses whitespace and clips to [maxTextLength].
  ///
  /// Values are always bound as SQL parameters, so this exists to keep records
  /// tidy rather than to defend against injection.
  static String sanitize(String? value, {int maxLength = maxTextLength}) {
    final collapsed = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.length <= maxLength
        ? collapsed
        : collapsed.substring(0, maxLength);
  }

  /// Same as [sanitize] but keeps line breaks, for multi-line notes.
  static String sanitizeMultiline(String? value,
      {int maxLength = maxTextLength}) {
    final trimmed = (value ?? '').trim().replaceAll(RegExp(r'[ \t]+'), ' ');
    return trimmed.length <= maxLength
        ? trimmed
        : trimmed.substring(0, maxLength);
  }
}
