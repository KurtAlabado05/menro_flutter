import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/project_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/project_card.dart';

import 'project_details_screen.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_hasLoadedOnce) {
        _hasLoadedOnce = true;
        await _loadProjects();
      }
    });
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    await context.read<ProjectProvider>().loadProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _filterProjects(List<dynamic> projects) {
    if (_searchQuery.isEmpty) return projects;
    final q = _searchQuery.toLowerCase();
    return projects
        .where(
          (p) =>
              p.title.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.location.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q),
        )
        .toList();
  }

  bool _isAdminProject(ProjectModel project) {
    final title = project.title.toLowerCase();
    final category = project.category.toLowerCase();
    return title.contains('clean') ||
        title.contains('tree') ||
        title.contains('reforest') ||
        category.contains('clean') ||
        category.contains('tree') ||
        category.contains('reforest');
  }

  Widget _buildProjectList(
    List<dynamic> projects,
    String? userId,
    ProjectProvider provider, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (projects.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: EmptyState(
                icon: Icons.nature_outlined,
                title: _searchQuery.isNotEmpty
                    ? 'No results for "$_searchQuery"'
                    : emptyTitle,
                subtitle: _searchQuery.isNotEmpty
                    ? 'Try a different search term.'
                    : emptySubtitle,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final isJoined =
            userId != null && project.participants.contains(userId);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProjectCard(
            project: project,
            isJoined: isJoined,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectDetailsScreen(projectId: project.id),
                ),
              );
              _loadProjects();
            },
            onJoin: userId != null && project.status != 'completed'
                ? () {
                    if (isJoined) {
                      provider.leaveProject(project.id, userId);
                    } else {
                      provider.joinProject(project.id, userId);
                    }
                  }
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final isOrg = user?.role == 'organization';

    // Important: This widget should NOT create its own Scaffold/AppBar.
    // It is intended to be displayed inside MainScreen (which already has
    // header + bottom navbar).
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search projects...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primary,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Tab bar with live counts
          Consumer<ProjectProvider>(
            builder: (context, provider, _) {
              final visibleProjects = isOrg
                  ? provider.projects
                  : provider.projects.where(_isAdminProject).toList();
              final active = visibleProjects
                  .where((p) => p.status == 'ongoing')
                  .length;
              final pending = visibleProjects
                  .where((p) => p.status == 'pending')
                  .length;
              final completed = visibleProjects
                  .where((p) => p.status == 'completed')
                  .length;

              return Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textGrey,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Ongoing ($active)'),
                    Tab(text: 'Not Started ($pending)'),
                    Tab(text: 'Done ($completed)'),
                  ],
                ),
              );
            },
          ),

          // Tab content
          Expanded(
            child: Consumer2<ProjectProvider, AuthProvider>(
              builder: (context, provider, auth, _) {
                if (provider.isLoading && provider.projects.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (provider.error != null && provider.projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load projects',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.error ?? 'Unknown error',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadProjects,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final userId = auth.user?.id;
                final visibleProjects = isOrg
                    ? provider.projects
                    : provider.projects.where(_isAdminProject).toList();

                final active = _filterProjects(
                  visibleProjects.where((p) => p.status == 'ongoing').toList(),
                );
                final pending = _filterProjects(
                  visibleProjects.where((p) => p.status == 'pending').toList(),
                );
                final completed = _filterProjects(
                  visibleProjects
                      .where((p) => p.status == 'completed')
                      .toList(),
                );

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadProjects,
                  child: Column(
                    children: [
                      if (!isOrg)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Showing admin-led cleanup and tree planting projects only. Join or cancel participation from the project cards below.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildProjectList(
                              active,
                              userId,
                              provider,
                              emptyTitle: 'No ongoing events',
                              emptySubtitle:
                                  'Ongoing events will appear here once approved.',
                            ),
                            _buildProjectList(
                              pending,
                              userId,
                              provider,
                              emptyTitle: 'No not started events',
                              emptySubtitle:
                                  'Upcoming events will appear here once scheduled.',
                            ),
                            _buildProjectList(
                              completed,
                              userId,
                              provider,
                              emptyTitle: 'No done events',
                              emptySubtitle:
                                  'Finished events will be archived here.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
