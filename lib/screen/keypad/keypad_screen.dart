// lib/feature/dialpad/view/dial_pad_page.dart
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:get/get.dart';
import 'package:jg_phonebook/controller/local_contact_controller.dart';

// ▼ 추가: 연락처 컨트롤러/모델 import
import 'package:jg_phonebook/models/contact.dart';

class DialPadController extends GetxController {
  final RxString _raw = ''.obs;
  String get raw => _raw.value;
  String get display => _formatForDisplay(_raw.value);

  // ▼ 추가: 실시간 번호 매칭 결과 (상위 n개)
  final RxList<_NumberMatch> suggestions = <_NumberMatch>[].obs;
  static const int _maxSuggestions = 6;

  @override
  void onInit() {
    super.onInit();
    ever<String>(_raw, (_) => _updateSuggestions());
  }

  void input(String s) {
    HapticFeedback.lightImpact();
    _raw.value += s;
  }

  void backspace({bool all = false}) {
    if (_raw.isEmpty) return;
    HapticFeedback.selectionClick();
    if (all) {
      _raw.value = '';
    } else {
      _raw.value = _raw.substring(0, _raw.value.length - 1);
    }
  }

  // ▼ 추가: 제안에서 탭하면 번호 채우기
  void fillFromSuggestion(String phoneDigits) {
    // 숫자/플러스만 허용 (direct caller는 보통 숫자만 추천)
    _raw.value = _digitsOnly(phoneDigits);
  }

  Future<void> call() async {
    if (_raw.isEmpty) return;
    // FlutterPhoneDirectCaller는 'tel:' 프리픽스 없이 **번호만** 넘기는 것을 권장
    final number = _digitsOnly(_raw.value);
    bool? res = await FlutterPhoneDirectCaller.callNumber(number);
    print('res : $res');
  }

  // ======== 실시간 매칭 로직 ========
  Future<void> _updateSuggestions() async {
    final queryDigits = _digitsOnly(_raw.value);
    suggestions.clear();

    if (queryDigits.isEmpty) return;
    // LocalContactController는 앱 시작 시 바인딩되어 있다고 가정
    final cc = Get.find<LocalContactController>();
    final results = <_NumberMatch>[];

    // 간단/안전한 방식: 전체 연락처 순회하며 번호 중 하나라도 queryDigits를 포함하면 매칭
    for (final c in cc.contacts) {
      for (final rawPhone in c.telephones) {
        final norm = _normalizeToDigitsJP(rawPhone);
        final normDigits = _digitsOnly(norm);
        // 비교 규칙:
        // - 전체 포함(contains)
        // - 끝자리 일치(endsWith) 가중치 ↑
        if (normDigits.contains(queryDigits)) {
          final score = normDigits.endsWith(queryDigits) ? 2 : 1;
          results.add(
            _NumberMatch(
              contact: c,
              matchedDigits: normDigits,
              score: score,
              rawShown: rawPhone,
            ),
          );
          break; // 한 연락처에서 하나만 등록
        }
      }
      if (results.length >= 1000) break; // 과도한 순회 방지 (옵션)
    }

    // 정렬: 끝자리 일치 우선 → 이름 오름차순
    results.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      return (a.contact.name).compareTo(b.contact.name);
    });

    // 상위 N개만 표시
    suggestions.addAll(results.take(_maxSuggestions));
  }

  // ======== 유틸 ========
  String _formatForDisplay(String digits) => digits;

  String _digitsOnly(String s) {
    // *와 #는 검색/전화에 방해되므로 제거 (원하면 유지해도 됨)
    return s.replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', '');
  }

  /// 일본 기본 가정:
  /// - 숫자/플러스 외 제거 → '+' 제거 → 81로 시작하면 유지
  /// - 0으로 시작하면 선행 0 제거 후 '81' 접두
  /// - 그 외는 있는 그대로 숫자 유지
  String _normalizeToDigitsJP(String input) {
    var s = input.replaceAll(RegExp(r'[^0-9\+]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('81')) return s;
    if (s.startsWith('0')) {
      s = s.replaceFirst(RegExp(r'^0+'), '');
      return '81$s';
    }
    return s;
  }
}

// 제안 리스트용 값 객체
class _NumberMatch {
  final ContactModel contact;
  final String matchedDigits; // 정규화된 숫자(81...)
  final String rawShown; // UI 서브타이틀에 보여줄 원본 번호
  final int score; // 2: endsWith, 1: contains
  _NumberMatch({
    required this.contact,
    required this.matchedDigits,
    required this.rawShown,
    required this.score,
  });
}

class KeypadScreen extends GetView<DialPadController> {
  const KeypadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: const _Body(isIOS: false));
  }
}

class _Body extends StatelessWidget {
  final bool isIOS;
  const _Body({required this.isIOS});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DialPadController());
    final safe = MediaQuery.of(context).padding;

    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Obx(() {
                final canDelete = controller.raw.isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 120),
                          style: TextStyle(
                            fontSize: isIOS ? 36 : 32,
                            fontWeight:
                                isIOS ? FontWeight.w300 : FontWeight.w400,
                            letterSpacing: 0.5,

                            color:
                                isIOS
                                    ? CupertinoColors.label.resolveFrom(context)
                                    : Theme.of(context).colorScheme.onSurface,
                          ),
                          child: Text(
                            controller.display.isEmpty
                                ? ' '
                                : controller.display,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      if (canDelete)
                        _AdaptiveIconButton(
                          isIOS: isIOS,
                          icon:
                              isIOS
                                  ? CupertinoIcons.delete_left
                                  : Icons.backspace_outlined,
                          onPressed: () => controller.backspace(),
                          onLongPress: () => controller.backspace(all: true),
                          tooltip: '지우기',
                        ),
                    ],
                  ),
                );
              }),

              Obx(() {
                final items = controller.suggestions;
                if (items.isEmpty) return const SizedBox(height: 4);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (isIOS
                              ? CupertinoColors.secondarySystemGroupedBackground
                              : Theme.of(context).colorScheme.surfaceVariant)
                          .withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            color:
                                isIOS
                                    ? CupertinoColors.separator.resolveFrom(
                                      context,
                                    )
                                    : Theme.of(
                                      context,
                                    ).dividerColor.withOpacity(0.6),
                          ),
                      itemBuilder: (_, i) {
                        final m = items[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            child: Text(
                              (m.contact.name.isNotEmpty
                                      ? m.contact.name.characters.first
                                      : '#')
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(
                            m.contact.name.isNotEmpty
                                ? m.contact.name
                                : m.rawShown,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            m.rawShown, // 원본 형태의 번호 한 줄
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isIOS ? CupertinoIcons.phone_fill : Icons.call,
                              color:
                                  isIOS
                                      ? CupertinoColors.activeGreen
                                      : Colors.green,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              controller.fillFromSuggestion(m.rawShown);
                            },
                            tooltip: '이 번호 사용',
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.fillFromSuggestion(m.rawShown);
                          },
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          ), // 키패드
          Column(
            children: [
              _DialPadGrid(isIOS: isIOS),

              // 하단 액션 (통화 버튼)
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 12 + safe.bottom),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallButton(isIOS: isIOS, onPressed: controller.call),
                    // _AdaptiveIconButton(
                    //   isIOS: isIOS,
                    //   icon:
                    //       isIOS
                    //           ? CupertinoIcons.person_crop_circle_badge_plus
                    //           : Icons.person_add_alt_1,
                    //   onPressed: () {
                    //     HapticFeedback.selectionClick();
                    //   },
                    //   tooltip: '연락처에 추가',
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialPadGrid extends StatelessWidget {
  final bool isIOS;
  const _DialPadGrid({required this.isIOS});

  @override
  Widget build(BuildContext context) {
    final items = <_KeySpec>[
      _KeySpec('1', ''),
      _KeySpec('2', 'ABC'),
      _KeySpec('3', 'DEF'),
      _KeySpec('4', 'GHI'),
      _KeySpec('5', 'JKL'),
      _KeySpec('6', 'MNO'),
      _KeySpec('7', 'PQRS'),
      _KeySpec('8', 'TUV'),
      _KeySpec('9', 'WXYZ'),
      _KeySpec('*', ''),
      _KeySpec('0', '+'),
      _KeySpec('#', ''),
    ];

    return Container(
      height: 320,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (_, i) => _KeyButton(isIOS: isIOS, spec: items[i]),
        ),
      ),
    );
  }
}

class _KeySpec {
  final String main;
  final String sub; // T9 문자 또는 보조 의미(0 길게 누르면 +)
  const _KeySpec(this.main, this.sub);
}

class _KeyButton extends StatelessWidget {
  final bool isIOS;
  final _KeySpec spec;
  const _KeyButton({required this.isIOS, required this.spec});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<DialPadController>();
    final onTap = () => c.input(spec.main);
    final onLong = () {
      if (spec.main == '0' && spec.sub == '+') {
        c.input('+');
      }
    };

    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          spec.main,
          style: TextStyle(
            fontSize: isIOS ? 34 : 32,
            fontWeight: isIOS ? FontWeight.w300 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        if (spec.sub.isNotEmpty)
          Text(
            spec.sub,
            style: TextStyle(
              fontSize: isIOS ? 12 : 11,
              fontWeight: FontWeight.w500,
              color:
                  isIOS
                      ? CupertinoColors.secondaryLabel.resolveFrom(context)
                      : Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.7),
              letterSpacing: 1.0,
            ),
          ),
      ],
    );

    if (isIOS) {
      // iOS 느낌: 얇은 외곽선의 원형 버튼 + 투명도 살짝
      return _CupertinoCircleButton(
        onPressed: onTap,
        onLongPress: onLong,
        child: child,
      );
    } else {
      // Android 느낌: 머티리얼 잉크 리플의 원형 버튼
      return _MaterialCircleButton(
        onPressed: onTap,
        onLongPress: onLong,
        child: child,
      );
    }
  }
}

class _CupertinoCircleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  const _CupertinoCircleButton({
    required this.onPressed,
    this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final border = Border.all(
      color: CupertinoColors.separator.resolveFrom(context),
      width: 1,
    );
    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
          color: CupertinoColors.systemFill
              .resolveFrom(context)
              .withOpacity(0.15),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _MaterialCircleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  const _MaterialCircleButton({
    required this.onPressed,
    this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withOpacity(0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        onLongPress: onLongPress,
        child: Center(child: child),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final bool isIOS;
  final VoidCallback onPressed;
  const _CallButton({required this.isIOS, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final size = 60.0;
    final icon = isIOS ? CupertinoIcons.phone_fill : Icons.call;
    final color = isIOS ? CupertinoColors.activeGreen : Colors.green;

    final child = Icon(icon, color: Colors.white, size: 28);

    return SizedBox(
      width: size,
      height: size,
      child:
          isIOS
              ? ClipOval(
                child: CupertinoButton.filled(
                  padding: EdgeInsets.zero,
                  onPressed: onPressed,
                  child: child,
                ),
              )
              : RawMaterialButton(
                onPressed: onPressed,
                elevation: 2,
                fillColor: color,
                shape: const CircleBorder(),
                child: child,
              ),
    );
  }
}

class _AdaptiveIconButton extends StatelessWidget {
  final bool isIOS;
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;

  const _AdaptiveIconButton({
    required this.isIOS,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          icon,
          size: isIOS ? 26 : 24,
          color:
              isIOS
                  ? CupertinoColors.secondaryLabel.resolveFrom(context)
                  : Theme.of(context).iconTheme.color,
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
