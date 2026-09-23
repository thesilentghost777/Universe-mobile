import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Form Validation & Payload Constraints Tests', () {
    // Matches backend SendOtpDto regex: ^\+[1-9]\d{6,14}$
    final phoneRegex = RegExp(r'^\+[1-9]\d{6,14}$');

    // Matches backend PASSWORD_REGEX: Min 12 chars, upper, lower, digit, special symbol
    final passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^a-zA-Z\d]).{12,}$');

    // Email standard regex
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    test('International E.164 phone number validation', () {
      expect(phoneRegex.hasMatch('+237690000000'), isTrue);
      expect(phoneRegex.hasMatch('+33612345678'), isTrue);
      expect(phoneRegex.hasMatch('+2250700000000'), isTrue);

      // Invalid phone numbers
      expect(phoneRegex.hasMatch('690000000'), isFalse); // missing +
      expect(phoneRegex.hasMatch('+0123456'), isFalse); // starting with 0 after +
      expect(phoneRegex.hasMatch('+237'), isFalse); // too short
      expect(phoneRegex.hasMatch('+12345678901234567'), isFalse); // too long (>15 digits)
      expect(phoneRegex.hasMatch('+237abc123'), isFalse); // letters
    });

    test('Password complexity rule (minimum 12 chars, upper, lower, digit, symbol)', () {
      expect(passwordRegex.hasMatch('SuperAdminPassword123!'), isTrue);
      expect(passwordRegex.hasMatch('UniVerse@2026Secure'), isTrue);
      expect(passwordRegex.hasMatch('Strong#Passw0rd'), isTrue);

      // Invalid passwords
      expect(passwordRegex.hasMatch('Short1!'), isFalse); // < 12 chars
      expect(passwordRegex.hasMatch('nouppercase123!'), isFalse); // no uppercase
      expect(passwordRegex.hasMatch('NOLOWERCASE123!'), isFalse); // no lowercase
      expect(passwordRegex.hasMatch('NoDigitsSpecial!'), isFalse); // no digit
      expect(passwordRegex.hasMatch('NoSpecialSymbol123'), isFalse); // no special char
    });

    test('OTP 6-digit code validation', () {
      final otpRegex = RegExp(r'^\d{6}$');

      expect(otpRegex.hasMatch('123456'), isTrue);
      expect(otpRegex.hasMatch('000000'), isTrue);
      expect(otpRegex.hasMatch('999999'), isTrue);

      expect(otpRegex.hasMatch('12345'), isFalse); // 5 digits
      expect(otpRegex.hasMatch('1234567'), isFalse); // 7 digits
      expect(otpRegex.hasMatch('12a456'), isFalse); // alphanumeric
    });

    test('Email format validation', () {
      expect(emailRegex.hasMatch('etudiant@univ-yaounde1.cm'), isTrue);
      expect(emailRegex.hasMatch('prof.alain@gmail.com'), isTrue);
      expect(emailRegex.hasMatch('admin@universe.cm'), isTrue);

      expect(emailRegex.hasMatch('invalid-email'), isFalse);
      expect(emailRegex.hasMatch('missing@domain'), isFalse);
      expect(emailRegex.hasMatch('@domain.com'), isFalse);
    });

    test('Signalement text payload length boundaries', () {
      bool isSignalementValide(String sujet, String description) {
        return sujet.trim().length >= 3 &&
            sujet.trim().length <= 200 &&
            description.trim().length >= 10 &&
            description.trim().length <= 2000;
      }

      expect(isSignalementValide('Problème cours', 'Le document audio est inaudible sur le canal.'), isTrue);
      expect(isSignalementValide('No', 'Trop court'), isFalse); // sujet < 3
      expect(isSignalementValide('Titre valide', 'Court'), isFalse); // desc < 10
    });

    test('Video & Book metadata length limits', () {
      bool isVideoValide(String titre, String? description) {
        if (titre.trim().isEmpty || titre.length > 300) return false;
        if (description != null && description.length > 5000) return false;
        return true;
      }

      expect(isVideoValide('Cours 1 : Introduction aux Graphes', 'Description détaillée...'), isTrue);
      expect(isVideoValide('', null), isFalse);
      expect(isVideoValide('A' * 301, null), isFalse);
    });
  });
}
