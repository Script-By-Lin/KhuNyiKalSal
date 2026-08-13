import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/organization.dart';
import '../../providers/auth_provider.dart';
import '../../providers/emergency_provider.dart';
import '../../providers/organization_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class MapScreen extends ConsumerStatefulWidget {
  final OrganizationModel? previewOrg;
  final Map<String, double>? targetLocation;

  const MapScreen({super.key, this.previewOrg, this.targetLocation});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapCtrl = MapController();
  LatLng? _userLocation;
  LatLng? _responderLocation;
  bool _locationLoading = true;
  StreamSubscription? _locationSub;

  // Active preview target org (selected by user)
  OrganizationModel? _previewOrg;

  // Real road routing points from OSRM
  List<LatLng> _roadRoutePoints = [];
  String? _lastRouteKey;
  bool _isFetchingRoute = false;

  // Packet transmission pulse animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _previewOrg = widget.previewOrg;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_pulseCtrl);

    _initLocation();
    _listenToWsEvents();
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.previewOrg?.accountId != oldWidget.previewOrg?.accountId) {
      setState(() {
        _previewOrg = widget.previewOrg;
      });
      if (_previewOrg != null) {
        _mapCtrl.move(
          LatLng(_previewOrg!.geoLat, _previewOrg!.geoLng),
          14.0,
        );
      }
    }
  }

  Future<void> _initLocation() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _locationLoading = false;
        });
        _mapCtrl.move(_userLocation!, AppConstants.defaultZoom);
      }

      // Update server with location
      ApiService().updateUserLocation(pos.latitude, pos.longitude);

      // Load nearby orgs
      ref.read(organizationProvider.notifier).loadNearby(
            pos.latitude,
            pos.longitude,
          );
          
      // Automatically route to target location if provided (SOS view)
      if (widget.targetLocation != null && _userLocation != null) {
        _fetchRealRoadRoute(
          _userLocation!,
          LatLng(widget.targetLocation!['lat']!, widget.targetLocation!['lng']!)
        );
        _mapCtrl.move(
          LatLng(widget.targetLocation!['lat']!, widget.targetLocation!['lng']!), 
          13.0
        );
      }

      // Stream location updates
      _locationSub = LocationService.getLocationStream().listen((pos) {
        if (mounted) {
          setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
          ApiService().updateUserLocation(pos.latitude, pos.longitude);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _userLocation = LatLng(AppConstants.defaultLat, AppConstants.defaultLng);
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
          ref.read(emergencyProvider.notifier).loadActive();
          _showSnackBar('✅ Help is on the way! Tracking rescue team...', AppTheme.secondaryGreen);
          break;
        case 'RESPONDER_LOCATION_UPDATED':
          final loc = event['location'];
          if (loc != null && mounted) {
            final lat = (loc['lat'] as num).toDouble();
            final lng = (loc['lng'] as num).toDouble();
            setState(() {
              _responderLocation = LatLng(lat, lng);
            });
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
              '🔄 ${event['message'] ?? 'Searching next rescue organization...'}',
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
              '❌ ${event['message'] ?? 'No responders available'}',
              AppTheme.primaryRed);
          break;
        case 'FAMILY_NOTIFIED':
          _showSnackBar(
              '👨‍👩‍👧 Family notified (${event['contacts_notified']} contacts)',
              Colors.blue);
          break;
      }
    });
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
    _pulseCtrl.dispose();
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
      final type = active.type.toLowerCase();
      if (type == 'fire') {
        final fireOrg = orgs.where((o) {
          final n = o.orgName.toLowerCase();
          return n.contains('fire') || n.contains('station') || n.contains('brigade');
        }).firstOrNull;
        if (fireOrg != null) return fireOrg;
      } else if (type == 'medical') {
        final medOrg = orgs.where((o) {
          final n = o.orgName.toLowerCase();
          return n.contains('hospital') || n.contains('medical') || n.contains('rescue') || n.contains('red cross');
        }).firstOrNull;
        if (medOrg != null) return medOrg;
      }
      return orgs.isNotEmpty ? orgs.first : null;
    }
    return null;
  }

  // Fetch real road lane geometry from OpenStreetMap OSRM Routing API (HTTPS)
  Future<void> _fetchRealRoadRoute(LatLng start, LatLng end) async {
    final routeKey =
        '${start.latitude.toStringAsFixed(3)},${start.longitude.toStringAsFixed(3)}->${end.latitude.toStringAsFixed(3)},${end.longitude.toStringAsFixed(3)}';
    if (_lastRouteKey == routeKey || _isFetchingRoute) return;
    _lastRouteKey = routeKey;
    _isFetchingRoute = true;

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final res = await Dio().get(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      if (res.statusCode == 200 && res.data['routes'] != null && res.data['routes'].isNotEmpty) {
        final coords =
            res.data['routes'][0]['geometry']['coordinates'] as List;
        final points = coords
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        if (mounted) {
          setState(() {
            _roadRoutePoints = points;
            _isFetchingRoute = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback straight line if OSRM is offline or fails
    if (mounted) {
      setState(() {
        _roadRoutePoints = [start, end];
        _isFetchingRoute = false;
      });
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
    try {
      final orgLoc = LatLng(targetOrg.geoLat, targetOrg.geoLng);
      final centerLat = (_userLocation!.latitude + orgLoc.latitude) / 2;
      final centerLng = (_userLocation!.longitude + orgLoc.longitude) / 2;
      _mapCtrl.move(LatLng(centerLat, centerLng), 13.5);
    } catch (_) {}
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
    final LatLng? routeStartPoint;
    final LatLng routeEndPoint;

    if (isSosPending && activeTargetOrg != null) {
      // SOS active: route FROM Org base station TO user emergency location
      routeStartPoint = LatLng(activeTargetOrg.geoLat, activeTargetOrg.geoLng);
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

    if (routeStartPoint != null && activeTargetOrg != null && _lastRouteKey != expectedRouteKey && !_isFetchingRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchRealRoadRoute(routeStartPoint!, routeEndPoint);
        }
      });
    }

    // Only display route line when SOS is active OR preview org is selected
    final bool showRouteLine = (isSosPending || _previewOrg != null) && activeTargetOrg != null;

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
              initialCenter: _userLocation ??
                  LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
              initialZoom: AppConstants.defaultZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.khunyikalsal.app',
              ),

              // ── ROUTE POLYLINE (ONLY SHOW WHEN SOS OR PREVIEWING) ────
              if (showRouteLine && polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: polylinePoints,
                      strokeWidth: 5.5,
                      color: isSosPending
                          ? ((activeEmergency.isAccepted || _responderLocation != null)
                              ? AppTheme.secondaryGreen
                              : AppTheme.primaryRed)
                          : Colors.blue,
                      borderStrokeWidth: 2.5,
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
                      width: 52,
                      height: 52,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.secondaryGreen.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.airport_shuttle, color: Colors.white, size: 24),
                      ),
                    ),

                  // User location marker + SOS Wave Animation
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: isSosPending ? 80 : 36,
                      height: isSosPending ? 80 : 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isSosPending)
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (context, _) {
                                return Container(
                                  width: 30 + (_pulseAnim.value * 50),
                                  height: 30 + (_pulseAnim.value * 50),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primaryRed.withValues(
                                      alpha: 0.5 * (1.0 - _pulseAnim.value),
                                    ),
                                    border: Border.all(
                                      color: AppTheme.primaryRed.withValues(
                                        alpha: 1.0 - _pulseAnim.value,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSosPending ? AppTheme.primaryRed : Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: (isSosPending ? AppTheme.primaryRed : Colors.blue)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: isSosPending
                                ? const Icon(Icons.wifi_tethering,
                                    color: Colors.white, size: 16)
                                : null,
                          ),
                        ],
                      ),
                    ),

                  // Organization markers
                  ...orgsList.map((org) => _orgMarker(org, isTarget: org == activeTargetOrg)),
                ],
              ),
            ],
          ),

          // ── Loading overlay ──────────────────────────────────────────
          if (_locationLoading)
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

          // ── My Location button ───────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 140,
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

          // ── Active Route / Live Responder Status Banner ──────────────
          if (activeTargetOrg != null && (_previewOrg != null || activeEmergency?.isAccepted == true))
            Positioned(
              left: 16,
              bottom: 140,
              child: Row(
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'route_org',
                    backgroundColor: (activeEmergency?.isAccepted == true || _responderLocation != null)
                        ? AppTheme.secondaryGreen
                        : (isSosPending ? AppTheme.primaryRed : Colors.blue),
                    foregroundColor: Colors.white,
                    icon: Icon(_responderLocation != null || activeEmergency?.isAccepted == true
                        ? Icons.airport_shuttle
                        : (isSosPending ? Icons.warning : Icons.alt_route)),
                    label: Text(
                      (activeEmergency?.isAccepted == true || _responderLocation != null)
                          ? 'Rescue Team En Route • ETA: ~6 mins'
                          : (isSosPending
                              ? 'SOS Route: ${activeTargetOrg.orgName.split(' ').first}'
                              : 'Preview: ${activeTargetOrg.orgName.split(' ').first}'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () {
                      if (_responderLocation != null) {
                        _mapCtrl.move(_responderLocation!, 14.5);
                      } else {
                        _zoomToRoute(activeTargetOrg);
                      }
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
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;
        return Container(
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_hospital, color: AppTheme.secondaryGreen),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        org.orgName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '📞 ${org.phoneNumber}',
                        style: const TextStyle(color: AppTheme.subtleGrey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📍 Coverage: ${org.coverageRadiusKm} km'),
                if (org.distanceKm != null)
                  Text(
                    '🏃 ${org.distanceKm!.toStringAsFixed(1)} km away',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.blue),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.alt_route),
                label: const Text('Preview Route on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
    });
  }
}
