import 'dart:async';

import 'package:flutter/material.dart';

Future<void> showBottomPopup(
  BuildContext context, {
  required String message,
  bool isError = false,
  Duration duration = const Duration(seconds: 2),
}) async {
  if (!context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);

  unawaited(
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'popup',
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim1, anim2) {
        return _BottomPopup(
          message: message,
          isError: isError,
        );
      },
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: offset,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    ),
  );

  await Future<void>.delayed(duration);
  if (navigator.canPop()) {
    navigator.pop();
  }
}

class _BottomPopup extends StatelessWidget {
  final String message;
  final bool isError;

  const _BottomPopup({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isError
        ? const Color(0xFFCF222E)
        : (isDark ? const Color(0xFF1F6FEB) : const Color(0xFF0969DA));

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x32000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
