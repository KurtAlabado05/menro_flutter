import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../models/report_model.dart';
import '../../models/project_model.dart';
import '../report/report_details_screen.dart';
import '../project/project_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isLoading = false;
  List<ReportModel> _reports = [];
  List<ProjectModel> _projects = [];
  String _activeTab = 'All';

  final List<String> _tabs = ['All', 'Reports', 'Projects'];

  Future<void> _performSearch(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _reports = [];
        _projects = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Firestore doesn't support full-text search natively,
      // so we fetch recent docs and filter client-side.
      // For production, consider Algolia or Typesense.
      final reportSnap = await _db
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final projectSnap = await _db
          .collection('projects')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _reports = reportSnap.docs
          .map((d) => ReportModel.fromFirestore(d.data(), d.id))
          .where((r) =>
              r.title.toLowerCase().contains(q) ||
              r.description.toLowerCase().contains(q) ||
              r.location.toLowerCase().contains(q))
          .toList();

      _projects = projectSnap.docs
          .map((d) => ProjectModel.fromFirestore(d.data(), d.id))
          .where((p) =>
              p.title.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.location.toLowerCase().contains(q))
          .toList();
    } catch (e) {
      debugPrint('❌ Search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalResults => _reports.length + _projects.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search reports, projects...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: hasQuery
                  ? GestureDetector(
                      onTap: () {
                        _controller.clear();
                        setState(() {
                          _reports = [];
                          _projects = [];
                        });
                      },
                      child: const Icon(Icons.close, color: Colors.white70, size: 18),
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() {}); // rebuild for suffix icon
              if (val.trim().isEmpty) {
                setState(() {
                  _reports = [];
                  _projects = [];
                });
              }
            },
            onSubmitted: _performSearch,
            textInputAction: TextInputAction.search,
          ),
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Tab Filter (only when results exist) ──────────
          if (hasQuery && !_isLoading && _totalResults > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  ..._tabs.map((tab) {
                    final isSelected = _activeTab == tab;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = tab),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tab,
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
                  }),
                  const Spacer(),
                  Text(
                    '$_totalResults result${_totalResults == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),

          // ── Body ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : !hasQuery
                    ? _EmptyPrompt()
                    : _totalResults == 0
                        ? _NoResults(query: _controller.text)
                        : _SearchResults(
                            reports: _activeTab == 'Projects' ? [] : _reports,
                            projects: _activeTab == 'Reports' ? [] : _projects,
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Empty Prompt ─────────────────────────────────────────────────
class _EmptyPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Search MENRO Baliwag',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find reports, projects, and locations',
            style: TextStyle(fontSize: 13, color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}

// ── No Results ───────────────────────────────────────────────────
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 34,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different keyword',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ── Search Results ───────────────────────────────────────────────
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.reports, required this.projects});
  final List<ReportModel> reports;
  final List<ProjectModel> projects;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [

        // Reports section
        if (reports.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.assignment_outlined,
            label: 'Reports',
            count: reports.length,
          ),
          const SizedBox(height: 8),
          ...reports.map(
            (r) => _ResultTile(
              icon: Icons.flag_outlined,
              iconColor: Colors.orange,
              title: r.title,
              subtitle: r.location,
              tag: r.status,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportDetailsScreen(reportId: r.id),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Projects section
        if (projects.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.nature_outlined,
            label: 'Projects',
            count: projects.length,
          ),
          const SizedBox(height: 8),
          ...projects.map(
            (p) => _ResultTile(
              icon: Icons.eco_outlined,
              iconColor: AppColors.primary,
              title: p.title,
              subtitle: p.location,
              tag: p.status,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectDetailsScreen(projectId: p.id),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Section Label ────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.count,
  });
  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Result Tile ──────────────────────────────────────────────────
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String tag;
  final VoidCallback onTap;

  Color _tagColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'ongoing':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _tagColor(tag);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            // Text
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
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
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
            // Status tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}