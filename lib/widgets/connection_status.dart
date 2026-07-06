import 'package:flutter/material.dart';
import 'package:ev_charging_station/theme/app_theme.dart';

class ConnectionStatus extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final String? error;

  const ConnectionStatus({
    super.key,
    required this.isConnected,
    this.isConnecting = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final String label;

    if (error != null) {
      dotColor = AppColors.warning;
      label = 'Lỗi kết nối';
    } else if (isConnecting) {
      dotColor = AppColors.accent;
      label = 'Đang kết nối...';
    } else if (isConnected) {
      dotColor = AppColors.primary;
      label = 'MQTT Online';
    } else {
      dotColor = AppColors.textSecondary;
      label = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
