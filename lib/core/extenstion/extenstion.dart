extension OptionalStringExtension on String? {
  bool get isNotNull {
    return this != null && this!.isNotEmpty;
  }
}
