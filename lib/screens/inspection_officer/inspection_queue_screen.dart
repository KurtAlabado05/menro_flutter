import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../providers/inspection_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/status_badge.dart';
import 'inspection_detail_screen.dart';

/// Queue of tree-cutting applications and open environmental reports
/// with search, filter, refresh, and priority sorting.
class InspectionQueueScreen extends StatefulWidget {
  const InspectionQueueScreen({super.key});

  @override
  State<InspectionQueueScreen> createState() => _InspectionQueueScreenState();
}

class _InspectionQueueScreenState extends State<InspectionQueueScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // all, reports, permits
  String _sortBy = 'priority'; // priority, submitted

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _filterAndSortQueue(List<dynamic> queue) {
    var filtered = queue;

    // Apply type filter
    if (_filterType == 'reports') {
      filtered = filtered.where((a) => a.sourceCollection == 'reports').toList();
    } else if (_filterType == 'permits') {
      filtered = filtered.where((a) => a.sourceCollection != 'reports').toList();
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (a) =>
                a.applicantName.toLowerCase().contains(q) ||
                a.category.toLowerCase().contains(q) ||
                a.applicationAddress.toLowerCase().contains(q) ||
                (a.raw['title']?.toString().toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    // Apply sorting
    if (_sortBy == 'priority') {
      final priorityOrder = {
        'urgent': 0,
        'high': 1,
        'normal': 2,
        'low': 3,
      };
      filtered.sort((a, b) {
        final aPriority =
            priorityOrder[a.raw['priority']?.toString().toLowerCase()] ?? 2;
        final bPriority =
            priorityOrder[b.raw['priority']?.toString().toLowerCase()] ?? 2;
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        // Secondary sort by submitted date
        return (b.submittedAt ?? DateTime(2000))
            .compareTo(a.submittedAt ?? DateTime(2000));
      });
    } else {
      filtered.sort(
        (a, b) => (b.submittedAt ?? DateTime(2000))
            .compareTo(a.submittedAt ?? DateTime(2000)),
      );
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();

    if (provider.isLoading &&
        provider.queue.isEmpty &&
        provider.error == null) {
      return const SkeletonList(count: 5);
    }

    if (provider.error != null && provider.queue.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Failed to load applications',
        subtitle: provider.error,
      );
    }

    final filteredQueue = _filterAndSortQueue(provider.queue);
    final allCount = provider.queue.length;
    final reportCount = provider.queue
        .where((a) => a.sourceCollection == 'reports')
        .length;
    final permitCount = allCount - reportCount;

    return RefreshIndicator(
      onRefresh: () => Future.delayed(const Duration(seconds: 1)),
      color: AppColors.primary,
      child: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Semantics(
              label: 'Search applications',
              textField: true,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search applications...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? Semantics(
                          label: 'Clear search',
                          button: true,
                          enabled: true,
                          onTap: () {},
                          child: IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
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
          ),

          // Filter & sort bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Semantics(
              label: 'Filter and sort options',
              container: true,
              child: Row(
                children: [
                  // Type filter
                  Semantics(
                    label: _filterType == 'all' ? 'All applications filter, selected' : 'All applications filter',
                    button: true,
                    enabled: true,
                    onTap: () {},
                    child: FilterChip(
                      selected: _filterType == 'all',
                      label: Text('All ($allCount)'),
                      onSelected: (selected) =>
                          setState(() => _filterType = 'all'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    label: _filterType == 'reports' ? 'Reports filter, selected' : 'Reports filter',
                    button: true,
                    enabled: true,
                    onTap: () {},
                    child: FilterChip(
                      selected: _filterType == 'reports',
                      label: Text('Reports ($reportCount)'),
                      onSelected: (selected) =>
                          setState(() => _filterType = 'reports'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Semantics(
                    label: _filterType == 'permits' ? 'Permits filter, selected' : 'Permits filter',
                    button: true,
                    enabled: true,
                    onTap: () {},
                    child: FilterChip(
                      selected: _filterType == 'permits',
                      label: Text('Permits ($permitCount)'),
                      onSelected: (selected) =>
                          setState(() => _filterType = 'permits'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  // Sort dropdown
                  Semantics(
                    label: 'Sort by $_sortBy',
                    button: true,
                    enabled: true,
                    onTap: () {},
                    child: DropdownButton<String>(
                      value: _sortBy,
                      underline: Container(
                        height: 2,
                        color: AppColors.primary,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'priority',
                          child: Text('Priority'),
                        ),
                        DropdownMenuItem(
                          value: 'submitted',
                          child: Text('Recently Submitted'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _sortBy = value ?? 'priority'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sync notice
          if (provider.isUsingCachedData || provider.hasPendingWrites)
            _SyncNotice(
              isCached: provider.isUsingCachedData,
              hasPendingWrites: provider.hasPendingWrites,
            ),

          // Queue list or empty state
          if (filteredQueue.isEmpty)
            Expanded(
              child: EmptyState(
                icon: _searchQuery.isNotEmpty
                    ? Icons.search_off_outlined
                    : Icons.inbox_outlined,
                title: _searchQuery.isNotEmpty
                    ? 'No results for "$_searchQuery"'
                    : 'No inspection cases',
                subtitle: _searchQuery.isNotEmpty
                    ? 'Try a different search term.'
                    : 'Open reports and forwarded tree-cutting applications appear here.',
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: filteredQueue.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final application = filteredQueue[index];
                  final verified =
                      application.documents.where((d) => d.verified).length;
                  final total = application.documents.length;
                  final priority = application.raw['priority']
                          ?.toString()
                          .toLowerCase() ??
                      'normal';

                  final appTitle = application.sourceCollection == 'reports'
                      ? (application.raw['title'] ?? application.category)
                          .toString()
                      : application.applicantName.isEmpty
                      ? 'Unknown Applicant'
                      : application.applicantName;

                  final semanticLabel =
                      '$appTitle, ${application.applicationType.isEmpty ? application.type : application.applicationType}, '
                      'Documents: $verified of $total, Status: ${application.status}, Priority: $priority';

                  return Semantics(
                    label: semanticLabel,
                    button: true,
                    enabled: true,
                    onTap: () {},
                    child: Card(
                      elevation: 0,
                      color: AppColors.cardWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        leading: _getPriorityIndicator(priority),
                        title: Text(
                          appTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                application.sourceCollection == 'reports'
                                    ? '${application.applicantName} · ${application.applicationAddress}'
                                    : application.applicationType.isEmpty
                                    ? application.type
                                    : application.applicationType,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Documents: $verified/$total',
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                        trailing: StatusBadge(status: application.status),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                InspectionDetailScreen(application: application),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _getPriorityIndicator(String priority) {
    final color = switch (priority) {
      'urgent' => Colors.red.shade600,
      'high' => Colors.orange.shade600,
      'normal' => Colors.blue.shade600,
      'low' => Colors.green.shade600,
      _ => AppColors.textGrey,
    };
    return Container(
      width: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  final bool isCached;
  final bool hasPendingWrites;

  const _SyncNotice({required this.isCached, required this.hasPendingWrites});

  @override
  Widget build(BuildContext context) {
    final message = hasPendingWrites
        ? 'Changes are waiting to sync.'
        : 'Showing cached applications while refreshing.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(
            hasPendingWrites
                ? Icons.cloud_upload_outlined
                : Icons.cloud_off_outlined,
            size: 18,
            color: Colors.amber.shade900,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isCached && hasPendingWrites
                  ? '$message Cached data may be shown.'
                  : message,
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
