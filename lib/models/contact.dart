// lib/feature/contacts/model/contact.dart
class ContactModel {
  final String name;
  final String yomiName;
  final List<String> telephones;
  final List<String> emails;
  final String oragnization; // (원문 철자 유지)
  final String titie; // (원문 철자 유지)
  final String memo;
  final String groupId;
  final String status;
  final String contactId;
  final String contactType;

  ContactModel({
    required this.name,
    required this.yomiName,
    required this.telephones,
    required this.emails,
    required this.oragnization,
    required this.titie,
    required this.memo,
    required this.groupId,
    required this.status,
    required this.contactId,
    required this.contactType,
  });
}
