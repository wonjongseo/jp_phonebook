// lib/common/widget/app_lifecycle_listener.dart
import 'package:flutter/widgets.dart';

class CAppLifecycleListener extends StatefulWidget {
  final VoidCallback onResumed;
  final Widget child;
  const CAppLifecycleListener({
    super.key,
    required this.onResumed,
    required this.child,
  });

  @override
  State<CAppLifecycleListener> createState() => _CAppLifecycleListenerState();
}

class _CAppLifecycleListenerState extends State<CAppLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onResumed();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
