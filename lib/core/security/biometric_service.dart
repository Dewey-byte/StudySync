import 'package:local_auth/local_auth.dart';

/// Outcome of an unlock attempt, kept as a closed set so the UI can react to
/// "not available" differently from "the user said no".
enum BiometricResult { success, failed, unavailable, notEnrolled, cancelled }

/// Thin wrapper over `local_auth`.
///
/// Biometrics gate access to an already-authenticated session; they never
/// replace the password, so a stolen device cannot be used to change
/// credentials or delete data without knowing it.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.canCheckBiometrics;
    } on LocalAuthException {
      return false;
    }
  }

  Future<List<BiometricType>> enrolledTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on LocalAuthException {
      return const <BiometricType>[];
    }
  }

  Future<BiometricResult> authenticate({
    String reason = 'Unlock StudySync to view your schedule and deadlines',
  }) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        // Survive the app being backgrounded by the system biometric sheet.
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable => BiometricResult.unavailable,
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noCredentialsSet => BiometricResult.notEnrolled,
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.userRequestedFallback ||
        LocalAuthExceptionCode.authInProgress => BiometricResult.cancelled,
        _ => BiometricResult.failed,
      };
    }
  }

  /// Human-readable name for the biometric the device actually offers, used to
  /// label the unlock button honestly instead of guessing "Fingerprint".
  Future<String> describeAvailable() async {
    final types = await enrolledTypes();
    if (types.contains(BiometricType.face)) return 'Face unlock';
    if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    if (types.contains(BiometricType.iris)) return 'Iris unlock';
    return 'Biometric unlock';
  }
}
