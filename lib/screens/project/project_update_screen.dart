import 'package:flutter/material.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_button.dart';

class ProjectUpdateScreen extends StatefulWidget {
  const ProjectUpdateScreen({super.key});

  @override
  State<ProjectUpdateScreen> createState() => _ProjectUpdateScreenState();
}

class _ProjectUpdateScreenState extends State<ProjectUpdateScreen> {
  final _updateController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Project Update')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share Progress',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Update the community on the milestones achieved.'),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _updateController,
              label: 'What happened today?',
              prefixIcon: Icons.update,
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            // Placeholder for image picker
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Progress Photos'),
            ),
            const Spacer(),
            CustomButton(
              text: 'Publish Update',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}