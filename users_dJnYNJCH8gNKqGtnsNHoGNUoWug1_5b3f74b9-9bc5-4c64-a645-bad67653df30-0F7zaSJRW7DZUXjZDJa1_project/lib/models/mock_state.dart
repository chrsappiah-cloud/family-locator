import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:family_map/services/location_service.dart';
import 'package:family_map/services/family_service.dart';
import 'package:family_map/services/realtime_location_service.dart';
import 'package:family_map/supabase/supabase_config.dart';

class ChatMessage {
  final String text;
  final DateTime createdAt;
  final bool isMe;

  ChatMessage({
    required this.text,
    required this.createdAt,
    required this.isMe,
  });
}

class LocationItem {
  final String label;
  final Color color;
  final double top;
  final double left;

  LocationItem({
    required this.label,
    required this.color,
    required this.top,
    required this.left,
  });
}

class CockpitViewModel extends ChangeNotifier {
  final LocationService _locationService;
  StreamSubscription<Position>? _positionSub;
  final RealtimeLocationService _realtime;
  StreamSubscription<FamilyLocationSample>? _familySub;
  String? _familyId;
  String? get familyId => _familyId;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Position? _myPosition;
  Position? get myPosition => _myPosition;

  LocationPermissionState _permissionState = LocationPermissionState.denied;
  LocationPermissionState get permissionState => _permissionState;

  Position? _anchor;

  final Map<String, FamilyLocationSample> _latestByUser = {};

  final List<ChatMessage> recentMessages = [
    ChatMessage(text: 'Hey everyone!', createdAt: DateTime.now().subtract(const Duration(minutes: 10)), isMe: false),
    ChatMessage(text: 'Are we still on for dinner?', createdAt: DateTime.now().subtract(const Duration(minutes: 8)), isMe: false),
    ChatMessage(text: 'Yes! See you at 7.', createdAt: DateTime.now().subtract(const Duration(minutes: 5)), isMe: true),
  ];

  final List<LocationItem> locations = [
    LocationItem(label: 'You', color: Colors.cyanAccent, top: 0.5, left: 0.5),
  ];

  CockpitViewModel({LocationService? locationService, RealtimeLocationService? realtime})
      : _locationService = locationService ?? LocationService(),
        _realtime = realtime ?? RealtimeLocationService() {
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      _familyId = await FamilyService.ensureDefaultFamily();
      await _realtime.start(familyId: _familyId!);
      _familySub = _realtime.samples.listen(_onFamilySample, onError: (e) => debugPrint('Realtime samples error: $e'));
    } catch (e) {
      debugPrint('Family bootstrap failed (schema/migrations missing?): $e');
      // App still works in "local-only" mode.
    }
    await _startLocation();
  }

  String get statusLine => _isPremium
      ? 'Premium: live-second tracking & rich visuals'
      : 'Free: periodic updates and basic view';

  void togglePremium() {
    _isPremium = !_isPremium;
    unawaited(_startLocation(restart: true));
    notifyListeners();
  }

  Future<void> requestLocation() async {
    await _startLocation(restart: true);
  }

  Future<void> _startLocation({bool restart = false}) async {
    if (restart) {
      await _positionSub?.cancel();
      _positionSub = null;
    }

    if (_positionSub != null) return;

    final perm = await _locationService.ensurePermission();
    _permissionState = perm;
    notifyListeners();

    if (perm != LocationPermissionState.granted) return;

    _positionSub = _locationService.positionStream(isPremium: _isPremium).listen(
      (pos) {
        _myPosition = pos;
        _anchor ??= pos;
        _updateYouMarker();
        unawaited(_maybePublish(pos));
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Location stream error: $e');
      },
    );
  }

  Future<void> _maybePublish(Position pos) async {
    final fid = _familyId;
    if (fid == null) return;
    try {
      await _realtime.publishMyLocation(
        familyId: fid,
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyM: pos.accuracy,
        headingDeg: pos.heading,
        speedMps: pos.speed,
        recordedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      debugPrint('Failed to publish location: $e');
    }
  }

  void _onFamilySample(FamilyLocationSample sample) {
    // Update latests and re-project markers into our radar panel.
    if (sample.userId.isEmpty) return;
    _latestByUser[sample.userId] = sample;
    _rebuildFamilyMarkers();
    notifyListeners();
  }

  void _rebuildFamilyMarkers() {
    final base = _anchor;
    if (base == null) return;

    // Keep "You" marker as index 0.
    final updated = <LocationItem>[locations.first];

    final others = _latestByUser.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    var colorIndex = 0;
    const palette = [Colors.greenAccent, Colors.orangeAccent, Colors.pinkAccent, Colors.amberAccent, Colors.lightBlueAccent];

    for (final e in others) {
      final userId = e.key;
      final s = e.value;
      if (userId.isEmpty) continue;
      if (userId == SupabaseConfig.auth.currentUser?.id) continue;

      // Project coordinates relative to anchor.
      const spanDegrees = 0.002;
      final dx = (s.longitude - base.longitude) / spanDegrees;
      final dy = (s.latitude - base.latitude) / spanDegrees;
      final left = (0.5 + dx).clamp(0.05, 0.95);
      final top = (0.5 - dy).clamp(0.05, 0.95);

      final color = palette[colorIndex % palette.length];
      colorIndex++;

      final short = userId.length >= 4 ? userId.substring(0, 4).toUpperCase() : userId.toUpperCase();
      updated.add(LocationItem(label: short, color: color, top: top, left: left));
    }

    locations
      ..clear()
      ..addAll(updated);
  }

  void _updateYouMarker() {
    final pos = _myPosition;
    final base = _anchor;
    if (pos == null || base == null) return;

    // Normalize around the first fix so the dot moves meaningfully inside the panel.
    // Roughly: 0.002° lat ≈ 222m. Good for a “mini radar” view.
    const spanDegrees = 0.002;
    final dx = (pos.longitude - base.longitude) / spanDegrees;
    final dy = (pos.latitude - base.latitude) / spanDegrees;

    final left = (0.5 + dx).clamp(0.05, 0.95);
    final top = (0.5 - dy).clamp(0.05, 0.95);

    final youIndex = locations.indexWhere((l) => l.label == 'You');
    if (youIndex == -1) return;

    locations[youIndex] = LocationItem(label: 'You', color: locations[youIndex].color, top: top, left: left);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _familySub?.cancel();
    unawaited(_realtime.dispose());
    super.dispose();
  }
}
