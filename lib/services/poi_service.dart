import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class POIService {
  // User-Agent header required by Nominatim/Overpass usage policy
  static const _userAgent = 'SilentSOS/1.0 (dev@example.com)';

  /// Reverse geocode using Nominatim to get nearest settlement/locality name.
  /// Returns a short string like "Bengaluru, India" or empty string on failure.
  static Future<String> nearestCivilization(double lat, double lon) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=10&addressdetails=1');
      final res = await http.get(uri, headers: {'User-Agent': _userAgent});
      if (res.statusCode != 200) return '';
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final address = map['address'] as Map<String, dynamic>?;
      if (address == null) return '';
      final parts = <String>[];
      if (address['city'] != null) parts.add(address['city']);
      if (address['town'] != null) parts.add(address['town']);
      if (address['village'] != null) parts.add(address['village']);
      if (parts.isEmpty && address['county'] != null) parts.add(address['county']);
      if (map['display_name'] != null && parts.isEmpty) return (map['display_name'] as String).split(',').take(2).join(',');
      // country
      if (address['country'] != null) parts.add(address['country']);
      return parts.join(', ');
    } catch (e) {
      return '';
    }
  }

  /// Query Overpass API for nearest public transport node (bus_stop, tram_stop, station, stop_position)
  /// Returns a short string like "Bus stop: MG Road (120m)" or empty on failure.
  static Future<String> nearestTransport(double lat, double lon, {int radiusMeters = 1000}) async {
    try {
      // Overpass QL: look for nodes and ways with public_transport=platform/stop_position or highway=bus_stop or railway=station
      final query = '''[out:json][timeout:7];(
  node(around:$radiusMeters,$lat,$lon)[public_transport~"platform|stop_position|stop_area"];
  node(around:$radiusMeters,$lat,$lon)[highway=bus_stop];
  node(around:$radiusMeters,$lat,$lon)[railway=station];
  way(around:$radiusMeters,$lat,$lon)[public_transport~"platform|stop_position|stop_area"];
  way(around:$radiusMeters,$lat,$lon)[highway=bus_stop];
  way(around:$radiusMeters,$lat,$lon)[railway=station];
);
out center; >; out skel qt;''';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final res = await http.post(uri, headers: {'User-Agent': _userAgent, 'Content-Type': 'application/x-www-form-urlencoded'}, body: {'data': query});
      if (res.statusCode != 200) return '';
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = body['elements'] as List<dynamic>?;
      if (elements == null || elements.isEmpty) return '';

      // Find the closest element with a name tag if possible
      double bestDist = double.infinity;
      Map<String, dynamic>? bestEl;
      for (final e in elements) {
        if (e is Map<String, dynamic>) {
          double? elLat;
          double? elLon;
          if (e['lat'] != null && e['lon'] != null) {
            elLat = (e['lat'] as num).toDouble();
            elLon = (e['lon'] as num).toDouble();
          } else if (e['center'] != null) {
            final c = e['center'] as Map<String, dynamic>;
            elLat = (c['lat'] as num).toDouble();
            elLon = (c['lon'] as num).toDouble();
          }
          if (elLat == null || elLon == null) continue;
          final d = _haversineDistance(lat, lon, elLat, elLon);
          if (d < bestDist) {
            bestDist = d;
            bestEl = e;
          }
        }
      }

      if (bestEl == null) return '';
      final tags = bestEl['tags'] as Map<String, dynamic>? ?? {};
      final name = tags['name'] as String? ?? tags['ref'] as String? ?? '';
      final type = (tags['public_transport'] as String?) ?? (tags['highway'] as String?) ?? (tags['railway'] as String?) ?? 'stop';
      final distMeters = (bestDist * 1000).round();
      if (name.isNotEmpty) return '${_labelForType(type)}: $name (${distMeters}m)';
      return '${_labelForType(type)} (${distMeters}m)';
    } catch (e) {
      return '';
    }
  }

  static String _labelForType(String t) {
    final lower = t.toLowerCase();
    if (lower.contains('bus') || lower.contains('highway')) return 'Bus stop';
    if (lower.contains('rail') || lower.contains('station')) return 'Rail station';
    if (lower.contains('platform') || lower.contains('stop')) return 'Platform';
    return 'Transport';
  }

  // Haversine distance in kilometers
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat/2) * sin(dLat/2) + cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180.0);
}
