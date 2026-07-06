import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ev_charging_station/bloc/relay/relay_bloc.dart';
import 'package:ev_charging_station/bloc/relay/relay_event.dart';
import 'package:ev_charging_station/bloc/relay/relay_state.dart';
import 'package:ev_charging_station/theme/app_theme.dart';

class RelayControlCard extends StatelessWidget {
  const RelayControlCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RelayBloc, RelayState>(
      builder: (context, state) {
        if (state is! RelayReady) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surface,
                AppColors.surfaceLight.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: state.isOn
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (state.isOn ? AppColors.primary : AppColors.textSecondary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      color: state.isOn ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Điều khiển Relay',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          state.isSyncing
                              ? 'Đang đồng bộ...'
                              : 'Nguồn: ${state.updatedBy}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.isSyncing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _RelayButton(
                      label: 'Tắt',
                      icon: Icons.power_off_rounded,
                      isActive: !state.isOn,
                      activeColor: AppColors.textSecondary,
                      onTap: state.isSyncing
                          ? null
                          : () => context
                              .read<RelayBloc>()
                              .add(const RelayToggleEvent(false)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RelayButton(
                      label: 'Bật',
                      icon: Icons.bolt_rounded,
                      isActive: state.isOn,
                      activeColor: AppColors.primary,
                      onTap: state.isSyncing
                          ? null
                          : () => context
                              .read<RelayBloc>()
                              .add(const RelayToggleEvent(true)),
                    ),
                  ),
                ],
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RelayButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;

  const _RelayButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? activeColor.withValues(alpha: 0.15)
          : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.5)
                  : AppColors.textSecondary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isActive ? activeColor : AppColors.textSecondary),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
