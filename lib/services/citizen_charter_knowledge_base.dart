class CitizenCharterKnowledgeBase {
  CitizenCharterKnowledgeBase._();

  static const _source =
      'Source: MENRO Baliwag Citizen Charter, excerpt provided by the user.';
    static const _ecoMapSource =
      'Sources: EcoMap app features and MENRO Baliwag Citizen Charter excerpt.';

  static const _entries = <_KnowledgeEntry>[
    _KnowledgeEntry(
      triggers: [
        'no objection clearance requirements',
        'requirements for no objection clearance',
        'documents for no objection clearance',
        'no objection clearance',
        'no objection certificate',
        'no objection',
      ],
      answer:
          'The No Objection Clearance checklist in the excerpt lists: Barangay Certificate, Business Name, Business Permit, Barangay Resolution, Land Title, Zoning Permit, Farm Design/PCO/Drainage, and a picture of the septage tank. The charter also lists establishments, schools, and hospitals as those who may avail of the service. Confirm the current checklist with MENRO before filing.',
    ),
    _KnowledgeEntry(
      triggers: [
        'environmental inspection clearance requirements',
        'requirements for environmental inspection clearance',
        'documents for environmental inspection clearance',
        'inspection clearance requirements',
        'environmental inspection clearance',
        'eic requirements',
        'eic form',
        'eic',
      ],
      answer:
          'The Environmental Inspection Clearance checklist lists: EIC Form, Barangay Certificate, Zoning Permit, Updated Business Permit, and ECC/CNC. The charter describes this clearance as recognition of an establishment’s compliance with environmental regulations. It lists establishments, schools, and hospitals as those who may avail of the service.',
    ),
    _KnowledgeEntry(
      triggers: [
        'requirements for tree cutting',
        'tree cutting requirements',
        'documents for tree cutting',
        'tree cutting documents',
        'tree cutting checklist',
        'requirements for trimming a tree',
        'papers for trimming a tree',
        'documents for tree trimming',
        'tree trimming requirements',
        'tree endorsement requirements',
        'tree permit requirements',
        'request letter',
      ],
      answer:
          'The tree-cutting/trimming endorsement checklist in the excerpt lists: Request Letter for tree cutting, Barangay certification (no objection for tree cutting), Land Title, Sketch Plan, pictures of the trees, and a referendum for HOA cases. Requirements can depend on the application; verify the current checklist with MENRO.',
    ),
    _KnowledgeEntry(
      triggers: [
        'who may avail',
        'who can apply',
        'who may apply',
        'who is eligible',
        'eligible applicants',
        'eligibility',
        'hospitals',
        'schools',
      ],
      answer:
          'For the Environmental Inspection Clearance / No Objection Clearance entry, the excerpt lists establishments, schools, and hospitals as those who may avail. The tree-cutting/trimming endorsement entry is marked applicable to all. MENRO can confirm eligibility for a specific case.',
    ),
    _KnowledgeEntry(
      triggers: [
        'tree cutting process',
        'tree trimming process',
        'tree endorsement process',
        'how to get a tree endorsement',
        'how do i apply for tree cutting',
        'steps for tree cutting',
        'clearance process',
        'inspection process',
        'ocular inspection',
        'what happens after submitting',
      ],
      answer:
          'The charter’s tree endorsement steps begin with registering at the MENRO logbook and choosing the service, then submitting the required documents. MENRO prepares the endorsement and forwards it for the listed signatory process; after it is signed, the endorsement is forwarded to the Community ENRO. The provided scan clips part of the process, so confirm the current steps with MENRO.',
    ),
    _KnowledgeEntry(
      triggers: [
        'how much does it cost',
        'how much do i pay',
        'is there a fee',
        'are there fees',
        'application fee',
        'processing fee',
        'fees and charges',
        'fee',
        'fees',
        'cost',
        'payment',
      ],
      answer:
          'The provided Citizen Charter tables list NONE for fees for both the clearance and tree-cutting/trimming endorsement services. Confirm with MENRO in case the current schedule has changed.',
    ),
    _KnowledgeEntry(
      triggers: [
        'tree cutting processing time',
        'tree endorsement processing time',
        'how long for tree cutting',
        'how long does tree cutting take',
        'clearance processing time',
        'inspection clearance processing time',
        'how long does clearance take',
        'how long does the process take',
        'processing time',
        'turnaround time',
        'how long',
        'duration',
      ],
      answer:
          'The excerpt gives estimated total processing times of 1 day and 1 hour 12 minutes for Environmental Inspection / No Objection Clearance, and 1 day and 10 minutes for the tree-cutting/trimming endorsement. These are charter estimates, not guaranteed completion times.',
    ),
    _KnowledgeEntry(
      triggers: [
        'where is the menro office',
        'menro office location',
        'menro address',
        'office address',
        'where can i contact menro',
        'contact menro',
        'contact number',
        'phone number',
        'email address',
        'email',
        'address',
        'location',
      ],
      answer:
          'The excerpt lists the City Environment and Natural Resources Office at Baliwag Climate Change Center, DRT Highway, Pagala, Baliwag, Bulacan. Contact number: 798-0391 local 3676. Email: menro_baliwag@yahoo.com. The listed Facebook page is www.facebook.com/menrobaliwag/.',
    ),
  ];

  static String? answerPermitQuestion(String question) {
    final normalized = _normalize(question);
    if (normalized.isEmpty) return null;

    _KnowledgeEntry? bestEntry;
    var bestScore = 0;
    var hasTie = false;

    for (final entry in _entries) {
      var score = 0;
      for (final trigger in entry.triggers) {
        if (normalized.contains(trigger)) {
          score += trigger.split(' ').length * 2;
        }
      }
      if (score > bestScore) {
        bestEntry = entry;
        bestScore = score;
        hasTie = false;
      } else if (score > 0 && score == bestScore) {
        hasTie = true;
      }
    }

    if (bestEntry == null || hasTie) return null;
    return '${bestEntry.answer}\n\n$_source';
  }

  static String? answerEcoMapQuestion(String question) {
    final normalized = _normalize(question);
    if (normalized.isEmpty) return null;

    const entries = <_KnowledgeEntry>[
      _KnowledgeEntry(
        triggers: [
          'where is the menro office',
          'where is menro baliwag',
          'menro baliwag office',
          'menro office',
          'menro office location',
          'menro address',
          'menro location',
          'menro contact',
          'menro number',
          'menro phone',
          'call menro',
          'contact menro',
          'contact details',
          'contact number',
          'phone number',
          'email address',
          'menro email',
          'office address',
        ],
        answer:
            'The MENRO Baliwag office is at Baliwag Climate Change Center, DRT Highway, Pagala, Baliwag, Bulacan. Call 798-0391 local 3676 or email menro_baliwag@yahoo.com. The listed Facebook page is www.facebook.com/menrobaliwag/.',
      ),
      _KnowledgeEntry(
        triggers: [
          'what is ecomap',
          'what is eco map',
          'ecomap',
          'eco map',
          'menro baliwag app',
          'what can this app do',
        ],
        answer:
            'EcoMap helps residents access MENRO Baliwag environmental services, including environmental reports, tree-cutting permit guidance, community projects, and a map of mapped reports and projects. This assistant provides general guidance; MENRO staff handle official decisions and case-specific updates.',
      ),
      _KnowledgeEntry(
        triggers: [
          'what does the map show',
          'what is shown on the map',
          'how do i use the map',
          'how to use the map',
          'use the map',
          'environmental map',
          'map markers',
          'map pins',
          'reports on the map',
          'projects on the map',
          'map filter',
        ],
        answer:
            'The environmental map displays reports and community projects that have location coordinates. Use the All, Reports, and Projects filters to narrow the visible markers. Records without coordinates cannot be placed on the map.',
      ),
      _KnowledgeEntry(
        triggers: [
          'how do i report',
          'file an environmental report',
          'report an environmental issue',
          'track my report',
          'report status',
        ],
        answer:
            'Sign in, open the environmental report form, describe the issue, provide its location, and review the details before submitting. Open My Reports to see your submissions and recorded status history. The current form does not offer anonymous submission.',
      ),
    ];

    _KnowledgeEntry? bestEntry;
    var bestScore = 0;
    var hasTie = false;

    for (final entry in entries) {
      var score = 0;
      for (final trigger in entry.triggers) {
        if (normalized.contains(trigger)) {
          score += trigger.split(' ').length * 2;
        }
      }
      if (score > bestScore) {
        bestEntry = entry;
        bestScore = score;
        hasTie = false;
      } else if (score > 0 && score == bestScore) {
        hasTie = true;
      }
    }

    if (bestEntry == null || hasTie) return null;
    return '${bestEntry.answer}\n\n$_ecoMapSource';
  }

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _KnowledgeEntry {
  const _KnowledgeEntry({required this.triggers, required this.answer});

  final List<String> triggers;
  final String answer;
}
