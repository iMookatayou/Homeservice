// lib/widgets/toast.dart
import 'dart:collection';
import 'package:flutter/material.dart';

enum ToastType { success, error, info }

class AppToast {
  AppToast._();

  static final _queue = Queue<_ToastRequest>();
  static bool _isShowing = false;

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    _enqueue(context, message, ToastType.success, duration);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    _enqueue(context, message, ToastType.error, duration);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 1600),
  }) {
    _enqueue(context, message, ToastType.info, duration);
  }

  static void _enqueue(
    BuildContext context,
    String message,
    ToastType type,
    Duration duration,
  ) {
    _queue.add(_ToastRequest(context, message, type, duration));
    if (!_isShowing) _tryShowNext();
  }

  static void _tryShowNext() async {
    if (_queue.isEmpty) return;
    _isShowing = true;

    final req = _queue.removeFirst();
    final overlay = Overlay.of(req.context, rootOverlay: true);
    if (overlay == null) {
      _isShowing = false;
      _tryShowNext();
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      opaque: false,
      builder: (_) => _ToastEntry(
        message: req.message,
        type: req.type,
        duration: req.duration,
        onCompleted: () {
          entry.remove();
          _isShowing = false;
          _tryShowNext();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastRequest {
  final BuildContext context;
  final String message;
  final ToastType type;
  final Duration duration;
  _ToastRequest(this.context, this.message, this.type, this.duration);
}

class _ToastEntry extends StatefulWidget {
  const _ToastEntry({
    required this.message,
    required this.type,
    required this.duration,
    required this.onCompleted,
  });

  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onCompleted;

  @override
  State<_ToastEntry> createState() => _ToastEntryState();
}

class _ToastEntryState extends State<_ToastEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = Tween(begin: 0.92, end: 1.0).animate(
    CurvedAnimation(
      parent: _ac,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    ),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    _show();
  }

  Future<void> _show() async {
    await _ac.forward();
    await Future.delayed(widget.duration);
    if (mounted) {
      await _ac.reverse();
      widget.onCompleted();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = switch (widget.type) {
      ToastType.success => (
        Icons.check_circle_rounded,
        const Color(0xFF16A34A),
      ), // green-600
      ToastType.error => (
        Icons.error_rounded,
        const Color(0xFFDC2626),
      ), // red-600
      ToastType.info => (
        Icons.info_rounded,
        const Color(0xFF2563EB),
      ), // blue-600
    };

    // Government-clean style: การ์ดขาว ขอบจาง เงานุ่ม
    return IgnorePointer(
      ignoring: true,
      child: SafeArea(
        child: Stack(
          children: [
            // ใส่เลเยอร์โปร่งแสงเบาๆ ให้โฟกัสที่ข้อความ
            Positioned.fill(child: Container(color: Colors.transparent)),
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Material(
                      elevation: 0,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE7ECF4),
                          ), // cardBorder โทนสะอาด
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 24,
                              spreadRadius: 0,
                              offset: Offset(0, 12),
                              color: Color(0x1A000000),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: tint.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 22, color: tint),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.25,
                                  color: Color(0xFF0F172A), // slate-900
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
