// lib/feature/calllog/view/call_log_tabbed_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:call_log/call_log.dart';
import 'package:jg_phonebook/app_lifecycle_listener.dart';
import 'package:jg_phonebook/controller/call_log_controller.dart';
import 'package:jg_phonebook/core/extenstion/extenstion.dart';
import 'package:jg_phonebook/models/contact.dart';

class CallLogTabbedPage extends GetView<CallLogController> {
  const CallLogTabbedPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('통화기록')),
        body: const Center(child: Text('iOS는 시스템 정책상 통화기록 접근이 불가합니다.')),
      );
    }

    return CAppLifecycleListener(
      onResumed: controller.onAppResumed,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('통화기록'),
            bottom: const TabBar(tabs: [Tab(text: '착신'), Tab(text: '발신')]),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => controller.refreshLogs(full: true),
                tooltip: '전체 새로고침',
              ),
            ],
          ),
          body: Obx(() {
            if (controller.isLoading.isTrue && controller.logs.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.logs.isEmpty) {
              return const Center(child: Text('통화기록이 없습니다.'));
            }

            final incoming =
                controller.logs
                    .where(
                      (e) =>
                          e.callType == CallType.incoming ||
                          e.callType == CallType.missed,
                    )
                    .toList(); // 필요시 missed 제외하려면 조건에서 빼세요

            final outgoing =
                controller.logs
                    .where((e) => e.callType == CallType.outgoing)
                    .toList();

            return TabBarView(
              children: [_buildList(incoming), _buildList(outgoing)],
            );
          }),
        ),
      ),
    );
  }

  // ---------------- UI builders ----------------

  Widget _buildList(List<CallLogEntry> items) {
    if (items.isEmpty) {
      return const Center(child: Text('기록이 없습니다.'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => _buildTile(items[i]),
    );
  }

  Widget _buildTile(CallLogEntry e) {
    final ContactModel? matched = controller.contactOf(e);
    final title = _titleText(e, matched);
    final subtitle = _subtitleText(e, matched);
    final trailing = _trailingWidget(e, matched);
    final icon = _leadingIcon(e.callType);

    return ListTile(
      leading: Icon(icon),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: () {
        // TODO: 상세 페이지 이동 등 필요 시 추가
      },
    );
  }

  Widget _titleText(CallLogEntry e, ContactModel? matched) {
    String primary = '';
    if (matched != null) {
      if (matched.name.isNotEmpty) {
        primary = matched.name;
      }
    } else {
      if (e.name.isNotNull) {
        primary = e.name!;
      } else if (e.formattedNumber.isNotNull) {
        primary = e.formattedNumber!;
      } else if (e.formattedNumber.isNotNull) {
        primary = e.formattedNumber!;
      }
    }

    if (primary.isEmpty) {
      primary = '알 수 없음';
    }
    if (matched != null) {
      return Row(
        children: [
          Expanded(
            child: Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
        ],
      );
    }
    return Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _subtitleText(CallLogEntry e, ContactModel? matched) {
    final ts =
        (e.timestamp != null)
            ? DateTime.fromMillisecondsSinceEpoch(e.timestamp!).toLocal()
            : null;
    final typeLabel = _typeLabel(e.callType);
    final duration = '${e.duration ?? 0}s';

    final parts = <String>[];
    if (matched != null && matched.yomiName.trim().isNotEmpty) {
      parts.add(matched.yomiName.trim());
    }
    parts.add(typeLabel);
    if (ts != null) parts.add(_formatDateTime(ts));
    parts.add(duration);

    return Text(parts.join(' • '));
  }

  Widget _trailingWidget(CallLogEntry e, ContactModel? matched) {
    if (matched != null) {
      final company = matched.oragnization;
      final title = matched.titie;
      final lines = <String>[];
      if (company.isNotEmpty) lines.add(company);
      if (title.isNotEmpty) lines.add(title);

      if (lines.isNotEmpty) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children:
              lines
                  .map(
                    (t) =>
                        Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
                  )
                  .toList(),
        );
      }
    }

    return (e.simDisplayName != null && e.simDisplayName!.isNotEmpty)
        ? Text(e.simDisplayName!, maxLines: 2, textAlign: TextAlign.end)
        : const SizedBox.shrink();
  }

  IconData _leadingIcon(CallType? t) {
    switch (t) {
      case CallType.missed:
        return Icons.call_missed;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.incoming:
      default:
        return Icons.call_received;
    }
  }

  String _typeLabel(CallType? t) {
    switch (t) {
      case CallType.incoming:
        return '수신';
      case CallType.outgoing:
        return '발신';
      case CallType.missed:
        return '부재중';
      case CallType.blocked:
        return '차단';
      case CallType.rejected:
        return '거절';
      default:
        return '기타';
    }
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
