import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ev_charging_station/theme/app_theme.dart';

class ChargingStationAnimation extends StatefulWidget {
  final bool isCharging;
  final bool hasAlarm;

  const ChargingStationAnimation({
    super.key,
    required this.isCharging,
    this.hasAlarm = false,
  });

  @override
  State<ChargingStationAnimation> createState() =>
      _ChargingStationAnimationState();
}

class _ChargingStationAnimationState extends State<ChargingStationAnimation>
    with TickerProviderStateMixin {
  late AnimationController _flowController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isCharging) {
      _flowController.repeat();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChargingStationAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCharging && !oldWidget.isCharging) {
      _flowController.repeat();
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCharging && oldWidget.isCharging) {
      _flowController.stop();
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _flowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color get _accentColor =>
      widget.hasAlarm ? AppColors.warning : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flowController, _pulseAnimation]),
        builder: (context, child) {
          return CustomPaint(
            painter: _ElectricityFlowPainter(
              progress: _flowController.value,
              isActive: widget.isCharging,
              color: _accentColor,
              pulse: _pulseAnimation.value,
            ),
            child: child,
          );
        },
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSourceIcon(),
              const SizedBox(width: 60),
              _buildStationIcon(),
              const SizedBox(width: 60),
              _buildBatteryIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
          ),
          child: const Icon(Icons.electrical_services, color: AppColors.accent),
        ),
        const SizedBox(height: 6),
        const Text(
          'Lưới điện',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildStationIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _accentColor.withValues(
                alpha: widget.isCharging ? 0.8 : 0.3,
              ),
              width: 2,
            ),
            boxShadow: widget.isCharging
                ? [
                    BoxShadow(
                      color: _accentColor.withValues(
                        alpha: 0.3 * _pulseAnimation.value,
                      ),
                      blurRadius: 24 * _pulseAnimation.value,
                      spreadRadius: 4 * _pulseAnimation.value,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.ev_station,
            color: _accentColor,
            size: 36,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Trạm sạc',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBatteryIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: _accentColor.withValues(
                alpha: widget.isCharging ? 0.6 : 0.3,
              ),
            ),
          ),
          child: Icon(
            widget.isCharging
                ? Icons.battery_charging_full
                : Icons.battery_std,
            color: _accentColor,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pin xe',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _ElectricityFlowPainter extends CustomPainter {
  final double progress;
  final bool isActive;
  final Color color;
  final double pulse;

  _ElectricityFlowPainter({
    required this.progress,
    required this.isActive,
    required this.color,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) {
      _drawIdleLine(canvas, size);
      return;
    }

    final centerY = size.height / 2;
    final leftX = size.width * 0.18;
    final midX = size.width * 0.5;
    final rightX = size.width * 0.82;

    final path1 = Path()
      ..moveTo(leftX + 28, centerY)
      ..quadraticBezierTo(
        (leftX + midX) / 2,
        centerY - 30,
        midX,
        centerY,
      );

    final path2 = Path()
      ..moveTo(midX, centerY)
      ..quadraticBezierTo(
        (midX + rightX) / 2,
        centerY + 30,
        rightX - 28,
        centerY,
      );

    _drawAnimatedPath(canvas, path1);
    _drawAnimatedPath(canvas, path2);
  }

  void _drawIdleLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.surfaceLight
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    canvas.drawLine(
      Offset(size.width * 0.22, centerY),
      Offset(size.width * 0.78, centerY),
      paint,
    );
  }

  void _drawAnimatedPath(Canvas canvas, Path path) {
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, basePaint);

    for (int i = 0; i < 3; i++) {
      final offset = (progress + i * 0.33) % 1.0;
      final metric = path.computeMetrics().first;
      final tangent = metric.getTangentForOffset(metric.length * offset);
      if (tangent == null) continue;

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.9 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(tangent.position, 4, glowPaint);

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(tangent.position, 2, dotPaint);
    }

    final dashPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.8),
          Colors.transparent,
        ],
        stops: [
          math.max(0, progress - 0.15),
          progress,
          math.min(1, progress + 0.15),
        ],
      ).createShader(Rect.fromLTWH(0, 0, 400, 200))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, dashPaint);
  }

  @override
  bool shouldRepaint(covariant _ElectricityFlowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isActive != isActive ||
      oldDelegate.color != color ||
      oldDelegate.pulse != pulse;
}
