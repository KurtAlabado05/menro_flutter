import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/feed_model.dart';
import '../providers/feed_provider.dart';
import 'status_badge.dart';
import 'comment_section.dart';

class FeedCard extends StatefulWidget {
  final FeedModel item;
  final VoidCallback? onTap;
  final VoidCallback? onLike;

  const FeedCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLike,
  });

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  late bool _isLiked;
  bool _isCommentsExpanded = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
  }

  @override
  void didUpdateWidget(FeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id) {
      _isLiked = widget.item.isLiked;
      _isCommentsExpanded = false;
      _currentImageIndex = 0;
    } else if (widget.item.isLiked != oldWidget.item.isLiked) {
      _isLiked = widget.item.isLiked;
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
    widget.onLike?.call();
  }

  void _toggleComments() {
    setState(() {
      _isCommentsExpanded = !_isCommentsExpanded;
    });
    if (_isCommentsExpanded) {
      context.read<FeedProvider>().loadComments(widget.item.id);
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  // Collect all available images from the item
  List<String> get _allImages {
    final images = <String>[];
    if (widget.item.imageUrls.isNotEmpty) {
      images.addAll(widget.item.imageUrls);
    } else if (widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty) {
      images.add(widget.item.imageUrl!);
    }
    return images;
  }

  Widget _buildImageSection() {
    final images = _allImages;

    // No images — show nothing (no map placeholder)
    if (images.isEmpty) return const SizedBox.shrink();

    // Single image
    if (images.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            images.first,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
              ),
            ),
          ),
        ),
      );
    }

    // Multiple images — PageView with dot indicator
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              child: PageView.builder(
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _currentImageIndex = i),
                itemBuilder: (context, i) {
                  return Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Page count badge top-right
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Dot indicators bottom-center
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentImageIndex == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == i
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReport = widget.item.type == FeedItemType.report;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: widget.onTap,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isReport ? AppColors.statusPending : AppColors.primary,
                    child: Icon(
                      isReport ? Icons.report_outlined : Icons.nature_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.authorName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.item.isVerified)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.statusResolved.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.statusResolved.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 10, color: AppColors.statusResolved),
                              const SizedBox(width: 2),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.statusResolved,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    _timeAgo(widget.item.postedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: widget.item.status != null
                      ? StatusBadge(status: widget.item.status)
                      : null,
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    widget.item.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    widget.item.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                  ),
                ),

                // Images uploaded by the user
                _buildImageSection(),

                // Location row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.item.location,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _toggleLike,
                        icon: Icon(
                          _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 20,
                          color: _isLiked ? AppColors.primary : Colors.grey[600],
                        ),
                      ),
                      Text('${widget.item.likeCount}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _toggleComments,
                        icon: Icon(
                          _isCommentsExpanded ? Icons.comment : Icons.comment_outlined,
                          size: 20,
                          color: _isCommentsExpanded ? AppColors.primary : Colors.grey[600],
                        ),
                      ),
                      Text('${widget.item.commentCount}', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('View', style: TextStyle(fontSize: 13)),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),

                // Comment Section
                Consumer<FeedProvider>(
                  builder: (context, feedProvider, _) {
                    return CommentSection(
                      commentCount: widget.item.commentCount,
                      comments: feedProvider.getComments(widget.item.id),
                      isLoading: feedProvider.isCommentsLoading(widget.item.id),
                      onAddComment: (message) => feedProvider.addComment(widget.item.id, message),
                      isExpanded: _isCommentsExpanded,
                      onToggle: _toggleComments,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}