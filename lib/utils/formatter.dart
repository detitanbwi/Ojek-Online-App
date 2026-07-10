import 'package:flutter/services.dart';

String formatPrice(String price) {
  final intVal = int.tryParse(price.replaceAll('.', ''));
  if (intVal == null) return price;
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return intVal.toString().replaceAllMapped(reg, (Match m) => '${m[1]}.');
}

class ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Remove any non-digits
    final cleanText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final intVal = int.tryParse(cleanText);
    if (intVal == null) return oldValue;

    final formatted = formatPrice(cleanText);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
