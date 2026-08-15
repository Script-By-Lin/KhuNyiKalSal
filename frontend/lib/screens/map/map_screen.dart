import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/organization_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class MapScreen extends ConsumerStatefulWidget {
  final OrganizationModel? previewOrg;
  final Map<String, double>? targetLocation;
  final String? targetTitle;
  final bool isMissionMode;
  final String? returnRoute;

  const MapScreen({
    super.key,
    this.previewOrg,
    this.targetLocation,
    this.targetTitle,
    this.isMissionMode = false,
    this.returnRoute,
  });

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();
  bool _isMapReady = false;
  LatLng? _userLocation;
  LatLng? _responderLocation;
  bool _locationLoading = true;
  StreamSubscription? _locationSub;

  // Active preview target org (selected by user)
  OrganizationModel? _previewOrg;

  // Active target location (e.g. from Family SOS Alert / Mission View)
  Map<String, double>? _targetLocation;
  String? _targetTitle;

  // Active accepted responder info
  String? _responderName;
  String? _responderPhone;
  String? _responderRole;

  // Real road routing points from OSRM
  List<LatLng> _roadRoutePoints = [];
  String? _lastRouteKey;
  bool _isFetchingRoute = false;
  Timer? _pollTimer;



  @override
  void initState() {
    super.initState();
    _previewOrg = widget.previewOrg;
    _targetLocation = widget.targetLocation;
    _targetTitle = widget.targetTitle;

    _initLocation();
    _listenToWsEvents();

    // Periodic sync timer while emergency is active to guarantee status & route color updates
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      final emergencies = ref.read(emergencyProvider).value ?? [];
      if (emergencies.isNotEmpty) {
        ref.read(emergencyProvider.notifier).loadActive();
      }
    });
  }

  void _safeMove(LatLng center, double zoom) {
    if (!_isMapReady) return;
    try {
      _mapCtrl.move(center, zoom);
    } catch (_) {}
  }

  void _safeFitBounds(List<LatLng> points) {
    if (!_isMapReady || points.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapCtrl.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 80),
          maxZoom: 15.5,
        ),
      );
    } catch (_) {}
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.previewOrg?.accountId != oldWidget.previewOrg?.accountId) {
      setState(() {
        _previewOrg = widget.previewOrg;
      });
      if (_previewOrg != null) {
        _safeMove(LatLng(_previewOrg!.geoLat, _previewOrg!.geoLng), 14.0);
      }
    }

    if (widget.targetLocation != null &&
        (oldWidget.targetLocation == null ||
            widget.targetLocation!['lat'] != oldWidget.targetLocation!['lat'] ||
            widget.targetLocation!['lng'] != oldWidget.targetLocation!['lng'])) {
      setState(() {
        _targetLocation = widget.targetLocation;
        _targetTitle = widget.targetTitle;
        _lastRouteKey = null;
        _roadRoutePoints = [];
      });
      final targetLatLng = LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!);
      if (_userLocation != null) {
        _fetchRealRoadRoute(_userLocation!, targetLatLng);
      }
      _safeMove(targetLatLng, 14.0);
    }
  }

  Future<void> _initLocation() async {
    // If target location is present (Mission mode), immediately center on target location
    if (_targetLocation != null) {
      _safeMove(LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!), 14.5);
    }

    try {
      final lastPos = await LocationService.getLastKnownLocation();
      if (lastPos != null && mounted) {
        setState(() {
          _userLocation = LatLng(lastPos.latitude, lastPos.longitude);
          _locationLoading = false;
        });
        if (_targetLocation != null) {
          _lastRouteKey = null;
          _fetchRealRoadRoute(
            _userLocation!,
            LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!),
          );
        } else {
          _safeMove(_userLocation!, AppConstants.defaultZoom);
        }
      }
    } catch (_) {}

    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _locationLoading = false;
        });
        if (_targetLocation != null) {
          _lastRouteKey = null;
          _fetchRealRoadRoute(
            _userLocation!,
            LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!),
          );
          _safeFitBounds([_userLocation!, LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!)]);
        } else {
          _safeMove(_userLocation!, AppConstants.defaultZoom);
        }
      }

      // Update server with location
      ApiService().updateUserLocation(pos.latitude, pos.longitude);

      // Load nearby orgs
      ref.read(organizationProvider.notifier).loadNearby(
            pos.latitude,
            pos.longitude,
          );

      // Stream location updates
      _locationSub = LocationService.getLocationStream().listen((pos) {
        if (mounted) {
          final newLoc = LatLng(pos.latitude, pos.longitude);
          final oldLoc = _userLocation;
          setState(() => _userLocation = newLoc);
          ApiService().updateUserLocation(pos.latitude, pos.longitude);

          // Update route if user moved significantly (> 20 meters)
          if (_targetLocation != null && oldLoc != null) {
            final moved = (newLoc.latitude - oldLoc.latitude).abs() > 0.0002 ||
                (newLoc.longitude - oldLoc.longitude).abs() > 0.0002;
            if (moved) {
              _fetchRealRoadRoute(
                newLoc,
                LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!),
              );
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationLoading = false;
        });
      }
    }
  }

  void _listenToWsEvents() {
    final auth = ref.read(authProvider.notifier);
    auth.ws.events.listen((event) {
      if (!mounted) return;
      final eventType = event['event'];
      switch (eventType) {
        case 'VOLUNTEER_ACCEPTED':
        case 'EMERGENCY_ACCEPTED':
        case 'SOS_ACCEPTED':
          final eid = event['emergency_id'] ?? '';
          final orgId = event['assigned_org_id'];
          final rName = event['responder_name'] as String?;
          final rPhone = event['responder_phone'] as String?;
          final rRole = event['responder_role'] as String?;
          final rLoc = event['responder_location'];

          ref.read(emergencyProvider.notifier).markAccepted(eid, assignedOrgId: orgId);
          ref.read(emergencyProvider.notifier).loadActive();
          setState(() {
            if (rName != null) _responderName = rName;
            if (rPhone != null) _responderPhone = rPhone;
            if (rRole != null) _responderRole = rRole;
            if (rLoc != null && rLoc is Map) {
              _responderLocation = LatLng(
                (rLoc['lat'] as num).toDouble(),
                (rLoc['lng'] as num).toDouble(),
              );
            }
            _lastRouteKey = null; // Force route recalculation with green styling
          });
          _showSnackBar('✅ ${rName ?? "Rescue team"} is on the way to your location!', AppTheme.secondaryGreen);
          _reloadCurrentRoute();
          break;
        case 'SOS_ASSIGNED':
          ref.read(emergencyProvider.notifier).loadActive();
          setState(() {
            _lastRouteKey = null;
          });
          _reloadCurrentRoute();
          break;
        case 'RESPONDER_LOCATION_UPDATED':
          final loc = event['location'];
          if (loc != null && mounted) {
            final lat = (loc['lat'] as num).toDouble();
            final lng = (loc['lng'] as num).toDouble();
            final newPos = LatLng(lat, lng);
            setState(() {
              _responderLocation = newPos;
            });
            if (_userLocation != null) {
              _fetchRealRoadRoute(newPos, _userLocation!);
            }
          }
          break;
        case 'EMERGENCY_COMPLETED':
          ref.read(emergencyProvider.notifier).loadActive();
          if (mounted) {
            setState(() {
              _responderLocation = null;
              _roadRoutePoints = [];
              _lastRouteKey = null;
            });
          }
          _showSnackBar('🎉 Rescue mission complete! Patient safely delivered.', AppTheme.secondaryGreen);
          break;
        case 'REROUTE_TRIGGERED':
          ref.read(emergencyProvider.notifier).loadActive();
          if (mounted) {
            setState(() {
              _lastRouteKey = null;
              _roadRoutePoints = [];
            });
          }
          _showSnackBar(
              '${event['message'] ?? 'Searching next rescue organization...'}',
              Colors.orange);
          break;
        case 'SOS_CANCELLED':
          ref.read(emergencyProvider.notifier).loadActive();
          if (mounted) {
            setState(() {
              _previewOrg = null;
              _responderLocation = null;
              _roadRoutePoints = [];
              _lastRouteKey = null;
            });
          }
          _showSnackBar(
              '${event['message'] ?? 'No responders available'}',
              AppTheme.primaryRed);
          break;
        case 'FAMILY_NOTIFIED':
          _showSnackBar(
              'Family notified (${event['contacts_notified']} contacts)',
              Colors.blue);
          break;
      }
    });
  }

  Future<void> _reloadCurrentRoute() async {
    setState(() {
      _lastRouteKey = null;
      _isFetchingRoute = false;
    });

    if (_targetLocation != null && _userLocation != null) {
      final start = _userLocation!;
      final end = LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!);
      await _fetchRealRoadRoute(start, end);
      _safeFitBounds([start, end]);
      return;
    }

    final orgs = ref.read(organizationProvider).value ?? [];
    final activeEmergencies = ref.read(emergencyProvider).value ?? [];
    final active = activeEmergencies.isNotEmpty ? activeEmergencies.first : null;
    final isSosPending = active != null && (active.isPending || active.isAccepted);
    final sosOrg = _findSosTargetOrg(orgs);
    final targetOrg = isSosPending ? sosOrg : _previewOrg;

    if (targetOrg != null) {
      final start = _responderLocation ?? LatLng(targetOrg.geoLat, targetOrg.geoLng);
      final end = _userLocation ?? LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
      await _fetchRealRoadRoute(start, end);
      _zoomToRoute(targetOrg);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  OrganizationModel? _findSosTargetOrg(List<OrganizationModel> orgs) {
    final activeEmergencies = ref.watch(emergencyProvider).value ?? [];
    final active = activeEmergencies.isNotEmpty ? activeEmergencies.first : null;

    if (active != null && (active.isPending || active.isAccepted)) {
      if (active.assignedOrgId != null) {
        final match =
            orgs.where((o) => o.accountId == active.assignedOrgId).firstOrNull;
        if (match != null) return match;
      }
      // If assignedOrgId not yet populated, select nearest organization from user location
      if (orgs.isNotEmpty && _userLocation != null) {
        OrganizationModel? nearest;
        double minD = double.infinity;
        for (final o in orgs) {
          final d = LocationService.calculateDistance(
            _userLocation!.latitude,
            _userLocation!.longitude,
            o.geoLat,
            o.geoLng,
          );
          if (d < minD) {
            minD = d;
            nearest = o;
          }
        }
        return nearest;
      }
    }
    return null;
  }

  // Fetch real road lane geometry from OpenStreetMap OSRM Routing API (HTTPS) with multi-mirror fallback
  Future<void> _fetchRealRoadRoute(LatLng rawStart, LatLng end) async {
    final diffLat = (rawStart.latitude - end.latitude).abs();
    final diffLng = (rawStart.longitude - end.longitude).abs();

    // If victim and responder are very close (< ~40m / in same building), draw clean direct connection
    if (diffLat < 0.0004 && diffLng < 0.0004) {
      if (mounted) {
        setState(() {
          _roadRoutePoints = [rawStart, end];
          _isFetchingRoute = false;
        });
      }
      return;
    }

    final routeKey =
        '${rawStart.latitude.toStringAsFixed(4)},${rawStart.longitude.toStringAsFixed(4)}->${end.latitude.toStringAsFixed(4)},${end.longitude.toStringAsFixed(4)}';
    if (_lastRouteKey == routeKey || _isFetchingRoute) return;
    _lastRouteKey = routeKey;
    _isFetchingRoute = true;

    final mirrors = [
      'https://router.project-osrm.org/route/v1/driving/${rawStart.longitude},${rawStart.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving/${rawStart.longitude},${rawStart.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      'https://router.project-osrm.org/route/v1/foot/${rawStart.longitude},${rawStart.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    ];

    for (final url in mirrors) {
      try {
        final res = await Dio().get(
          url,
          options: Options(
            headers: {'User-Agent': 'KhuNyiKalSal-Emergency/1.0'},
            receiveTimeout: const Duration(seconds: 6),
            sendTimeout: const Duration(seconds: 6),
          ),
        );
        if (res.statusCode == 200 && res.data['routes'] != null && (res.data['routes'] as List).isNotEmpty) {
          final coords = res.data['routes'][0]['geometry']['coordinates'] as List;
          final points = <LatLng>[rawStart];
          for (final c in coords) {
            points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
          }
          points.add(end);

          if (points.length >= 2 && mounted) {
            setState(() {
              _roadRoutePoints = points;
              _isFetchingRoute = false;
            });
            _safeFitBounds(points);
            return;
          }
        }
      } catch (_) {}
    }

    // Fallback if completely offline: direct connect between responder and target
    if (mounted) {
      final fallbackPoints = [rawStart, end];
      setState(() {
        _roadRoutePoints = fallbackPoints;
        _isFetchingRoute = false;
      });
      _safeFitBounds(fallbackPoints);
    }
  }

  // Preview route to a specific organization
  void _previewRouteTo(OrganizationModel targetOrg) {
    if (_userLocation == null) return;
    setState(() {
      _previewOrg = targetOrg;
      _lastRouteKey = null;
      _roadRoutePoints = [];
    });
    _fetchRealRoadRoute(_userLocation!, LatLng(targetOrg.geoLat, targetOrg.geoLng));
    _zoomToRoute(targetOrg);
  }

  // Clear route preview
  void _clearPreview() {
    setState(() {
      _previewOrg = null;
      _roadRoutePoints = [];
      _lastRouteKey = null;
    });
  }

  // Safe camera zoom to target organization route
  void _zoomToRoute(OrganizationModel targetOrg) {
    if (_userLocation == null) return;
    final orgLoc = LatLng(targetOrg.geoLat, targetOrg.geoLng);
    final centerLat = (_userLocation!.latitude + orgLoc.latitude) / 2;
    final centerLng = (_userLocation!.longitude + orgLoc.longitude) / 2;
    _safeMove(LatLng(centerLat, centerLng), 13.5);
  }

  @override
  Widget build(BuildContext context) {
    final orgsAsync = ref.watch(organizationProvider);
    final orgsList = orgsAsync.value ?? [];
    
    final activeEmergencies = ref.watch(emergencyProvider).value ?? [];
    final activeEmergency =
        activeEmergencies.isNotEmpty ? activeEmergencies.first : null;
    final isSosPending = activeEmergency != null && (activeEmergency.isPending || activeEmergency.isAccepted);

    // Target org is SOS assigned org during emergency, or selected preview org when previewing
    final sosOrg = _findSosTargetOrg(orgsList);
    final activeTargetOrg = isSosPending ? sosOrg : _previewOrg;

    // During SOS: route FROM org/responder TO user's emergency location
    // Preview: route FROM user TO org
    // Target location (Family SOS alert): route FROM user TO victim target location
    final LatLng? routeStartPoint;
    final LatLng routeEndPoint;

    if (_targetLocation != null) {
      // Direct navigation to Family SOS / Target victim location
      routeStartPoint = _userLocation;
      routeEndPoint = LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!);
    } else if (isSosPending) {
      // SOS active: route FROM Org base / Responder TO user emergency location
      routeStartPoint = _responderLocation ??
          (activeTargetOrg != null
              ? LatLng(activeTargetOrg.geoLat, activeTargetOrg.geoLng)
              : null);
      routeEndPoint = _userLocation ?? LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    } else if (_previewOrg != null) {
      // Preview: show user TO org
      routeStartPoint = _userLocation;
      routeEndPoint = LatLng(_previewOrg!.geoLat, _previewOrg!.geoLng);
    } else {
      routeStartPoint = _userLocation;
      routeEndPoint = _userLocation ?? LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
    }

    // Trigger route fetch asynchronously when valid start and end exist
    final expectedRouteKey = routeStartPoint != null
        ? '${routeStartPoint.latitude.toStringAsFixed(3)},${routeStartPoint.longitude.toStringAsFixed(3)}->${routeEndPoint.latitude.toStringAsFixed(3)},${routeEndPoint.longitude.toStringAsFixed(3)}'
        : null;

    final bool shouldFetchRoute = _targetLocation != null || isSosPending || _previewOrg != null;

    if (shouldFetchRoute && routeStartPoint != null && _lastRouteKey != expectedRouteKey && !_isFetchingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchRealRoadRoute(routeStartPoint!, routeEndPoint);
        }
      });
    }

    // Display route line when Target Location is active OR SOS is active OR preview org is selected
    final bool showRouteLine = _targetLocation != null || isSosPending || _previewOrg != null;

    final polylinePoints = showRouteLine
        ? (_roadRoutePoints.isNotEmpty
            ? _roadRoutePoints
            : (routeStartPoint != null ? [routeStartPoint, routeEndPoint] : <LatLng>[]))
        : <LatLng>[];

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _targetLocation != null
                  ? LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!)
                  : (_userLocation ??
                      LatLng(AppConstants.defaultLat, AppConstants.defaultLng)),
              initialZoom: _targetLocation != null ? 14.5 : AppConstants.defaultZoom,
              onMapReady: () {
                _isMapReady = true;
                if (_roadRoutePoints.length >= 2) {
                  _safeFitBounds(_roadRoutePoints);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.khunyikalsal.app',
              ),

              // ── ROUTE POLYLINE (ONLY SHOW WHEN SOS OR PREVIEWING) ────
              if (showRouteLine && polylinePoints.isNotEmpty)
                PolylineLayer(
                  key: ValueKey('route_${_targetLocation != null ? "target" : activeEmergency?.status}_${polylinePoints.length}_$_lastRouteKey'),
                  polylines: [
                    // Outer outline / glow
                    Polyline(
                      points: polylinePoints.toList(),
                      strokeWidth: 7.0,
                      color: _targetLocation != null
                          ? const Color(0xFFFF3B30) // High-visibility Emergency Red
                          : (isSosPending
                              ? ((activeEmergency.isAccepted || _responderLocation != null)
                                  ? const Color(0xFF00E676) // Vivid Emerald Green
                                  : AppTheme.primaryRed)
                              : Colors.blue),
                      borderStrokeWidth: 3.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // ── MARKERS & PACKET ANIMATION ─────────────────────────
              MarkerLayer(
                markers: [
                  // Live Responder / Ambulance Marker (Foodpanda / Grab style)
                  if (_responderLocation != null)
                    Marker(
                      point: _responderLocation!,
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [

                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withValues(alpha: 0.6),
                                  blurRadius: 14,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.airport_shuttle, color: Colors.white, size: 26),
                          ),
                        ],
                      ),
                    ),

                  // Family / Victim SOS Target Marker + Pulsing SOS Beacon
                  if (_targetLocation != null)
                    Marker(
                      point: LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!),
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [

                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryRed.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),

                  // User location marker
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: (_targetLocation != null || widget.isMissionMode)
                              ? const Color(0xFF0284C7)
                              : (isSosPending ? AppTheme.primaryRed : Colors.blue),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: ((_targetLocation != null || widget.isMissionMode)
                                      ? const Color(0xFF0284C7)
                                      : (isSosPending ? AppTheme.primaryRed : Colors.blue))
                                  .withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          (_targetLocation != null || widget.isMissionMode)
                              ? Icons.navigation_rounded
                              : (isSosPending ? Icons.wifi_tethering : Icons.person_pin_circle_rounded),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                  // Organization markers
                  ...orgsList.map((org) => _orgMarker(org, isTarget: org == activeTargetOrg)),
                ],
              ),
            ],
          ),

          // ── Loading overlay ──────────────────────────────────────────
          if (_locationLoading && _userLocation == null && _targetLocation == null)
            Container(
              color: Colors.white70,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryRed),
                    SizedBox(height: 16),
                    Text('Getting your location...'),
                  ],
                ),
              ),
            ),

          // ── Mission Mode Top Command Header (Org & Volunteer) ───────
          if (widget.isMissionMode || widget.returnRoute != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF0F172A),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        tooltip: 'Return to Dashboard',
                        onPressed: () {
                          if (widget.returnRoute != null) {
                            context.go(widget.returnRoute!);
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/org-dashboard');
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.targetTitle ?? '🚨 EMERGENCY RESCUE MISSION',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Live Road Route • GPS Tracking Active',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00E676)),
                        ),
                        child: const Text(
                          'MISSION',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Reload / Recalculate Route button ───────────────────────
          if (showRouteLine)
            Positioned(
              right: 16,
              bottom: _targetLocation != null ? 170 : 196,
              child: FloatingActionButton.small(
                heroTag: 'reload_route',
                backgroundColor: Colors.white,
                foregroundColor: (activeEmergency?.isAccepted == true || _responderLocation != null)
                    ? AppTheme.secondaryGreen
                    : AppTheme.primaryRed,
                tooltip: 'Recalculate Route (လမ်းကြောင်း ပြန်ဆွဲမည်)',
                onPressed: () {
                  ref.read(emergencyProvider.notifier).loadActive();
                  _reloadCurrentRoute();
                  _showSnackBar('Recalculating rescue route...', Colors.blue);
                },
                child: const Icon(Icons.refresh),
              ),
            ),

          // ── My Location button ───────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _targetLocation != null ? 120 : 140,
            child: FloatingActionButton.small(
              heroTag: 'locate',
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryRed,
              onPressed: () {
                if (_userLocation != null) {
                  _mapCtrl.move(_userLocation!, AppConstants.defaultZoom);
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // ── Active Target Location (Mission Mode) HUD Card ───────────
          if (_targetLocation != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF0F172A),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFF3B30)),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: Color(0xFFFF3B30), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _targetTitle ?? '🚨 Emergency Target Location',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'GPS: ${_targetLocation!['lat']!.toStringAsFixed(4)}, ${_targetLocation!['lng']!.toStringAsFixed(4)}',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.center_focus_strong_rounded, color: Color(0xFF38BDF8), size: 22),
                            tooltip: 'Center on Target',
                            onPressed: () {
                              _safeMove(LatLng(_targetLocation!['lat']!, _targetLocation!['lng']!), 15.0);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Color(0xFF334155)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                icon: const Icon(Icons.navigation_rounded, color: Color(0xFF00E676), size: 18),
                                label: const Text(
                                  'GOOGLE MAPS GPS',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                                onPressed: () {
                                  final lat = _targetLocation!['lat']!;
                                  final lng = _targetLocation!['lng']!;
                                  final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 38,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF3B30),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: const Text(
                                'RETURN',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                              onPressed: () {
                                if (widget.returnRoute != null) {
                                  context.go(widget.returnRoute!);
                                } else if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  context.go('/org-dashboard');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Active Accepted Responder Card (User View) ───────────────
          if (_targetLocation == null && (activeEmergency?.isAccepted == true || _responderLocation != null))
            Positioned(
              left: 16,
              right: 16,
              bottom: 125,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFF0F172A),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                        ),
                        child: const Icon(Icons.airport_shuttle_rounded, color: Color(0xFF00E676), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _responderName ?? activeTargetOrg?.orgName ?? 'Rescue Team',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    (_responderRole ?? 'DISPATCHED').toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              '📍 Heading to your location • Live GPS',
                              style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((_responderPhone != null && _responderPhone!.isNotEmpty) ||
                          (activeTargetOrg != null && activeTargetOrg.phoneNumber.isNotEmpty)) ...[
                        IconButton(
                          icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF00E676), size: 24),
                          tooltip: 'Call Responder',
                          onPressed: () {
                            final phone = (_responderPhone != null && _responderPhone!.isNotEmpty)
                                ? _responderPhone!
                                : activeTargetOrg!.phoneNumber;
                            launchUrl(Uri.parse('tel:$phone'));
                          },
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.center_focus_strong_rounded, color: Colors.white70, size: 22),
                        tooltip: 'Focus Responder',
                        onPressed: () {
                          if (_responderLocation != null) {
                            _safeMove(_responderLocation!, 15.0);
                          } else if (activeTargetOrg != null) {
                            _zoomToRoute(activeTargetOrg);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Pending SOS or Preview Route Banner ──────────────────────
          if (_targetLocation == null &&
              activeTargetOrg != null &&
              activeEmergency?.isAccepted != true &&
              _responderLocation == null &&
              (_previewOrg != null || isSosPending))
            Positioned(
              left: 16,
              bottom: 140,
              child: Row(
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'route_org',
                    backgroundColor: isSosPending ? AppTheme.primaryRed : Colors.blue,
                    foregroundColor: Colors.white,
                    icon: Icon(isSosPending ? Icons.warning : Icons.alt_route),
                    label: Text(
                      isSosPending
                          ? 'SOS Route: ${activeTargetOrg.orgName.split(' ').first}'
                          : 'Preview: ${activeTargetOrg.orgName.split(' ').first}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () {
                      _zoomToRoute(activeTargetOrg);
                    },
                  ),
                  if (_previewOrg != null && !isSosPending) ...[
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      heroTag: 'clear_route',
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey,
                      tooltip: 'Clear Route Preview',
                      onPressed: _clearPreview,
                      child: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Marker _orgMarker(OrganizationModel org, {bool isTarget = false}) {
    final name = org.orgName.toLowerCase();
    IconData iconData = Icons.local_hospital;
    if (name.contains('fire') || name.contains('station') || name.contains('brigade')) {
      iconData = Icons.local_fire_department;
    } else if (name.contains('police') || name.contains('security')) {
      iconData = Icons.shield;
    }

    return Marker(
      point: LatLng(org.geoLat, org.geoLng),
      width: isTarget ? 50 : 44,
      height: isTarget ? 50 : 44,
      child: GestureDetector(
        onTap: () => _showOrgInfo(org),
        child: Container(
          decoration: BoxDecoration(
            color: isTarget ? AppTheme.primaryRed : AppTheme.secondaryGreen,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: (isTarget ? AppTheme.primaryRed : AppTheme.secondaryGreen)
                    .withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(iconData, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _showOrgInfo(OrganizationModel org) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dividerCol = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondary = isDark ? Colors.white70 : AppTheme.subtleGrey;

    final cat = org.category.toLowerCase();
    IconData orgIcon = Icons.medical_services;
    Color orgColor = AppTheme.secondaryGreen;
    if (cat.contains('fire')) {
      orgIcon = Icons.local_fire_department;
      orgColor = const Color(0xFFFF6B35);
    } else if (cat.contains('volunt') || cat.contains('rescue')) {
      orgIcon = Icons.shield_rounded;
      orgColor = AppTheme.primaryRed;
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;
        final isMm = ref.watch(settingsProvider).locale.languageCode == 'my';

        return Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDark ? const Border(top: BorderSide(color: Color(0xFF334155), width: 1)) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: orgColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(orgIcon, color: orgColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.orgName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 14, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              org.phoneNumber,
                              style: TextStyle(color: textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (org.phoneNumber.isNotEmpty)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.call, color: AppTheme.secondaryGreen, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.15),
                      ),
                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: org.phoneNumber)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: dividerCol, height: 1),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMm
                        ? '📍 လွှမ်းခြုံဧရိယာ: ${org.coverageRadiusKm} km'
                        : '📍 Coverage: ${org.coverageRadiusKm} km',
                    style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
                  ),
                  if (org.distanceKm != null)
                    Text(
                      isMm
                          ? '🏃 ${org.distanceKm!.toStringAsFixed(1)} km အကွာ'
                          : '🏃 ${org.distanceKm!.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.lightBlueAccent : Colors.blue.shade700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route, color: Colors.white, size: 20),
                  label: Text(
                    isMm ? 'မြေပုံပေါ်တွင် လမ်းကြောင်းကြည့်မည်' : 'Preview Route on Map',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _previewRouteTo(org);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
