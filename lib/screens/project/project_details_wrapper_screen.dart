import 'package:flutter/material.dart';

import 'project_details_screen.dart';

/// Wrapper to ensure DashboardScreen's MainScreen header + bottom navbar
/// remain visible.
///
/// The original [ProjectDetailsScreen] builds its own [Scaffold], which
/// replaces the parent scaffold from [MainScreen]. This wrapper relies on the
/// edits in that file to render content only.
class ProjectDetailsWrapperScreen extends StatelessWidget {
  final String projectId;
  const ProjectDetailsWrapperScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return ProjectDetailsScreen(projectId: projectId);
  }
}
