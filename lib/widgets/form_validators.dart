String? requiredField(String? value, [String message = 'Required field']) =>
    (value == null || value.trim().isEmpty) ? message : null;

String? phoneValidator(String? value) {
  if (value == null || value.isEmpty) return 'Required field';
  if (value.length < 13) return 'Enter the complete 11-digit mobile number';
  if (!value.startsWith('09')) return 'Must start with 09';
  return null;
}
