import 'package:intl/intl.dart';

class Fmt {
  Fmt._();

  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  static final _currencyCompact = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 2);
  static final _pct = NumberFormat('+#,##0.00%;-#,##0.00%');
  static final _pctPlain = NumberFormat('#,##0.00%');
  static final _decimal = NumberFormat('#,##0.00');
  static final _big = NumberFormat('#,##0');

  static String usd(double? v, {bool compact = false}) {
    if (v == null) return '--';
    if (compact && v.abs() >= 1000) return _currencyCompact.format(v);
    return _currency.format(v);
  }

  static String pct(double? v, {bool showSign = true}) {
    if (v == null) return '--';
    return showSign ? _pct.format(v) : _pctPlain.format(v);
  }

  static String ratio(double? v, {int decimals = 2}) {
    if (v == null) return '--';
    return v.toStringAsFixed(decimals);
  }

  static String number(double? v) {
    if (v == null) return '--';
    if (v.abs() >= 1000) return _big.format(v);
    return _decimal.format(v);
  }

  static String hours(double? h) {
    if (h == null) return '--';
    if (h < 1) return '${(h * 60).toStringAsFixed(0)}m';
    if (h < 24) return '${h.toStringAsFixed(1)}h';
    return '${(h / 24).toStringAsFixed(1)}d';
  }

  static String date(DateTime? dt) {
    if (dt == null) return '--';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  static String dateTime(DateTime? dt) {
    if (dt == null) return '--';
    return DateFormat('MMM d · HH:mm').format(dt);
  }

  static String timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String crypto(double? v, {int decimals = 6}) {
    if (v == null) return '--';
    return v.toStringAsFixed(decimals);
  }

  static String fearGreed(int? score) {
    if (score == null) return 'N/A';
    if (score >= 75) return 'Extreme Greed';
    if (score >= 55) return 'Greed';
    if (score >= 45) return 'Neutral';
    if (score >= 25) return 'Fear';
    return 'Extreme Fear';
  }
}
