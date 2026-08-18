import 'package:flutter/material.dart';

import 'project_list_screen.dart';

/// Wrapper to ensure DashboardScreen's MainScreen header + bottom navbar
/// remain visible.
///
/// The original [ProjectListScreen] builds its own [Scaffold], which replaces
/// the parent scaffold from [MainScreen]. This wrapper removes that isolation
/// by rendering the content only.
class ProjectListWrapperScreen extends StatelessWidget {
  const ProjectListWrapperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the screen widget directly; the actual Scaffold is removed in
    // ProjectListScreen (see edits in that file).
    return const ProjectListScreen();
  }
}
