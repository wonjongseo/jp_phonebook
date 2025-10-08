class CallDirectoryEntry {
  final String number; // "+81...", "03...", "090..." 등
  final String label; // "고객A", "회사대표" 등
  const CallDirectoryEntry({required this.number, required this.label});
  Map<String, String> toJson() => {'number': number, 'label': label};
}
