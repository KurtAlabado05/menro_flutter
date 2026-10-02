import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/account_type.dart';
import '../../../models/user_model.dart';

typedef ProfileBadge = ({Color color, IconData icon, String label});

/// Derived, display-ready facts about the signed-in user.
@immutable
class ProfileFlags {
  const ProfileFlags._({
    required this.isOrg,
    required this.isCitizen,
    required this.isVerified,
    required this.hasUploadedDoc,
    required this.canApplyForOrganization,
    required this.canRequestRepresentation,
    required this.canManageOrgPermit,
    required this.canUploadCitizenId,
    required this.showOrgBanner,
    required this.orgBannerMessage,
    required this.orgBannerColor,
    required this.orgBannerIcon,
    required this.badge,
  });

  factory ProfileFlags.from(UserModel user) {
    final isOrg = user.accountType == AccountType.organization;
    final isCitizen = user.accountType == AccountType.citizen;
    final isVerified = isOrg
        ? user.organizationStatus == 'verified' &&
              user.organizationMembershipStatus == 'approved'
        : user.isVerified ?? false;
    final hasUploadedDoc = switch (user.accountType) {
      AccountType.organization =>
        user.businessPermitUrl?.trim().isNotEmpty == true,
      AccountType.citizen =>
        user.citizenNationalIdUrl?.trim().isNotEmpty == true,
      null => false,
    };
    final hasApprovedAccess = user.hasApprovedOrganizationAccess;
    final hasPendingRequest = user.organizationRequestStatus == 'pending_review';

    final message = hasPendingRequest
        ? 'Request for ${user.organizationRequestName ?? 'organization access'} '
              'is pending review'
        : user.organizationMembershipStatus == 'approved'
        ? 'Organization access approved'
        : user.organizationStatus == 'verified'
        ? 'Organization verified; representative access pending'
        : user.organizationStatus == 'rejected'
        ? 'Organization application needs review'
        : isOrg && user.organizationStatus == 'pending' && !hasUploadedDoc
        ? 'Business permit required to complete review'
        : user.organizationRequestStatus != null
        ? 'Representative request pending review'
        : 'Organization application pending review';

    final ProfileBadge badge;
    if (isVerified) {
      badge = (
        color: AppColors.statusApproved,
        icon: Icons.verified_user_outlined,
        label: 'Verified',
      );
    } else if (isOrg && user.organizationStatus == 'rejected') {
      badge = (
        color: AppColors.statusRejected,
        icon: Icons.error_outline_rounded,
        label: 'Application rejected',
      );
    } else if (isOrg && user.organizationStatus != 'pending') {
      badge = (
        color: AppColors.textGrey,
        icon: Icons.help_outline_rounded,
        label: 'Status unavailable',
      );
    } else if (isOrg || isCitizen) {
      badge = hasUploadedDoc
          ? (
              color: AppColors.statusPending,
              icon: Icons.hourglass_empty_rounded,
              label: 'Pending review',
            )
          : (
              color: AppColors.statusRejected,
              icon: Icons.error_outline_rounded,
              label: isOrg ? 'Permit required' : 'ID required',
            );
    } else {
      badge = (
        color: AppColors.textGrey,
        icon: Icons.account_circle_outlined,
        label: user.role.toUpperCase(),
      );
    }

    return ProfileFlags._(
      isOrg: isOrg,
      isCitizen: isCitizen,
      isVerified: isVerified,
      hasUploadedDoc: hasUploadedDoc,
      canApplyForOrganization:
          isCitizen &&
          user.organizationId == null &&
          user.organizationStatus == null &&
          user.organizationRequestStatus == null,
      canRequestRepresentation:
          isCitizen && !hasApprovedAccess && !hasPendingRequest,
      canManageOrgPermit: isOrg && user.organizationStatus == 'pending',
      canUploadCitizenId: isCitizen && !isVerified && !hasUploadedDoc,
      showOrgBanner:
          user.organizationStatus != null ||
          user.organizationRequestStatus != null,
      orgBannerMessage: message,
      orgBannerColor: hasApprovedAccess
          ? AppColors.statusApproved
          : user.organizationStatus == 'rejected'
          ? AppColors.statusRejected
          : AppColors.statusPending,
      orgBannerIcon: hasApprovedAccess
          ? Icons.verified_outlined
          : user.organizationStatus == 'rejected'
          ? Icons.error_outline
          : Icons.schedule_outlined,
      badge: badge,
    );
  }

  final bool isOrg;
  final bool isCitizen;
  final bool isVerified;
  final bool hasUploadedDoc;
  final bool canApplyForOrganization;
  final bool canRequestRepresentation;
  final bool canManageOrgPermit;
  final bool canUploadCitizenId;
  final bool showOrgBanner;
  final String orgBannerMessage;
  final Color orgBannerColor;
  final IconData orgBannerIcon;
  final ProfileBadge badge;
}
