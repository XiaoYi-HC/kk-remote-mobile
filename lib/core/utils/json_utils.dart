import 'dart:convert';

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, v) => MapEntry(key.toString(), v));
  return const {};
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

String asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? asStringOrNull(dynamic value) {
  final text = asString(value);
  return text.isEmpty ? null : text;
}

int asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(asString(value)) ?? fallback;
}

int? asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(asString(value)) ?? fallback;
}

bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = asString(value).toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

DateTime? asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString())?.toLocal();
}

Map<String, dynamic> mapFromJsonString(String? json) {
  if (json == null || json.trim().isEmpty) return const {};
  try {
    return asMap(jsonDecode(json));
  } catch (_) {
    return const {};
  }
}

List<dynamic> listFromJsonString(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  try {
    final value = jsonDecode(json);
    return value is List ? value : const [];
  } catch (_) {
    return const [];
  }
}

String encodeJson(Object? value, {bool pretty = false}) {
  try {
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(value)
        : jsonEncode(value);
  } catch (_) {
    return '';
  }
}
