import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/customer/presentation/customer_shell.dart';
import '../../features/customer/presentation/branch_screen.dart';
import '../../features/customer/presentation/home_screen.dart';
import '../../features/customer/presentation/profile_screen.dart';
import '../../features/customer/presentation/subscription_screen.dart';
import '../../features/customer/presentation/wallet_screen.dart';
import '../../features/customer/presentation/providers/customer_providers.dart';
import '../../features/owner/presentation/customers_screen.dart';
import '../../features/owner/presentation/dashboard_screen.dart';
import '../../features/owner/presentation/fraud_screen.dart';
import '../../features/owner/presentation/transactions_screen.dart';
import '../../features/staff/presentation/add_subscription_screen.dart';
import '../../features/staff/presentation/amount_entry_screen.dart';
import '../../features/staff/presentation/confirm_screen.dart';
import '../../features/staff/presentation/customer_card_screen.dart';
import '../../features/staff/presentation/scanner_screen.dart';
import '../../features/staff/presentation/staff_profile_screen.dart';
import '../../features/staff/presentation/staff_route_models.dart';
import '../../features/staff/presentation/success_screen.dart';
import '../../features/staff/presentation/unified_staff_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final listen = Env.hasSupabase ? ref.watch(authRefreshProvider) : null;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: listen,
    redirect: (context, state) {
      if (!Env.hasSupabase) return null;
      var loc = state.matchedLocation;

      if (loc.startsWith('/owner/')) {
        if (loc == '/owner/login') {
          return '/auth/phone';
        }
        final rest = loc.substring('/owner/'.length);
        return '/staff/$rest';
      }

      if (loc.startsWith('/staff/app/')) {
        return loc.replaceFirst('/staff/app/', '/staff/');
      }
      if (loc == '/staff/app') {
        return '/staff/scanner';
      }
      if (loc.startsWith('/staff/m/')) {
        return loc.replaceFirst('/staff/m/', '/staff/');
      }
      if (loc == '/staff/m') {
        return '/staff/scanner';
      }

      if (loc.startsWith('/staff/')) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return '/auth/phone';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/phone',
        name: 'auth-phone',
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'auth-otp',
        // Avoid RTL slide + stacked routes on iOS (torn screen: OTP left, phone right).
        pageBuilder: (context, state) {
          final phone = state.extra as String? ?? '';
          return NoTransitionPage<void>(
            key: state.pageKey,
            name: state.name,
            child: OtpScreen(phone: phone),
          );
        },
      ),
      GoRoute(
        path: '/customer',
        redirect: (context, state) => '/customer/home',
      ),
      GoRoute(
        path: '/customer/history',
        redirect: (context, state) => '/customer/home',
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CustomerShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customer/home',
                name: 'customer-home',
                builder: (context, state) => const CustomerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customer/subscription',
                name: 'customer-subscription',
                builder: (context, state) => const SubscriptionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customer/profile',
                name: 'customer-profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/customer/branch',
        name: 'customer-branch',
        builder: (context, state) => const BranchScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/customer/wallet',
        name: 'customer-wallet',
        builder: (context, state) => const CustomerWalletScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return UnifiedStaffShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff/scanner',
                name: 'staff-scanner',
                builder: (context, state) => const StaffScannerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff/transactions',
                name: 'staff-transactions',
                builder: (context, state) => const OwnerTransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff/dashboard',
                name: 'staff-dashboard',
                builder: (context, state) => const OwnerDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff/customers',
                name: 'staff-customers',
                builder: (context, state) => const OwnerCustomersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff/profile',
                name: 'staff-profile',
                builder: (context, state) => const StaffProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/staff/fraud',
        name: 'staff-fraud',
        builder: (context, state) => const OwnerFraudScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/staff/customer-card',
        name: 'staff-customer-card',
        builder: (context, state) => const StaffCustomerCardScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/staff/amount-entry',
        name: 'staff-amount-entry',
        builder: (context, state) => const StaffAmountEntryScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/staff/confirm',
        name: 'staff-confirm',
        builder: (context, state) => const StaffConfirmScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/staff/success',
        name: 'staff-success',
        builder: (context, state) {
          final extra = state.extra as StaffSuccessPayload?;
          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('Missing success payload')),
            );
          }
          return StaffSuccessScreen(payload: extra);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/staff/add-subscription',
        name: 'staff-add-subscription',
        builder: (context, state) => const StaffAddSubscriptionScreen(),
      ),
    ],
  );
});
