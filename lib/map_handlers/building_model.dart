import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Represents a school building defined by a polygon (ordered list of vertices).
class Building {
  final String id;
  final String name;
  final List<LatLng> points; // Polygon vertices
  final LatLng? centroid; // Optional cached centroid
  final int? level; // Optional floor / level indicator
  final String? colorHex; // Optional display color

  Building({
    required this.id,
    required this.name,
    required this.points,
    this.centroid,
    this.level,
    this.colorHex,
  });

  factory Building.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
  // Accept either 'polygon' or 'polygons' field names
  final List<dynamic> raw = (data['polygon'] as List<dynamic>? ?? data['polygons'] as List<dynamic>? ?? []);
    final List<LatLng> points = [];
    for (final entry in raw) {
      if (entry is GeoPoint) {
        points.add(LatLng(entry.latitude, entry.longitude));
      } else if (entry is Map) {
        final lat = entry['latitude'] ?? entry['lat'];
        final lng = entry['longitude'] ?? entry['lng'];
        if (lat is num && lng is num) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }

    LatLng? centroid;
    if (data['centroid'] is GeoPoint) {
      final c = data['centroid'] as GeoPoint;
      centroid = LatLng(c.latitude, c.longitude);
    } else if (points.length >= 3) {
      centroid = _computeCentroid(points);
    }

    return Building(
      id: doc.id,
      name: (data['name'] as String?) ?? doc.id,
  points: points,
      centroid: centroid,
      level: data['level'] as int?,
      colorHex: data['color'] as String?,
    );
  }

  static LatLng _computeCentroid(List<LatLng> pts) {
    double signedArea = 0.0;
    double cx = 0.0;
    double cy = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final p0 = pts[i];
      final p1 = pts[(i + 1) % pts.length];
      final a = p0.latitude * p1.longitude - p1.latitude * p0.longitude;
      signedArea += a;
      cx += (p0.latitude + p1.latitude) * a;
      cy += (p0.longitude + p1.longitude) * a;
    }
    signedArea *= 0.5;
    if (signedArea.abs() < 1e-12) {
      // Fallback to average
      final avgLat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
      final avgLng = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
      return LatLng(avgLat, avgLng);
    }
    cx /= (6.0 * signedArea);
    cy /= (6.0 * signedArea);
    return LatLng(cx, cy);
  }
}
