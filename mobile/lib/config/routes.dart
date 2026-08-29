import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/organization.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/legal_agreement_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/how_to_use_screen.dart';
import '../screens/home/rules_laws_screen.dart';
import '../screens/home/offline_first_aid_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/family/family_group_screen.dart';
import '../screens/family/family_alerts_screen.dart';
import '../screens/volunteer/volunteer_dashboard.dart';
import '../screens/organization/org_dashboard.dart';
import '../screens/organization/manage_volunteers_screen.dart';
import '../screens/organization/orgs_list_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/device_management_screen.dart';
import '../screens/settings/change_password_screen.dart';

import '../screens/more/more_screen.dart';
import '../screens/blood_donation/blood_donation_screen.dart';
import '../screens/announcements/announcements_screen.dart';
import '../screens/support/support_us_screen.dart';
import '../screens/weather/weather_disaster_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    // ── Auth & Legal ──────────────────────────────────────────────────────
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/legal', builder: (_, _) => const RulesLawsScreen()),
    GoRoute(path: '/legal-agreement', builder: (_, _) => const LegalAgreementScreen()),

    // ── Main app (bottom nav shell) ──────────────────────────────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (_, _, child) => ShellScreen(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/organizations', builder: (_, _) => const OrgsListScreen()),
        GoRoute(path: '/family', builder: (_, _) => const FamilyGroupScreen()),
        GoRoute(path: '/family-alerts', builder: (_, _) => const FamilyAlertsScreen()),
        GoRoute(
          path: '/map',
          builder: (_, state) {
            final extra = state.extra;
            OrganizationModel? previewOrg;
            Map<String, double>? targetLoc;
            String? targetTitle;
            String? returnRoute;
            
            if (extra is OrganizationModel) {
              previewOrg = extra;
            } else if (extra is Map<String, double>) {
              targetLoc = extra;
            } else if (extra is Map) {
              final lat = (extra['lat'] as num?)?.toDouble();
              final lng = (extra['lng'] as num?)?.toDouble();
              if (lat != null && lng != null) {
                targetLoc = {'lat': lat, 'lng': lng};
              }
              if (extra['title'] != null) {
                targetTitle = extra['title'].toString();
              }
              if (extra['returnRoute'] != null) {
                returnRoute = extra['returnRoute'].toString();
              }
            }
            return MapScreen(
              previewOrg: previewOrg,
              targetLocation: targetLoc,
              targetTitle: targetTitle,
              returnRoute: returnRoute,
            );
          },
        ),
        GoRoute(path: '/more', builder: (_, _) => const MoreScreen()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/settings/devices', builder: (_, _) => const DeviceManagementScreen()),
      ],
    ),

    // ── Sub-pages ────────────────────────────────────────────────────────
    GoRoute(path: '/blood-donation', builder: (_, _) => const BloodDonationScreen()),
    GoRoute(path: '/first-aid', builder: (_, _) => const OfflineFirstAidScreen()),
    GoRoute(path: '/how-to-use', builder: (_, _) => const HowToUseScreen()),
    GoRoute(path: '/rules-laws', builder: (_, _) => const RulesLawsScreen()),
    GoRoute(path: '/announcements', builder: (_, _) => const AnnouncementsScreen()),
    GoRoute(path: '/support-us', builder: (_, _) => const SupportUsScreen()),
    GoRoute(path: '/change-password', builder: (_, _) => const ChangePasswordScreen()),
    GoRoute(path: '/weather-disaster', builder: (_, _) => const WeatherDisasterScreen()),
    GoRoute(path: '/weather', builder: (_, _) => const WeatherDisasterScreen()),

    // ── Role dashboards ──────────────────────────────────────────────────
    GoRoute(
      path: '/volunteer-dashboard',
      builder: (_, _) => const VolunteerDashboard(),
    ),
    GoRoute(
      path: '/org-dashboard',
      builder: (_, _) => const OrgDashboard(),
    ),
    GoRoute(
      path: '/manage-volunteers',
      builder: (_, _) => const ManageVolunteersScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/mission-map',
      builder: (_, state) {
        final extra = state.extra;
        OrganizationModel? previewOrg;
        Map<String, double>? targetLoc;
        String? targetTitle;
        String? returnRoute;

        if (extra is OrganizationModel) {
          previewOrg = extra;
        } else if (extra is Map<String, double>) {
          targetLoc = extra;
        } else if (extra is Map) {
          final lat = (extra['lat'] as num?)?.toDouble();
          final lng = (extra['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            targetLoc = {'lat': lat, 'lng': lng};
          }
          if (extra['title'] != null) {
            targetTitle = extra['title'].toString();
          }
          if (extra['returnRoute'] != null) {
            returnRoute = extra['returnRoute'].toString();
          }
        }
        return MapScreen(
          previewOrg: previewOrg,
          targetLocation: targetLoc,
          targetTitle: targetTitle,
          isMissionMode: true,
          returnRoute: returnRoute,
        );
      },
    ),
  ],
);
