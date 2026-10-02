import 'package:flutter/material.dart';

/// Content for a single onboarding carousel page.
class OnboardingSlide {
  const OnboardingSlide({
    required this.imagePath,
    required this.fallbackIcon,
    required this.title,
    required this.description,
  });

  final String imagePath;
  final IconData fallbackIcon;
  final String title;
  final String description;
}

const List<OnboardingSlide> onboardingSlides = [
  OnboardingSlide(
    imagePath: 'assets/images/onboarding/welcome.png',
    fallbackIcon: Icons.eco_outlined,
    title: 'Welcome to EcoMap Baliwag',
    description:
        'Your direct line to MENRO/CENRO Baliwag for reporting environmental '
        'concerns and taking part in local sustainability efforts.',
  ),
  OnboardingSlide(
    imagePath: 'assets/images/onboarding/report_issue.png',
    fallbackIcon: Icons.report_problem_outlined,
    title: 'Report Environmental Issues',
    description:
        'Spotted illegal dumping, waterway pollution, or open burning? File '
        'a report with photos and location in just a few taps.',
  ),
  OnboardingSlide(
    imagePath: 'assets/images/onboarding/tree_permit.png',
    fallbackIcon: Icons.park_outlined,
    title: 'Apply for Tree Cutting Permits',
    description:
        'Need to cut or trim a tree? Submit your permit application with '
        'required documents and track its review status.',
  ),
  OnboardingSlide(
    imagePath: 'assets/images/onboarding/community_projects.png',
    fallbackIcon: Icons.diversity_3_outlined,
    title: 'Join Community Projects',
    description:
        'Discover tree planting, clean-up drives, and other local '
        'initiatives, and join in to help your community.',
  ),
  OnboardingSlide(
    imagePath: 'assets/images/onboarding/account_types.png',
    fallbackIcon: Icons.groups_outlined,
    title: 'For Citizens and Organizations',
    description:
        'Sign up as an individual citizen or register your organization to '
        'access features tailored to your account type.',
  ),
];
