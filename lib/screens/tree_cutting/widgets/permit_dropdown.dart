import 'package:flutter/material.dart';

/// Dropdown that keeps working when the model changes the value externally
/// (for example when the species identifier fills it in).
class PermitDropdown extends StatelessWidget {
  const PermitDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labels = const {},
    this.validator,
    this.helperText,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<String> options;
  final Map<String, String> labels;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;
  final String? helperText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    String textFor(String v) => labels[v] ?? v;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(textFor(o), overflow: TextOverflow.ellipsis),
          ),
      ],
      selectedItemBuilder: (_) => [
        for (final o in options)
          Text(textFor(o), overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
      onChanged: enabled ? onChanged : null,
      validator: validator,
    );
  }
}
