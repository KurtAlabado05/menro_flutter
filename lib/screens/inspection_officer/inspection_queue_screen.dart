import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/inspection_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'inspection_detail_screen.dart';

/// Queue of tree-cutting applications and open environmental reports.
class InspectionQueueScreen extends StatelessWidget {
  const InspectionQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();

    if (provider.isLoading &&
        provider.queue.isEmpty &&
        provider.error == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (provider.error != null && provider.queue.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Failed to load applications',
        subtitle: provider.error,
      );
    }

    final queue = provider.queue;
    if (queue.isEmpty) {
      return Column(
        children: [
          if (provider.isUsingCachedData || provider.hasPendingWrites)
            _SyncNotice(
              isCached: provider.isUsingCachedData,
              hasPendingWrites: provider.hasPendingWrites,
            ),
          const Expanded(
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No inspection cases',
              subtitle:
                  'Open reports and forwarded tree-cutting applications appear here.',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (provider.isUsingCachedData || provider.hasPendingWrites)
          _SyncNotice(
            isCached: provider.isUsingCachedData,
            hasPendingWrites: provider.hasPendingWrites,
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: queue.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final application = queue[index];
              final verified = application.documents
                  .where((d) => d.verified)
                  .length;
              final total = application.documents.length;

              return Card(
                elevation: 0,
                color: AppColors.cardWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    application.sourceCollection == 'reports'
                        ? (application.raw['title'] ?? application.category)
                              .toString()
                        : application.applicantName.isEmpty
                        ? 'Unknown Applicant'
                        : application.applicantName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
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
                        const SizedBox(height: 4),
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
              );
            },
          ),
        ),
      ],
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
