// lib/feature/contacts/controller/local_contact_controller.dart
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:jg_phonebook/models/contact.dart';

class LocalContactController extends GetxController {
  /// 전체 연락처 리스트 (표시용)
  final contacts = <ContactModel>[].obs;

  /// 번호 → 연락처 매핑 (정규화된 국제표기 '81...' 키)
  /// 추가로 끝 9/10자리 키도 등록해서 포매팅 차이 대응
  final contactsByNumber = <String, ContactModel>{}.obs;

  final isReady = false.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 권한 요청 (flutter_contacts 고유 권한 요청)
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      isReady.value = true;
      return;
    }
    await _loadAll();
    isReady.value = true;
  }

  Future<void> refreshContacts() async {
    await _loadAll();
  }

  Future<void> _loadAll() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // 성능 고려: 프로퍼티/그룹만 로드 (사진은 제외)
    final list = await FlutterContacts.getContacts(
      withProperties: true,
      withGroups: true,
      withPhoto: false,
      withThumbnail: false,
    );

    final mapped = <ContactModel>[];
    final map = <String, ContactModel>{};

    for (final c in list) {
      final model = _mapFlutterToModel(c);

      // 전화번호 정규화 후 인덱싱
      for (final raw in model.telephones) {
        final k = _normalizeToDigitsJP(raw);
        if (k.isEmpty) continue;
        map[k] = model;

        // 포맷 다양성 대응을 위한 보조 키 (끝 10/9자리)
        final last10 = _suffixDigits(k, 10);
        final last9 = _suffixDigits(k, 9);
        if (last10.isNotEmpty) map['#10:$last10'] = model;
        if (last9.isNotEmpty) map['#9:$last9'] = model;
      }

      mapped.add(model);
    }

    contacts.assignAll(mapped);
    contactsByNumber.assignAll(map);
  }

  /// 외부에서 번호로 조회 (원시 문자열 입력 허용)
  ContactModel? lookup(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final k = _normalizeToDigitsJP(raw);
    if (k.isEmpty) return null;

    // 1차: 완전 키
    if (contactsByNumber.containsKey(k)) return contactsByNumber[k];

    // 2차: 끝 10/9자리
    final last10 = _suffixDigits(k, 10);
    final last9 = _suffixDigits(k, 9);
    return contactsByNumber['#10:$last10'] ?? contactsByNumber['#9:$last9'];
  }

  /// flutter_contacts.Contact -> 너의 Contact 모델 변환
  ContactModel _mapFlutterToModel(Contact c) {
    final displayName = c.displayName;

    final yomi = displayName;

    final tels = <String>[];
    for (final p in c.phones) {
      if ((p.number).trim().isNotEmpty) tels.add(p.number.trim());
    }

    final emails = <String>[];
    for (final e in c.emails) {
      if ((e.address).trim().isNotEmpty) emails.add(e.address.trim());
    }

    // 조직/직함 (첫 번째 값 사용)
    String org = '';
    String title = '';
    if (c.organizations.isNotEmpty) {
      org = c.organizations.first.company ?? '';
      title = c.organizations.first.title ?? '';
    }

    // 메모: flutter_contacts는 notes가 계정별로 다름. 안전하게 빈 값 기본.
    final memo = '';

    // 그룹: 첫 번째 그룹 ID 사용 (없으면 빈 문자열)
    String groupId = '';
    if (c.groups.isNotEmpty) {
      groupId = c.groups.first.id;
    }

    return ContactModel(
      name: displayName,
      yomiName: yomi,
      telephones: tels,
      emails: emails,
      oragnization: org, // (철자 원문 그대로)
      titie: title, // (철자 원문 그대로)
      memo: memo,
      groupId: groupId,
      status: 'active', // 커스텀 정책에 맞게 필드 사용
      contactId: c.id,
      contactType: _detectContactType(c),
    );
  }

  /// 간단한 타입 추정 (계정명/소스 기반, 없으면 'device')
  String _detectContactType(Contact c) {
    // flutter_contacts는 account 표기가 플랫폼마다 다름.
    // 안전하게 기본값 'device'로.
    return 'device';
  }

  /// 일본 번호 정규화: 숫자/플러스 외 제거 → '+' 제거 →
  /// 81로 시작하면 유지, 0시작이면 선행0 제거 후 81 접두, 그 외는 그대로
  String _normalizeToDigitsJP(String input) {
    var s = input.replaceAll(RegExp(r'[^0-9\+]'), '');
    if (s.startsWith('+')) s = s.substring(1);

    if (s.startsWith('81')) return s;
    if (s.startsWith('0')) {
      s = s.replaceFirst(RegExp(r'^0+'), '');
      return '81$s';
    }
    return s; // 이미 국제형(다른 국가코드) or 지역 특수 케이스
  }

  String _suffixDigits(String digits, int len) {
    final only = digits.replaceAll(RegExp(r'\D'), '');
    if (only.length < len) return '';
    return only.substring(only.length - len);
  }
}
