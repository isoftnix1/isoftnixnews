class Validators {
  Validators._();

  static final RegExp _emailRegex =
      RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');

  static final RegExp passwordPattern = RegExp(
    r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$',
  );

  static final RegExp otpPattern = RegExp(r'^\d{6}$');

  static final RegExp indianMobilePattern = RegExp(r'^[6-9]\d{9}$');

  static String normalizeIndianPhone(String value) {
    var digits = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');

    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    return digits;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter a password';
    }
    if (!passwordPattern.hasMatch(value)) {
      return 'Password must be at least 8 characters with uppercase, lowercase, number, and special character (@\$!%*#?&)';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter the verification code';
    }
    if (!otpPattern.hasMatch(value.trim())) {
      return 'OTP must be exactly 6 digits';
    }
    return null;
  }

  static String? indianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your phone number';
    }
    final normalized = normalizeIndianPhone(value);
    if (!indianMobilePattern.hasMatch(normalized)) {
      return 'Enter a valid 10-digit Indian mobile number (starting with 6–9)';
    }
    return null;
  }
}
