import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// Point of Interest types
enum POIType {
  hospital,
  police,
  firestation,
  ambulance,
  pharmacy,
  clinic,
}

/// Point of Interest model
class POI {
  final String id;
  final String name;
  final POIType type;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  double? distance; // calculated distance from user location

  POI({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
  });

  /// Calculate distance from a given position
  void calculateDistance(double userLat, double userLng) {
    distance = Geolocator.distanceBetween(
      userLat,
      userLng,
      latitude,
      longitude,
    ) /
        1000; // Convert to km
  }

  /// Get icon/emoji for POI type
  String get typeEmoji {
    switch (type) {
      case POIType.hospital:
        return '🏥';
      case POIType.police:
        return '🚔';
      case POIType.firestation:
        return '🚒';
      case POIType.ambulance:
        return '🚑';
      case POIType.pharmacy:
        return '💊';
      case POIType.clinic:
        return '⚕️';
    }
  }

  String get typeName {
    switch (type) {
      case POIType.hospital:
        return 'Hospital';
      case POIType.police:
        return 'Police';
      case POIType.firestation:
        return 'Fire Station';
      case POIType.ambulance:
        return 'Ambulance';
      case POIType.pharmacy:
        return 'Pharmacy';
      case POIType.clinic:
        return 'Clinic';
    }
  }
}

/// POI Service for fetching nearby emergency services
class POIService {
  static final List<POI> _mockPOIs = [
    // Hospitals
    POI(
      id: 'h1',
      name: 'City General Hospital',
      type: POIType.hospital,
      latitude: 40.7128,
      longitude: -74.0060,
      address: '123 Main St, New York, NY',
      phone: '+1-555-0100',
    ),
    POI(
      id: 'h2',
      name: 'Metropolitan Medical Center',
      type: POIType.hospital,
      latitude: 40.7245,
      longitude: -73.9999,
      address: '456 Park Ave, New York, NY',
      phone: '+1-555-0101',
    ),
    // Police Stations
    POI(
      id: 'p1',
      name: 'Midtown Police Station',
      type: POIType.police,
      latitude: 40.7505,
      longitude: -73.9680,
      address: '789 Police Blvd, New York, NY',
      phone: '+1-555-0102',
    ),
    POI(
      id: 'p2',
      name: 'Downtown Police Precinct',
      type: POIType.police,
      latitude: 40.7126,
      longitude: -74.0066,
      address: '321 Justice Ave, New York, NY',
      phone: '+1-555-0103',
    ),
    // Fire Stations
    POI(
      id: 'f1',
      name: 'Fire Station 42',
      type: POIType.firestation,
      latitude: 40.7489,
      longitude: -73.9680,
      address: '654 Safety St, New York, NY',
      phone: '+1-555-0104',
    ),
    POI(
      id: 'f2',
      name: 'Fire Station 8',
      type: POIType.firestation,
      latitude: 40.7140,
      longitude: -74.0087,
      address: '987 Emergency Lane, New York, NY',
      phone: '+1-555-0105',
    ),
    // Pharmacies
    POI(
      id: 'ph1',
      name: 'Central Pharmacy',
      type: POIType.pharmacy,
      latitude: 40.7156,
      longitude: -74.0023,
      address: '246 Health St, New York, NY',
      phone: '+1-555-0106',
    ),
  ];

  /// Get all nearby POIs within radius (in km)
  static Future<List<POI>> getNearbyPOIs(
    double userLatitude,
    double userLongitude, {
    double radiusKm = 5.0,
  }) async {
    try {
      // In a real app, this would call a backend API (Google Maps, OpenStreetMap, etc.)
      // For now, we use mock data
      final nearby = <POI>[];

      for (final poi in _mockPOIs) {
        poi.calculateDistance(userLatitude, userLongitude);
        if (poi.distance != null && poi.distance! <= radiusKm) {
          nearby.add(poi);
        }
      }

      // Sort by distance
      nearby.sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));

      debugPrint('Found ${nearby.length} nearby POIs within ${radiusKm}km');
      return nearby;
    } catch (e) {
      debugPrint('Error fetching nearby POIs: $e');
      return [];
    }
  }

  /// Get POIs by type
  static Future<List<POI>> getPOIsByType(
    double userLatitude,
    double userLongitude,
    POIType type, {
    double radiusKm = 5.0,
  }) async {
    final allNearby = await getNearbyPOIs(userLatitude, userLongitude,
        radiusKm: radiusKm);
    return allNearby.where((p) => p.type == type).toList();
  }

  /// Get nearest POI of a specific type
  static Future<POI?> getNearestPOI(
    double userLatitude,
    double userLongitude,
    POIType type,
  ) async {
    final pois = _mockPOIs.where((p) => p.type == type).toList();
    if (pois.isEmpty) return null;

    for (final poi in pois) {
      poi.calculateDistance(userLatitude, userLongitude);
    }

    pois.sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));
    return pois.first;
  }

  /// Emergency services (hospitals, police, fire) sorted by distance
  static Future<List<POI>> getEmergencyServices(
    double userLatitude,
    double userLongitude, {
    double radiusKm = 10.0,
  }) async {
    final emergencyTypes = [
      POIType.hospital,
      POIType.police,
      POIType.firestation,
      POIType.ambulance,
    ];

    final emergency = <POI>[];
    for (final type in emergencyTypes) {
      final pois = await getPOIsByType(
        userLatitude,
        userLongitude,
        type,
        radiusKm: radiusKm,
      );
      emergency.addAll(pois);
    }

    emergency.sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));
    return emergency;
  }
}
