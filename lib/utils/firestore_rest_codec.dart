import 'package:cloud_firestore/cloud_firestore.dart';

/// Convierte mapas Dart al formato JSON de la API REST de Firestore.
Map<String, dynamic> mapaAFirestoreRestFields(Map<String, dynamic> data) {
  final fields = <String, dynamic>{};
  for (final entry in data.entries) {
    fields[entry.key] = valorAFirestoreRest(entry.value);
  }
  return fields;
}

dynamic valorAFirestoreRest(dynamic value) {
  if (value is FieldValue) {
    return {
      'timestampValue': DateTime.now().toUtc().toIso8601String(),
    };
  }
  if (value == null) return {'nullValue': null};
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is num) {
    if (value is int) return {'integerValue': value.toString()};
    return {'doubleValue': value.toDouble()};
  }
  if (value is GeoPoint) {
    return {
      'geoPointValue': {
        'latitude': value.latitude,
        'longitude': value.longitude,
      },
    };
  }
  if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is List) {
    return {
      'arrayValue': {
        'values': value.map(valorAFirestoreRest).toList(),
      },
    };
  }
  if (value is Map) {
    final nested = <String, dynamic>{};
    for (final e in value.entries) {
      nested[e.key.toString()] = valorAFirestoreRest(e.value);
    }
    return {'mapValue': {'fields': nested}};
  }
  return {'stringValue': value.toString()};
}

/// Sustituye FieldValue.serverTimestamp() por ISO UTC (REST no lo soporta).
Map<String, dynamic> prepararMapaParaRest(Map<String, dynamic> datos) {
  final out = <String, dynamic>{};
  for (final e in datos.entries) {
    if (e.value is FieldValue) {
      out[e.key] = DateTime.now().toUtc();
    } else if (e.value is Map<String, dynamic>) {
      out[e.key] = prepararMapaParaRest(e.value);
    } else if (e.value is List) {
      out[e.key] = e.value.map((item) {
        if (item is Map<String, dynamic>) return prepararMapaParaRest(item);
        if (item is FieldValue) return DateTime.now().toUtc();
        return item;
      }).toList();
    } else {
      out[e.key] = e.value;
    }
  }
  return out;
}
