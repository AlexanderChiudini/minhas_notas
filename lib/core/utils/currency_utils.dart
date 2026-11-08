import 'package:intl/intl.dart';

class CurrencyUtils {
  static final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );

  static String format(int cents) {
    final magnitude = cents.abs();
    final whole = _currency.format(magnitude ~/ 100);
    final decimals = (magnitude % 100).toString().padLeft(2, '0');
    return '${cents < 0 ? '-' : ''}${whole.replaceFirst(RegExp(r',00$'), ',$decimals')}';
  }

  static String editable(int cents) =>
      '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  /// Accepts Brazilian grouping and either decimal separator on mobile keyboards.
  /// Conversion uses integers only; extra decimal places are never rounded.
  static int? parse(String input) {
    var value = input.trim().replaceFirst(RegExp(r'^R\$\s*'), '');
    if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(value)) {
      value = value.replaceAll('.', ',');
    }
    if (!RegExp(r'^(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,\d{1,2})?$')
        .hasMatch(value)) {
      return null;
    }
    final parts = value.replaceAll('.', '').split(',');
    final whole = int.tryParse(parts.first);
    if (whole == null || whole > 90071992547409) return null;
    final decimal = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(2, '0'));
    final cents = whole * 100 + decimal;
    return cents > 9007199254740991 ? null : cents;
  }
}
