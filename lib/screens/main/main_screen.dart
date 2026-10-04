import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_tokens.dart';
import '../../models/account_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_brand_logos.dart';
import '../dashboard/dashboard_screen.dart';
import '../map/map_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../project/project_list_screen.dart';
import '../submissions/report_submissions_hub_screen.dart';
import '../submissions/tree_cutting_submissions_hub_screen.dart';
import '../virtual_assistant_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  late final List<Widget> _screens;

  static const List<String> _titles = [
    'Dashboard',
    'Environment Report',
    'Community Projects',
    'Tree Cutting Permits',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(scrollController: _scrollController),
      const ReportSubmissionsHubScreen(),
      const ProjectListScreen(),
      const TreeCuttingSubmissionsHubScreen(),
      const ProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final fullName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'User';
    final isOrganization = user?.accountType == AccountType.organization;
    final shortName = isOrganization ? fullName : fullName.split(' ').first;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 120,
          centerTitle: false,
          titleSpacing: AppSpacing.xl - AppSpacing.xs,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppBrandLogos(size: 44, gap: 8),
              const SizedBox(height: 4),
              Text(
                _currentIndex == 0
                    ? '${_greeting()}, $shortName'
                    : _titles[_currentIndex],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                    color: Colors.white.fade(0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Baliwag City, Bulacan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.fade(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: const [_HeaderActions(), SizedBox(width: AppSpacing.sm)],
        ),
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) =>
                  setState(() => _currentIndex = index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Report',
                ),
                NavigationDestination(
                  icon: Icon(Icons.nature_outlined),
                  selectedIcon: Icon(Icons.nature),
                  label: 'Projects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.note_add_outlined),
                  selectedIcon: Icon(Icons.note_add),
                  label: 'Permits',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();

  static final ButtonStyle _style = IconButton.styleFrom(
    foregroundColor: Colors.white,
    minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
  );

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Selector<NotificationProvider, int>(
          selector: (_, p) => p.unreadCount,
          builder: (context, unread, _) => IconButton(
            tooltip: unread > 0
                ? 'Notifications, $unread unread'
                : 'Notifications',
            onPressed: () => _open(context, const NotificationScreen()),
            style: _style,
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 9 ? '9+' : '$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ),
        IconButton(
          tooltip: 'CENRO virtual assistant',
          onPressed: () => _open(context, const VirtualAssistantScreen()),
          style: _style,
          icon: const Icon(Icons.support_agent_outlined),
        ),
        IconButton(
          tooltip: 'Open environmental map',
          onPressed: () => _open(context, const MapScreen()),
          style: _style,
          icon: const Icon(Icons.map_outlined),
        ),
      ],
    );
  }
}
