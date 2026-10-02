import 'package:flutter/widgets.dart';
import '../../core/constants/user_roles.dart';
import '../../models/user_model.dart';
import '../inspection_officer/denr_case_queue_screen.dart';
import '../inspection_officer/inspection_officer_shell.dart';
import '../main/main_screen.dart';

/// Single source of truth for which home screen each role lands on.
Widget homeForUser(UserModel? user) {
  if (user?.isInspectionOfficer ?? false) {
    return const InspectionOfficerShell();
  }
  if (user?.role == UserRoles.denrOfficer) {
    return const DenrCaseQueueScreen();
  }
  return const MainScreen();
}
