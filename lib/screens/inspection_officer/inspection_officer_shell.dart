import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../widgets/animated_gradient_fab.dart';
import '../../widgets/app_brand_logos.dart';
import '../auth/login_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import 'inspection_dashboard_screen.dart';
import 'inspection_queue_screen.dart';

/// Root shell for the Inspection Officer staff role, parallel to the
/// citizen-facing [MainScreen]. Case Documentation and Tree Identification
/// tabs are added in later phases.
class InspectionOfficerShell extends StatefulWidget {
  const InspectionOfficerShell({super.key});

  @override
  State<InspectionOfficerShell> createState() => _InspectionOfficerShellState();
}

class _InspectionOfficerShellState extends State<InspectionOfficerShell> {
  int _currentIndex = 0;

  late final InspectionProvider _inspectionProvider;

  static const _titles = ['Dashboard', 'Queue', 'Profile'];

  final List<Widget> _screens = const [
    InspectionDashboardScreen(),
    InspectionQueueScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _inspectionProvider = context.read<InspectionProvider>()..start();
  }

  @override
  void dispose() {
    _inspectionProvider.stop();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 104,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppBrandLogos(size: 44, gap: 8),
            const SizedBox(height: 4),
            Text(_titles[_currentIndex]),
          ],
        ),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _currentIndex == 1
          ? AnimatedGradientFAB(
              onPressed: () {
                // TODO: Navigate to new inspection creation flow
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New inspection creation')),
                );
              },
              icon: Icons.add_outlined,
              tooltip: 'Create new inspection',
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
