import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Lightweight wrapper around `geolocator` that:
/// - Checks whether location services are enabled
/// - Requests runtime permission when needed
/// - Exposes a position stream with sensible defaults
class LocationService {
  Future<LocationPermissionState> ensurePermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return LocationPermissionState.serviceDisabled;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) return LocationPermissionState.denied;
      if (permission == LocationPermission.deniedForever) return LocationPermissionState.deniedForever;

      return LocationPermissionState.granted;
    } catch (e) {
      debugPrint('LocationService.ensurePermission failed: $e');
      return LocationPermissionState.error;
    }
  }

  Stream<Position> positionStream({required bool isPremium}) {
    // Premium: tighter updates, Free: a bit less chatty.
    final settings = LocationSettings(
      accuracy: isPremium ? LocationAccuracy.best : LocationAccuracy.high,
      distanceFilter: isPremium ? 1 : 10,
      timeLimit: null,
    );

    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

enum LocationPermissionState {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  error,
}
