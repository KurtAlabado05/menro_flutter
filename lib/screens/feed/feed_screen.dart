import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/status_config.dart';
import '../../models/feed_model.dart';
import '../../providers/feed_provider.dart';
import '../../providers/report_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed_card.dart';
import '../map/map_screen.dart';
import '../project/project_details_screen.dart';
import '../report/report_details_screen.dart';

class FeedScreen extends StatefulWidget {
  final ScrollController scrollController;
  const FeedScreen({super.key, required this.scrollController});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<String> _filters = [
    'All',
    'Reports',
    'Projects',
    'Completed',
    'Verified',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSearching = false;
  bool _isSearchLoading = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadFeed();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearchLoading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('feed')
          .orderBy('postedAt', descending: true)
          .limit(200)
          .get();

      final results = snap.docs.map((d) => {'id': d.id, ...d.data()}).where((
        item,
      ) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final description = (item['description'] ?? '')
            .toString()
            .toLowerCase();
        final location = (item['location'] ?? '').toString().toLowerCase();
        final authorName = (item['authorName'] ?? '').toString().toLowerCase();
        return title.contains(q) ||
            description.contains(q) ||
            location.contains(q) ||
            authorName.contains(q);
      }).toList();

      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      debugPrint('❌ Search error: $e');
    } finally {
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedProvider>(
      builder: (context, feed, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feed Updates',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Browse reports and project activity from across the system.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textGrey),
                        ),
                      ],
                    ),
                  ),
                  if (feed.isLoading && feed.feed.isNotEmpty)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isSearching
                              ? AppColors.primary.withOpacity(0.4)
                              : AppColors.primary.withOpacity(0.12),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search reports, projects...',
                          hintStyle: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          suffixIcon: _isSearching
                              ? GestureDetector(
                                  onTap: _clearSearch,
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.textGrey,
                                    size: 18,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                        onTap: () => setState(() => _isSearching = true),
                        onChanged: (val) {
                          setState(() {});
                          if (val.trim().isEmpty) {
                            setState(() => _searchResults = []);
                          } else {
                            _performSearch(val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isSearching) ...[
              const SizedBox(height: 8),
              Expanded(
                child: _isSearchLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _searchController.text.trim().isEmpty
                    ? const _SearchPrompt()
                    : _searchResults.isEmpty
                    ? _NoResults(query: _searchController.text)
                    : _InlineSearchResults(
                        results: _searchResults,
                        onTap: (item) {
                          final type = item['type'] ?? '';
                          final relatedId = item['relatedId'] ?? item['id'];
                          if (type == 'report') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ReportDetailsScreen(reportId: relatedId),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProjectDetailsScreen(projectId: relatedId),
                              ),
                            );
                          }
                        },
                      ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Latest Updates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    if (feed.isLoading && feed.feed.isNotEmpty)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = feed.activeFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => feed.setFilter(filter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => feed.loadFeed(),
                  color: AppColors.primary,
                  child: feed.isLoading && feed.feed.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : feed.feed.isEmpty
                      ? const EmptyState(
                          icon: Icons.rss_feed_outlined,
                          title: 'No updates yet',
                          subtitle:
                              'Reports and project updates will appear here.',
                        )
                      : ListView.separated(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: feed.feed.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = feed.feed[index];
                            return FeedCard(
                              item: item,
                              onLike:
                                  item.type == FeedItemType.report &&
                                      item.relatedId != null
                                  ? () async {
                                      final rp = context.read<ReportProvider>();
                                      final newCount = await rp
                                          .toggleUpvoteReport(item.relatedId!);
                                      feed.syncReportLike(
                                        item.relatedId!,
                                        newCount,
                                        isLiked: rp.hasUpvoted(item.relatedId!),
                                      );
                                    }
                                  : () => feed.toggleLike(item.id),
                              onTap: () {
                                if (item.relatedId != null) {
                                  if (item.type == FeedItemType.report) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReportDetailsScreen(
                                          reportId: item.relatedId!,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProjectDetailsScreen(
                                          projectId: item.relatedId!,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 30,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Search the feed',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Find reports, projects, or locations',
            style: TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 30,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No results found',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Try a different keyword',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _InlineSearchResults extends StatelessWidget {
  const _InlineSearchResults({required this.results, required this.onTap});

  final List<Map<String, dynamic>> results;
  final void Function(Map<String, dynamic>) onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = results[index];
        final type = (item['type'] ?? 'report').toString();
        final title = (item['title'] ?? 'Untitled').toString();
        final desc = (item['description'] ?? '').toString();
        final location = (item['location'] ?? '').toString();
        final author = (item['authorName'] ?? '').toString();
        final status = (item['status'] ?? '').toString();
        final isReport = type == 'report';
        final statusColor = StatusConfig.getColor(status);

        return GestureDetector(
          onTap: () => onTap(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isReport
                        ? Colors.orange.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isReport ? Icons.flag_outlined : Icons.eco_outlined,
                    size: 20,
                    color: isReport ? Colors.orange : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (desc.isNotEmpty)
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              location.isNotEmpty ? location : author,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (status.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
