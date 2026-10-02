import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../services/citizen_charter_knowledge_base.dart';
import 'map/map_screen.dart';
import 'project/project_list_screen.dart';
import 'submissions/report_input_screen.dart';
import 'submissions/report_submissions_hub_screen.dart';
import 'submissions/tree_cutting_submissions_hub_screen.dart';
import 'tree_cutting_application_screen.dart';

enum _AssistantModule { reports, permits, projects, ecoMap }

enum _AssistantAction { newReport, myReports, newPermit, myPermits, projects, map }

class _AssistantMessage {
  const _AssistantMessage({
    required this.text,
    required this.isUser,
    this.action,
  });

  final String text;
  final bool isUser;
  final _AssistantAction? action;
}

class VirtualAssistantScreen extends StatefulWidget {
  const VirtualAssistantScreen({super.key});

  @override
  State<VirtualAssistantScreen> createState() => _VirtualAssistantScreenState();
}

class _VirtualAssistantScreenState extends State<VirtualAssistantScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  _AssistantModule _activeModule = _AssistantModule.reports;
  bool _isSending = false;

  final List<_AssistantMessage> _messages = [
    const _AssistantMessage(
      text:
          'Hello. I can help with EcoMap, MENRO Baliwag services, environmental reports, tree-cutting permits, and community projects. I cannot make official decisions or submit anything without your review.',
      isUser: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _moduleLabel => switch (_activeModule) {
    _AssistantModule.reports => 'Environmental reports',
    _AssistantModule.permits => 'Tree-cutting permits',
    _AssistantModule.projects => 'Community projects',
    _AssistantModule.ecoMap => 'EcoMap and MENRO Baliwag',
  };

  List<String> get _suggestions => switch (_activeModule) {
    _AssistantModule.reports => [
      'How do I file a report?',
      'Can I report anonymously?',
      'How can I track my report?',
    ],
    _AssistantModule.permits => [
      'What documents do I need?',
      'How do I apply for a permit?',
      'Where can I track my application?',
    ],
    _AssistantModule.projects => [
      'How do I find a project?',
      'Can I join a project?',
      'What do project statuses mean?',
    ],
    _AssistantModule.ecoMap => [
      'What is EcoMap?',
      'What does the environmental map show?',
      'Where is the MENRO Baliwag office?',
    ],
  };

  void _selectModule(_AssistantModule module) {
    setState(() => _activeModule = module);
  }

  _AssistantModule _detectModule(String text) {
    final query = text.toLowerCase();
    if (query.contains('ecomap') ||
        query.contains('eco map') ||
        query.contains('environmental map') ||
        query.contains('map')) {
      return _AssistantModule.ecoMap;
    }
    if (query.contains('permit') ||
        query.contains('tree cutting') ||
        query.contains('tree-cutting') ||
        query.contains('trimming') ||
        query.contains('cut a tree') ||
        query.contains('no objection') ||
        query.contains('clearance') ||
        query.contains('endorsement') ||
        query.contains('eic')) {
      return _AssistantModule.permits;
    }
    if (query.contains('project') ||
        query.contains('event') ||
        query.contains('join')) {
      return _AssistantModule.projects;
    }
    if (query.contains('report') ||
        query.contains('dump') ||
        query.contains('pollution') ||
        query.contains('burning') ||
        query.contains('complaint')) {
      return _AssistantModule.reports;
    }
    if (query.contains('menro') || query.contains('baliwag')) {
      return _AssistantModule.ecoMap;
    }
    return _activeModule;
  }

  _AssistantMessage _answer(String text, _AssistantModule module) {
    final query = text.toLowerCase();
    if (query.trim().isEmpty ||
        query.contains('hello') ||
        query == 'hi' ||
        query == 'hey') {
      return const _AssistantMessage(
        text:
            'Choose a service above or tap a suggested question. I can help you find the right form or explain the information it asks for.',
        isUser: false,
      );
    }

    final ecoMapAnswer = CitizenCharterKnowledgeBase.answerEcoMapQuestion(text);
    if (ecoMapAnswer != null) {
      final isMapQuestion = query.contains('map') ||
          query.contains('ecomap') ||
          query.contains('eco map');
      return _AssistantMessage(
        text: ecoMapAnswer,
        isUser: false,
        action: isMapQuestion ? _AssistantAction.map : null,
      );
    }

    switch (module) {
      case _AssistantModule.reports:
        if (query.contains('anonymous')) {
          return const _AssistantMessage(
            text:
                'The current environmental report form requires a signed-in account and does not offer anonymous submission. You can review your reports from My Reports after filing.',
            isUser: false,
            action: _AssistantAction.newReport,
          );
        }
        if (query.contains('track') ||
            query.contains('status') ||
            query.contains('my report')) {
          return const _AssistantMessage(
            text:
                'I cannot look up private case details in this guided assistant. Open My Reports to see your submissions, status history, and case correspondence.',
            isUser: false,
            action: _AssistantAction.myReports,
          );
        }
        if (query.contains('nearby') ||
            query.contains('duplicate') ||
            query.contains('already reported')) {
          return const _AssistantMessage(
            text:
                'Before saving, the app checks for an active report in the same category within about 35 metres. If it finds one, you can add your support to that report instead of creating a duplicate.',
            isUser: false,
            action: _AssistantAction.newReport,
          );
        }
        return const _AssistantMessage(
          text:
              'You can report illegal dumping, waterway pollution, improper wastewater disposal, open burning, public smoking violations, or littering and public vandalism. Add a clear description, location, and any helpful photos. Review the details before submitting.',
          isUser: false,
          action: _AssistantAction.newReport,
        );

      case _AssistantModule.permits:
        if (query.contains('track') ||
            query.contains('status') ||
            query.contains('my application') ||
            query.contains('my permit')) {
          return const _AssistantMessage(
            text:
                'Open My Permit Applications to review your submitted applications and their recorded status history. I cannot access or change an application here.',
            isUser: false,
            action: _AssistantAction.myPermits,
          );
        }
        final charterAnswer = CitizenCharterKnowledgeBase.answerPermitQuestion(
          text,
        );
        if (charterAnswer != null) {
          return _AssistantMessage(
            text: charterAnswer,
            isUser: false,
            action: _AssistantAction.newPermit,
          );
        }
        return const _AssistantMessage(
          text:
              'I could not find that detail in the Citizen Charter excerpt available to me, so I do not want to guess. Please contact MENRO at Baliwag Climate Change Center, DRT Highway, Pagala, Baliwag, Bulacan, call 798-0391 local 3676, or email menro_baliwag@yahoo.com. You can also open the application form to review its current requirements.',
          isUser: false,
          action: _AssistantAction.newPermit,
        );

      case _AssistantModule.projects:
        if (query.contains('join') || query.contains('participat')) {
          return const _AssistantMessage(
            text:
                'Browse the community projects list to see project details and participation. Signed-in users can join or leave projects that are not completed.',
            isUser: false,
            action: _AssistantAction.projects,
          );
        }
        if (query.contains('status') ||
            query.contains('ongoing') ||
            query.contains('completed')) {
          return const _AssistantMessage(
            text:
                'Projects are grouped as Not Started (pending), Ongoing, and Done (completed). Open a project to review its goal, target date, location, and participant count.',
            isUser: false,
            action: _AssistantAction.projects,
          );
        }
        return const _AssistantMessage(
          text:
              'You can browse community projects by status and search by project name, description, location, or category. Open a project to review its goal and details.',
          isUser: false,
          action: _AssistantAction.projects,
        );

      case _AssistantModule.ecoMap:
        final charterAnswer = CitizenCharterKnowledgeBase.answerPermitQuestion(
          text,
        );
        if (charterAnswer != null) {
          return _AssistantMessage(
            text: charterAnswer,
            isUser: false,
            action: _AssistantAction.newPermit,
          );
        }
        return const _AssistantMessage(
          text:
              'I can help with EcoMap features, environmental reports, permits, community projects, and MENRO Baliwag contact details. For a specific case or an official decision, please contact MENRO directly.',
          isUser: false,
        );
    }
  }

  void _sendMessage([String? suggestedText]) {
    final text = (suggestedText ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    final module = _detectModule(text);
    setState(() {
      _isSending = true;
      _activeModule = module;
      _messages.add(_AssistantMessage(text: text, isUser: true));
      _messages.add(_answer(text, module));
      _messageController.clear();
      _isSending = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openAction(_AssistantAction action) {
    final screen = switch (action) {
      _AssistantAction.newReport => const ReportInputScreen(),
      _AssistantAction.myReports => const ReportSubmissionsHubScreen(),
      _AssistantAction.newPermit => const TreeCuttingApplicationScreen(),
      _AssistantAction.myPermits => const TreeCuttingSubmissionsHubScreen(),
      _AssistantAction.projects => const _AssistantProjectsPage(),
      _AssistantAction.map => const MapScreen(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          titleSpacing: 0,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CENRO Virtual Assistant',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                'Guided automated help',
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'New conversation',
              onPressed: () {
                setState(() {
                  _activeModule = _AssistantModule.reports;
                  _messages
                    ..clear()
                    ..add(
                      const _AssistantMessage(
                        text:
                            'Hello. I can help with EcoMap, MENRO Baliwag services, environmental reports, tree-cutting permits, and community projects. I cannot make official decisions or submit anything without your review.',
                        isUser: false,
                      ),
                    );
                });
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.textGrey,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'General guidance only. Case details and official decisions stay with MENRO staff.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<_AssistantModule>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _AssistantModule.reports,
                          label: Text('Reports'),
                        ),
                        ButtonSegment(
                          value: _AssistantModule.permits,
                          label: Text('Permits'),
                        ),
                        ButtonSegment(
                          value: _AssistantModule.projects,
                          label: Text('Projects'),
                        ),
                        ButtonSegment(
                          value: _AssistantModule.ecoMap,
                          label: Text('EcoMap'),
                        ),
                      ],
                      selected: {_activeModule},
                      onSelectionChanged: (selection) =>
                          _selectModule(selection.first),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _MessageBubble(
                    message: _messages[index],
                    onAction: _openAction,
                  ),
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_moduleLabel · Suggested questions',
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) => ActionChip(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD7DED7)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          label: Text(_suggestions[index]),
                          onPressed: () => _sendMessage(_suggestions[index]),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 500,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Ask about $_moduleLabel',
                              counterText: '',
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSending ? null : _sendMessage,
                          tooltip: 'Send question',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            fixedSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.send_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantProjectsPage extends StatelessWidget {
  const _AssistantProjectsPage();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Community Projects'),
        ),
        body: const ProjectListScreen(),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onAction});

  final _AssistantMessage message;
  final ValueChanged<_AssistantAction> onAction;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isUser ? null : Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.support_agent_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'CENRO GUIDANCE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
              ],
              Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.textDark,
                  height: 1.4,
                  fontSize: 14,
                ),
              ),
              if (message.action != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => onAction(message.action!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: Icon(_actionIcon(message.action!), size: 17),
                  label: Text(_actionLabel(message.action!)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _actionIcon(_AssistantAction action) => switch (action) {
    _AssistantAction.newReport => Icons.add_location_alt_outlined,
    _AssistantAction.myReports => Icons.assignment_outlined,
    _AssistantAction.newPermit => Icons.park_outlined,
    _AssistantAction.myPermits => Icons.folder_open_outlined,
    _AssistantAction.projects => Icons.groups_outlined,
    _AssistantAction.map => Icons.map_outlined,
  };

  String _actionLabel(_AssistantAction action) => switch (action) {
    _AssistantAction.newReport => 'Start an environmental report',
    _AssistantAction.myReports => 'Open My Reports',
    _AssistantAction.newPermit => 'Start a permit application',
    _AssistantAction.myPermits => 'Open My Permit Applications',
    _AssistantAction.projects => 'Browse community projects',
    _AssistantAction.map => 'Open environmental map',
  };
}
