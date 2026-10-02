import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../widgets/activity_list_tile.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/section_widgets.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../project/project_details_screen.dart';
import '../../report/report_details_screen.dart';
import '../../tree_cutting_application_screen.dart';
import '../../tree_cutting_permit_details_screen.dart';

class ProfileListSection extends StatefulWidget {
  const ProfileListSection({
    super.key,
    required this.icon,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.isLoading = false,
    this.hasError = false,
    this.headerAction,
  });

  final IconData icon;
  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String emptyTitle;
  final String emptySubtitle;
  final bool isLoading;
  final bool hasError;
  final Widget? headerAction;

  static const int collapsedCount = 5;

  @override
  State<ProfileListSection> createState() => _ProfileListSectionState();
}

class _ProfileListSectionState extends State<ProfileListSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.itemCount;
    final visible = _expanded
        ? total
        : total.clamp(0, ProfileListSection.collapsedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SectionHeader(
                icon: widget.icon,
                label: total > 0 && !widget.isLoading
                    ? '${widget.title} ($total)'
                    : widget.title,
              ),
            ),
            ?widget.headerAction,
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (widget.hasError)
          const _InlineMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load this list',
            subtitle: 'Pull down to refresh and try again.',
          )
        else if (widget.isLoading && total == 0) ...[
          const SkeletonCard(),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonCard(),
        ] else if (total == 0)
          _InlineMessage(
            icon: widget.icon,
            title: widget.emptyTitle,
            subtitle: widget.emptySubtitle,
          )
        else ...[
          for (var i = 0; i < visible; i++) ...[
            widget.itemBuilder(context, i),
            if (i < visible - 1) const SizedBox(height: AppSpacing.sm),
          ],
          if (total > ProfileListSection.collapsedCount)
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show all $total'),
              ),
            ),
        ],
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 28, color: Colors.grey.shade400),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _push(BuildContext context, Widget screen) {
  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
}

class ProfileReportsSection extends StatelessWidget {
  const ProfileReportsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReportProvider>();
    final reports = rp.myReports;
    return ProfileListSection(
      icon: Icons.flag_outlined,
      title: 'My Reports',
      itemCount: reports.length,
      isLoading: rp.isLoading,
      emptyTitle: 'No reports yet',
      emptySubtitle: 'Your submitted reports will appear here.',
      itemBuilder: (context, i) {
        final r = reports[i];
        return ActivityListTile(
          icon: Icons.flag_outlined,
          color: AppColors.statusPending,
          title: r.title,
          subtitle: [r.category, r.location]
              .where((s) => s.trim().isNotEmpty)
              .join(' - '),
          status: r.status,
          onTap: () => _push(context, ReportDetailsScreen(reportId: r.id)),
        );
      },
    );
  }
}

class ProfileProjectsSection extends StatelessWidget {
  const ProfileProjectsSection({super.key});

  Future<void> _toggle(
    BuildContext context,
    ProjectProvider pp,
    String projectId,
    String userId,
    bool isJoined,
  ) async {
    try {
      if (isJoined) {
        await pp.leaveProject(projectId, userId);
      } else {
        await pp.joinProject(projectId, userId);
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          'Could not update your participation. Please try again.',
          type: AppMessageType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProjectProvider>();
    final userId = context.select<AuthProvider, String>(
      (a) => a.user?.id ?? '',
    );
    final projects = pp.myProjects;

    return ProfileListSection(
      icon: Icons.eco_outlined,
      title: 'My Projects',
      itemCount: projects.length,
      isLoading: pp.isLoading,
      emptyTitle: 'No projects yet',
      emptySubtitle: 'Projects you join will appear here.',
      itemBuilder: (context, i) {
        final p = projects[i];
        final isJoined = p.participants.contains(userId);
        return ActivityListTile(
          icon: Icons.eco_outlined,
          color: AppColors.primary,
          title: p.title,
          subtitle: [p.category, p.location]
              .where((s) => s.trim().isNotEmpty)
              .join(' - '),
          status: p.status,
          onTap: () =>
              _push(context, ProjectDetailsScreen(projectId: p.id)),
          action: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(AppSizes.minTapTarget, 36),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: isJoined
                  ? AppColors.textGrey
                  : AppColors.primary,
            ),
            onPressed: () => _toggle(context, pp, p.id, userId, isJoined),
            child: Text(isJoined ? 'Leave' : 'Join'),
          ),
        );
      },
    );
  }
}

class ProfilePermitsSection extends StatefulWidget {
  const ProfilePermitsSection({super.key, required this.userId});

  final String userId;

  @override
  State<ProfilePermitsSection> createState() => _ProfilePermitsSectionState();
}

class _ProfilePermitsSectionState extends State<ProfilePermitsSection> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _open();

  Stream<QuerySnapshot<Map<String, dynamic>>> _open() => FirebaseFirestore
      .instance
      .collection('tree_cutting_permits')
      .where('submittedByUid', isEqualTo: widget.userId)
      .orderBy('submittedAt', descending: true)
      .snapshots();

  @override
  void didUpdateWidget(ProfilePermitsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _stream = _open();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        return ProfileListSection(
          icon: Icons.park_outlined,
          title: 'Tree Cutting Permits',
          itemCount: docs.length,
          isLoading: snapshot.connectionState == ConnectionState.waiting,
          hasError: snapshot.hasError,
          emptyTitle: 'No permits yet',
          emptySubtitle: 'Your tree cutting permit applications will appear here.',
          headerAction: IconButton(
            tooltip: 'Apply for a tree cutting permit',
            onPressed: () =>
                _push(context, const TreeCuttingApplicationScreen()),
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
            ),
          ),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data();
            final species = (data['kindOfTree'] as String?)?.trim() ?? '';
            final status = (data['status'] as String?)?.trim() ?? '';
            final rawCount = data['numberOfTrees'];
            final trees = rawCount is int
                ? rawCount
                : int.tryParse('$rawCount') ?? 0;

            return ActivityListTile(
              icon: Icons.park_outlined,
              color: AppColors.primary,
              title: species.isEmpty ? 'Tree Cutting Application' : species,
              subtitle: trees > 0 ? 'Trees: $trees' : null,
              status: status.isEmpty ? 'pending' : status,
              onTap: () => _push(
                context,
                TreeCuttingPermitDetailsScreen(permitId: doc.id),
              ),
            );
          },
        );
      },
    );
  }
}
