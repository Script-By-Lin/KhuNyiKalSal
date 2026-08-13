import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/organization.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/legal_agreement_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/how_to_use_screen.dart';
import '../screens/home/rules_laws_screen.dart';
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

import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/create_org_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    // ── Auth ──────────────────────────────────────────────────────────────
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/legal', builder: (_, _) => const LegalAgreementScreen()),

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
            
            if (extra is OrganizationModel) {
              previewOrg = extra;
            } else if (extra is Map<String, double>) {
              targetLoc = extra;
            } else if (extra is Map) {
              targetLoc = {
                'lat': extra['lat'] as double,
                'lng': extra['lng'] as double,
              };
            }
            return MapScreen(
              previewOrg: previewOrg,
              targetLocation: targetLoc,
            );
          },
        ),
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
    ),

    // ── Sub-pages ────────────────────────────────────────────────────────
    GoRoute(path: '/how-to-use', builder: (_, _) => const HowToUseScreen()),
    GoRoute(path: '/rules-laws', builder: (_, _) => const RulesLawsScreen()),

    // ── Role dashboards ──────────────────────────────────────────────────
    GoRoute(
      path: '/admin-dashboard',
      builder: (_, _) => const AdminDashboard(),
    ),
    GoRoute(
      path: '/admin/create-org',
      builder: (_, _) => const CreateOrgScreen(),
    ),
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
  ],
);
