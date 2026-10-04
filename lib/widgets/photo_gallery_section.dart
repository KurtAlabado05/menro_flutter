import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_tokens.dart';

class PhotoDocument {
  final String url;
  final String name;
  final String kind;
  final bool verified;

  PhotoDocument({
    required this.url,
    required this.name,
    this.kind = 'photo',
    this.verified = false,
  });
}

class PhotoGallerySection extends StatefulWidget {
  final List<PhotoDocument> documents;
  final String title;
  final String? subtitle;
  final bool showTreePicturesFirst;
  final VoidCallback? onPhotoTapped;

  const PhotoGallerySection({
    super.key,
    required this.documents,
    this.title = 'Photos',
    this.subtitle,
    this.showTreePicturesFirst = true,
    this.onPhotoTapped,
  });

  @override
  State<PhotoGallerySection> createState() => _PhotoGallerySectionState();
}

class _PhotoGallerySectionState extends State<PhotoGallerySection> {
  PhotoDocument? _selectedPhoto;

  bool _isTreePhoto(PhotoDocument doc) {
    final kind = doc.kind.toLowerCase();
    final name = doc.name.toLowerCase();
    return kind == 'tree-picture' || name.startsWith('tree picture');
  }

  bool _hasValidUrl(PhotoDocument doc) {
    final url = doc.url.toLowerCase().trim();
    return url.isNotEmpty &&
           url != 'pending_upload' &&
           url != 'pending upload' &&
           url.startsWith('http');
  }

  @override
  Widget build(BuildContext context) {
    final validDocs = widget.documents.where(_hasValidUrl).toList();

    if (validDocs.isEmpty) {
      return _buildEmptyState();
    }

    final treePics = validDocs.where(_isTreePhoto).toList();
    final otherDocs = validDocs.where((d) => !_isTreePhoto(d)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (widget.subtitle != null)
                  Text(
                    widget.subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Tree Photos Section
        if (treePics.isNotEmpty) ...[
          _TreePhotosGrid(
            photos: treePics,
            onPhotoTapped: (photo) {
              setState(() => _selectedPhoto = photo);
              widget.onPhotoTapped?.call();
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Other Documents Section
        if (otherDocs.isNotEmpty) ...[
          _OtherDocumentsTable(documents: otherDocs),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        'No documents available. Documents may still be uploading.',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _TreePhotosGrid extends StatelessWidget {
  final List<PhotoDocument> photos;
  final Function(PhotoDocument) onPhotoTapped;

  const _TreePhotosGrid({
    required this.photos,
    required this.onPhotoTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TREE PICTURES',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${photos.length} image${photos.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Photo Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 4 / 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return _PhotoTile(
                  photo: photo,
                  index: index,
                  onTap: () => onPhotoTapped(photo),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  final PhotoDocument photo;
  final int index;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.photo,
    required this.index,
    required this.onTap,
  });

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  bool _imageLoaded = false;
  bool _imageError = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image container
              Expanded(
                child: Container(
                  color: Colors.grey[100],
                  child: _imageError
                      ? _buildPlaceholder(
                          'Image\nunavailable',
                          Icons.broken_image_outlined,
                        )
                      : Image.network(
                          widget.photo.url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              _imageLoaded = true;
                              return child;
                            }
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            _imageError = true;
                            return _buildPlaceholder(
                              'Image\nunavailable',
                              Icons.broken_image_outlined,
                            );
                          },
                        ),
                ),
              ),

              // URL snippet
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Text(
                  widget.photo.url,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[400],
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
              ),

              // Photo name
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                child: Text(
                  widget.photo.name.isNotEmpty
                      ? widget.photo.name
                      : 'Tree Picture ${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String text, IconData icon) {
    return Container(
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey[400], size: 24),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherDocumentsTable extends StatelessWidget {
  final List<PhotoDocument> documents;

  const _OtherDocumentsTable({required this.documents});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Document',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Actions',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table Rows
          ...documents.asMap().entries.map((entry) {
            final doc = entry.value;
            final isLast = entry.key == documents.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          doc.name.isNotEmpty ? doc.name : 'Document',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => PhotoPreviewDialog(
                                    url: doc.url,
                                    name: doc.name,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.visibility, size: 16),
                              label: const Text('View'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    color: Colors.grey.shade200,
                    indent: 12,
                    endIndent: 12,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class PhotoPreviewDialog extends StatefulWidget {
  final String url;
  final String name;

  const PhotoPreviewDialog({
    super.key,
    required this.url,
    required this.name,
  });

  @override
  State<PhotoPreviewDialog> createState() => _PhotoPreviewDialogState();
}

class _PhotoPreviewDialogState extends State<PhotoPreviewDialog> {
  double _zoom = 1.0;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() => _zoom = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isImage = RegExp(r'\.(png|jpe?g|gif|webp|bmp|svg)(\?|#|$)',
        caseSensitive: false)
        .hasMatch(widget.url);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photo Preview',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          widget.name.isNotEmpty ? widget.name : 'Photo',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),

            // Content
            if (isImage)
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(80),
                      minScale: 0.5,
                      maxScale: 5.0,
                      onInteractionEnd: (_) {
                        setState(() {
                          final scale = _transformationController
                              .value
                              .getMaxScaleOnAxis();
                          _zoom = scale;
                        });
                      },
                      child: Image.network(
                        widget.url,
                        fit: BoxFit.contain,
                        loadingBuilder:
                            (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress
                                      .expectedTotalBytes !=
                                  null
                                  ? loadingProgress
                                          .cumulativeBytesLoaded /
                                      loadingProgress
                                          .expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error,
                            stackTrace) =>
                            Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.grey[400],
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cannot preview this document',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This document type cannot be rendered as an image.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isImage)
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _resetZoom();
                          },
                          child: Text(
                            'Reset (${(_zoom * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      // Open URL in browser
                      // TODO: Implement URL launcher
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
