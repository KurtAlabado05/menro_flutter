import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/status_config.dart';
import '../../models/report_model.dart';
import '../../providers/feed_provider.dart';
import '../../providers/report_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String reportId;
  const ReportDetailsScreen({super.key, required this.reportId});

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadReportById(widget.reportId);
    });
  }

  Future<void> _refresh() async {
    await context.read<ReportProvider>().loadReportById(widget.reportId);
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _shareReport(String title, String location) {
    final text = 'Check out this report: "$title" located at $location';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report link copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Report Details')),
      body: Consumer<ReportProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!provider.isLoading && provider.selectedReport == null) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Report Not Found',
              subtitle: provider.error ?? 'Failed to load report details.',
              actionLabel: 'Retry',
              onAction: _refresh,
            );
          }

          final report = provider.selectedReport!;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Photo Evidence at the Top
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: report.imageUrl != null
                        ? Image.network(
                            report.imageUrl!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 220,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                _buildImagePlaceholder(),
                          )
                        : _buildImagePlaceholder(),
                  ),
                  const SizedBox(height: 16),

                  // 2. Header Information Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(status: report.status, showIcon: true),
                            const Spacer(),
                            IconButton(
                              onPressed: () =>
                                  _shareReport(report.title, report.location),
                              icon: const Icon(Icons.share_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 16,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                report.submittedByName,
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _timeAgo(report.submittedAt),
                              style: const TextStyle(color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Location & Category Breakdown Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.category_outlined,
                          'Category',
                          report.category,
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.location_on_outlined,
                          'Full Address',
                          report.location,
                        ),
                        if (report.barangay != null &&
                            report.barangay!.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.home_work_outlined,
                            'Barangay',
                            report.barangay!,
                          ),
                        ],
                        if (report.sitio != null &&
                            report.sitio!.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.add_road_outlined,
                            'Street Name',
                            report.sitio!,
                          ),
                        ],
                        if (report.landmark != null &&
                            report.landmark!.isNotEmpty) ...[
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.apartment_outlined,
                            'Nearest Landmark',
                            report.landmark!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Description Text
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Map Location Module
                  const Text(
                    'Map Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FlutterMap(
                        options: MapOptions(
                          center: LatLng(
                            report.latitude ?? 14.9545,
                            report.longitude ?? 120.9038,
                          ),
                          zoom: 16.0,
                          interactiveFlags: InteractiveFlag.none,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.yourapp',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  report.latitude ?? 14.9545,
                                  report.longitude ?? 120.9038,
                                ),
                                width: 40,
                                height: 40,
                                builder: (ctx) => const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 6. Enhanced Status Timeline Container
                  const Text(
                    'Status Timeline',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: report.statusHistory.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No progression status history recorded.',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              ...report.statusHistory.reversed
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    final index = entry.key;
                                    final update = entry.value;
                                    final isLatest = index == 0;
                                    final isLast =
                                        index ==
                                        report.statusHistory.length - 1;
                                    return _buildTimelineTile(
                                      update,
                                      isLatest: isLatest,
                                      isLast: isLast,
                                    );
                                  }),
                            ],
                          ),
                  ),
                  const SizedBox(height: 32),

                  // 7. Bottom Interactivity Action Controls
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final newCount = await provider.toggleUpvoteReport(
                              report.id,
                            );
                            if (mounted) {
                              context.read<FeedProvider>().syncReportLike(
                                report.id,
                                newCount,
                                isLiked: provider.hasUpvoted(report.id),
                              );
                            }
                          },
                          icon: Icon(
                            provider.hasUpvoted(report.id)
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                          ),
                          label: Text(
                            provider.hasUpvoted(report.id)
                                ? 'Upvoted'
                                : 'Upvote',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _shareReport(report.title, report.location),
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text('Photo Evidence', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTile(
    ReportStatusUpdate update, {
    required bool isLatest,
    required bool isLast,
  }) {
    final config = StatusConfig.fromStatus(update.status);
    final color = config.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 3),
            Container(
              width: isLatest ? 16 : 12,
              height: isLatest ? 16 : 12,
              decoration: BoxDecoration(
                color: isLatest ? color : color.withOpacity(0.55),
                shape: BoxShape.circle,
                border: isLatest
                    ? Border.all(
                        color: color.withOpacity(0.25),
                        width: 3.5,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      )
                    : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 54,
                color: isLatest ? color.withOpacity(0.3) : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      config.label.toUpperCase(),
                      style: TextStyle(
                        fontWeight: isLatest
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isLatest ? color : Colors.grey[600],
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      '${update.timestamp.hour}:${update.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isLatest ? Colors.grey[800] : Colors.grey[400],
                        fontWeight: isLatest
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  update.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLatest ? Colors.black87 : Colors.grey[600],
                    fontWeight: isLatest ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (update.updatedBy != null)
                      Text(
                        'By ${update.updatedBy}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isLatest ? Colors.grey[700] : Colors.grey[450],
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      '${update.timestamp.day}/${update.timestamp.month}/${update.timestamp.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isLatest ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
