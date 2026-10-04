import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_tokens.dart';
import '../../../widgets/section_widgets.dart';
import '../tree_cutting_form_model.dart';

class PermitDocumentsStep extends StatelessWidget {
  const PermitDocumentsStep({
    super.key,
    required this.model,
    required this.onUpload,
    this.onTakeOnSitePhoto,
  });

  final TreeCuttingFormModel model;
  final ValueChanged<PermitAttachment> onUpload;
  final VoidCallback? onTakeOnSitePhoto;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final errors = model.showDocumentErrors;
        return Column(
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    icon: Icons.account_balance_outlined,
                    label: 'Who will receive this?',
                    subtitle: 'Your request letter should be addressed to them',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _AuthorityOption(
                    selected:
                        model.targetAuthority ==
                        TreeCuttingFormModel.authorityLgu,
                    title: 'Local Government Unit',
                    subtitle:
                        'Hon. Sonia Viceo-Estrella\nReplacement: 20 seedlings',
                    enabled: !model.submitting,
                    onTap: () =>
                        model.setAuthority(TreeCuttingFormModel.authorityLgu),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AuthorityOption(
                    selected:
                        model.targetAuthority ==
                        TreeCuttingFormModel.authorityDenr,
                    title: 'DENR-CENRO',
                    subtitle:
                        'Mr. Dennis P. Vergara\nReplacement: 50 seedlings',
                    enabled: !model.submitting,
                    onTap: () =>
                        model.setAuthority(TreeCuttingFormModel.authorityDenr),
                  ),
                  if (errors && model.targetAuthority == null)
                    const _ErrorText('Choose who will receive your application'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    icon: Icons.folder_open_outlined,
                    label: 'Documents',
                    subtitle: 'PDF, JPG or PNG files',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PermitDocumentTile(
                    title: 'Request letter',
                    helper: 'Addressed to the authority you chose above',
                    requirement: 'Required',
                    attached: model.isAttached(PermitAttachment.requestLetter),
                    uploading:
                        model.uploading == PermitAttachment.requestLetter,
                    disabled: model.busy,
                    showError: errors,
                    onUpload: () => onUpload(PermitAttachment.requestLetter),
                    onRemove: () =>
                        model.detach(PermitAttachment.requestLetter),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PermitDocumentTile(
                    title: 'LGU / Barangay certification',
                    helper: 'No-objection certification from the Barangay or Mayor',
                    requirement: 'Required',
                    attached: model.isAttached(
                      PermitAttachment.lguCertification,
                    ),
                    uploading:
                        model.uploading == PermitAttachment.lguCertification,
                    disabled: model.busy,
                    showError: errors,
                    onUpload: () =>
                        onUpload(PermitAttachment.lguCertification),
                    onRemove: () =>
                        model.detach(PermitAttachment.lguCertification),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PermitDocumentTile(
                    title: 'Land title (copy)',
                    helper: 'Only if the land is privately owned',
                    requirement: 'Optional',
                    attached: model.isAttached(PermitAttachment.landTitle),
                    uploading: model.uploading == PermitAttachment.landTitle,
                    disabled: model.busy,
                    showError: false,
                    onUpload: () => onUpload(PermitAttachment.landTitle),
                    onRemove: () => model.detach(PermitAttachment.landTitle),
                  ),
                  if (model.isSchoolGrounds) ...[
                    const SizedBox(height: AppSpacing.md),
                    PermitDocumentTile(
                      title: 'PTA President certification',
                      helper: 'Required because the site is on school grounds',
                      requirement: 'Required',
                      attached: model.isAttached(
                        PermitAttachment.ptaCertification,
                      ),
                      uploading:
                          model.uploading == PermitAttachment.ptaCertification,
                      disabled: model.busy,
                      showError: errors,
                      onUpload: () =>
                          onUpload(PermitAttachment.ptaCertification),
                      onRemove: () =>
                          model.detach(PermitAttachment.ptaCertification),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    icon: Icons.photo_camera_outlined,
                    label: 'Photos',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PermitPhotoGroup(
                    title: 'Photos of the trees',
                    helper: 'Each photo must pass plant recognition. A close-up of the leaves works best. If the tree has no leaves or is dead, take an on-site photo at the tree instead.',
                    requirement: 'Required',
                    urls: model.treePhotoUrls,
                    flaggedUrls: model.unverifiedTreePhotoUrls,
                    uploading: model.uploading == PermitAttachment.treePhotos,
                    disabled: model.busy,
                    showError: errors && model.treePhotoUrls.isEmpty,
                    onAdd: () => onUpload(PermitAttachment.treePhotos),
                    onRemove: (i) =>
                        model.detach(PermitAttachment.treePhotos, index: i),
                  ),
                  if (onTakeOnSitePhoto != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: model.busy ? null : onTakeOnSitePhoto,
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text(
                          'No leaves or dead tree? Take on-site photo',
                        ),
                      ),
                    ),
                  if (model.requiresSpeciesInspection) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const _InspectionNotice(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (model.photoError != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(model.photoError!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  PermitPhotoGroup(
                    title: 'Surroundings',
                    helper: 'Wider photos showing nearby structures or lines',
                    requirement: 'Optional',
                    urls: model.contextPhotoUrls,
                    uploading:
                        model.uploading == PermitAttachment.contextPhotos,
                    disabled: model.busy,
                    showError: false,
                    onAdd: () => onUpload(PermitAttachment.contextPhotos),
                    onRemove: (i) =>
                        model.detach(PermitAttachment.contextPhotos, index: i),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InspectionNotice extends StatelessWidget {
  const _InspectionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange.fade(0.1),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: Colors.orange.fade(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, color: Colors.orange.shade800),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Species not confirmed from photos. Your application will be flagged so MENRO can verify the species during the site inspection.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AuthorityOption extends StatelessWidget {
  const _AuthorityOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary.fade(0.06) : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.mdAll,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: selected ? AppColors.primary : Colors.grey.shade300,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? AppColors.primary : AppColors.textGrey,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequirementTag extends StatelessWidget {
  const _RequirementTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final required = text == 'Required';
    final color = required ? AppColors.statusRejected : AppColors.textGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.fade(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TileTitle extends StatelessWidget {
  const _TileTitle({
    required this.title,
    required this.helper,
    required this.requirement,
  });

  final String title;
  final String helper;
  final String requirement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RequirementTag(requirement),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          helper,
          style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        ),
      ],
    );
  }
}

class PermitDocumentTile extends StatelessWidget {
  const PermitDocumentTile({
    super.key,
    required this.title,
    required this.helper,
    required this.requirement,
    required this.attached,
    required this.uploading,
    required this.disabled,
    required this.showError,
    required this.onUpload,
    required this.onRemove,
  });

  final String title;
  final String helper;
  final String requirement;
  final bool attached;
  final bool uploading;
  final bool disabled;
  final bool showError;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final missing = showError && !attached && requirement == 'Required';
    final error = Theme.of(context).colorScheme.error;
    final Color accent = attached
        ? AppColors.statusApproved
        : missing
        ? error
        : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileTitle(title: title, helper: helper, requirement: requirement),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: attached ? accent.fade(0.05) : Colors.grey.shade50,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: attached || missing ? accent.fade(0.4) : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: disabled || attached ? null : onUpload,
                  borderRadius: AppRadius.mdAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        if (uploading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            attached
                                ? Icons.check_circle
                                : Icons.upload_file_outlined,
                            size: 20,
                            color: accent,
                          ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            uploading
                                ? 'Uploading...'
                                : attached
                                ? 'Uploaded'
                                : missing
                                ? 'Required. Tap to upload'
                                : 'Tap to upload',
                            style: TextStyle(
                              fontSize: 13,
                              color: attached || missing
                                  ? accent
                                  : AppColors.textGrey,
                              fontWeight: attached
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (attached) ...[
                TextButton(
                  onPressed: disabled ? null : onUpload,
                  child: const Text('Replace'),
                ),
                IconButton(
                  tooltip: 'Remove $title',
                  onPressed: disabled ? null : onRemove,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class PermitPhotoGroup extends StatelessWidget {
  const PermitPhotoGroup({
    super.key,
    required this.title,
    required this.helper,
    required this.requirement,
    required this.urls,
    required this.uploading,
    required this.disabled,
    required this.showError,
    required this.onAdd,
    required this.onRemove,
    this.flaggedUrls = const {},
  });

  final String title;
  final String helper;
  final String requirement;
  final List<String> urls;
  final bool uploading;
  final bool disabled;
  final bool showError;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  /// Photos accepted only as on-site evidence; shown with an inspection badge.
  final Set<String> flaggedUrls;

  static const double _size = 88;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TileTitle(title: title, helper: helper, requirement: requirement),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _size,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == urls.length) {
                final color = showError ? error : AppColors.primary;
                return Semantics(
                  button: true,
                  label: 'Add photo to $title',
                  excludeSemantics: true,
                  child: Material(
                    color: color.fade(0.06),
                    borderRadius: AppRadius.mdAll,
                    child: InkWell(
                      onTap: disabled ? null : onAdd,
                      borderRadius: AppRadius.mdAll,
                      child: Container(
                        width: _size,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.mdAll,
                          border: Border.all(color: color.fade(0.3)),
                        ),
                        child: uploading
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: color,
                                    size: 26,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Add photo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              }

              return SizedBox(
                width: _size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.mdAll,
                      child: Image.network(
                        urls[index],
                        fit: BoxFit.cover,
                        semanticLabel: '$title ${index + 1}',
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const ColoredBox(
                                color: Colors.black12,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.black12,
                          child: Icon(Icons.insert_drive_file_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: 'Remove photo ${index + 1}',
                        onPressed: disabled ? null : () => onRemove(index),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                    if (flaggedUrls.contains(urls[index]))
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Tooltip(
                          message: 'On-site photo: species to be verified at inspection',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade800,
                              borderRadius: AppRadius.mdAll,
                            ),
                            child: const Text(
                              'On-site',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        if (showError)
          _ErrorText('Add at least one photo of the trees'),
      ],
    );
  }
}
