import 'package:flutter/services.dart';

/// Formatter for alternate phone numbers
/// - Allows only digits
/// - Inserts a comma after every 10 digits
/// - Supports multiple numbers like: 9876543210,1234567890
class AlternatePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // keep only digits
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);

      // Add comma after every 10 digits, except at the end
      if ((i + 1) % 10 == 0 && i + 1 != digitsOnly.length) {
        buffer.write(',');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
