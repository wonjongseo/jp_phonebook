import 'package:hive/hive.dart';
import 'package:jg_phonebook/core/constants.dart';
import 'package:jg_phonebook/core/utils/utils.dart';
import 'package:jg_phonebook/services/navite/ios/entity/call_directory_entry.dart';

/// ===============================
/// Hive Repository (단일 소스)
/// ===============================
class LabelRepo {
  static Future<void> init() async {
    if (!Hive.isBoxOpen(labelsBoxName)) {
      await Hive.openBox<String>(labelsBoxName);
    }
  }

  static Box<String> get _box => Hive.box<String>(labelsBoxName);

  static Future<void> seedIfEmpty() async {
    if (_box.isEmpty) {
      await _box.putAll({
        normalizeNumber('08012345678'): '회사A · 영업1팀',
        normalizeNumber('07055608528'): '나야 · 종서',
        normalizeNumber('0312345678'): '고객센터',
        normalizeNumber('0120123456'): '협력사 B 담당자',
      });
    }
  }

  static Future<void> put(String number, String label) async {
    await _box.put(normalizeNumber(number), label);
  }

  static Future<void> remove(String number) async {
    await _box.delete(normalizeNumber(number));
  }

  static List<CallDirectoryEntry> all() {
    return _box.keys.map((k) {
      final key = k.toString();
      final v = _box.get(key) ?? '';
      return CallDirectoryEntry(number: key, label: v);
    }).toList();
  }

  /// 안드로이드 헤드리스 조회에서 사용: 정규화→정확 일치→뒤 8자리 느슨 매칭
  static String? lookupLabel(String rawNumber) {
    final key = normalizeNumber(rawNumber);
    final hit = _box.get(key);
    if (hit != null && hit.isNotEmpty) return hit;

    final tail = key.length >= 8 ? key.substring(key.length - 8) : key;
    for (final k in _box.keys) {
      final s = k.toString();
      if (s.endsWith(tail)) {
        final v = _box.get(s);
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }
}
