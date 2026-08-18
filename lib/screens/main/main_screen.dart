import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../dashboard/dashboard_screen.dart';
import '../map/map_screen.dart';
import '../project/project_list_screen.dart';
import '../profile/profile_screen.dart';
import '../submissions/report_submissions_hub_screen.dart';
import '../submissions/tree_cutting_submissions_hub_screen.dart';
import '../../providers/notification_provider.dart';
// Import all your root tab screens here
import '../map/map_screen.dart';
import '../profile/profile_screen.dart';
import '../submissions/report_submissions_hub_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isNavbarVisible = true;
  final ScrollController _scrollController = ScrollController();

  final List<Widget> _screens = [];

  static const List<String> _titles = [
    'Dashboard',
    'Environment Report',
    'Community Projects',
    'Tree Cutting Permits', // 🟢 FIXED TYPO: Added missing space
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      DashboardScreen(scrollController: _scrollController),
      const ReportSubmissionsHubScreen(),
      const ProjectListScreen(),
      const TreeCuttingSubmissionsHubScreen(),
      const ProfileScreen(),
    ]);

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_isNavbarVisible) setState(() => _isNavbarVisible = false);
      } else {
        if (!_isNavbarVisible) setState(() => _isNavbarVisible = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'User';
    final theme = Theme.of(context);
    const double navbarHeight = kBottomNavigationBarHeight + 20;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentIndex == 0
                              ? '${_getGreeting()}, ${displayName.split(' ').first} 👋'
                              : _titles[_currentIndex],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.white.withOpacity(0.7),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'San Jose del Monte, Bulacan',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const _HeaderMapIcon(),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
        height: _isNavbarVisible ? navbarHeight : 0,
        // 🟢 WRAPPED IN CLIPRECT TO PREVENT LAYOUT OVERFLOW CRASHES WHEN HIDING
        child: ClipRect(
          child: SizedBox(
            height: navbarHeight,
            child: Wrap(
              children: [
                Consumer<NotificationProvider>(
                  builder: (context, notif, _) {
                    return NavigationBar(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (index) {
                        setState(() => _currentIndex = index);
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          label: 'Dashboard',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.add_circle_outline),
                          label: 'Report',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.nature_outlined),
                          label: 'Projects',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.note_add_outlined),
                          label: 'Permits',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          label: 'Profile',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderMapIcon extends StatelessWidget {
  const _HeaderMapIcon();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MapScreen()),
      ),
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.map_outlined, color: Colors.white, size: 22),
      ),
    );
  }
}
