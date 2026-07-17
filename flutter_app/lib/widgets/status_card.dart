import 'package:flutter/material.dart';

import '../utils/status_helper.dart';

/// Card monitoring status (UNKNOWN / NORMAL / NOISE / DANGER / OFFLINE).
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.status,
    this.isAcknowledged = false,
  });

  final String status;
  final bool isAcknowledged;

  @override
  Widget build(BuildContext context) {
    final color = isAcknowledged
        ? const Color(0xFF546E7A)
        : StatusHelper.color(status);
    final soft = isAcknowledged
        ? const Color(0xFFECEFF1)
        : StatusHelper.softColor(status);
    final icon = isAcknowledged
        ? Icons.verified_user
        : StatusHelper.icon(status);
    final title = isAcknowledged ? 'ACKNOWLEDGED' : StatusHelper.title(status);
    final subtitle = isAcknowledged
        ? 'Alarm dihentikan sementara. Tetap waspada.'
        : StatusHelper.subtitle(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              icon,
              key: ValueKey('$status-$isAcknowledged'),
              size: 72,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              title,
              key: ValueKey('title-$title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: color.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isAcknowledged ? 'ACK' : StatusHelper.label(status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
