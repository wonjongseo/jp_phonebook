/// 일본 번호 정규화 예시: +81 -> 0, 하이픈/공백 제거
String normalizeNumber(String raw) {
  var n = raw.trim().replaceAll(RegExp(r'[\s\-]'), '');
  if (n.startsWith('+81')) n = '0${n.substring(3)}';
  return n;
}
