import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ev_charging_station/bloc/mqtt/mqtt_bloc.dart';
import 'package:ev_charging_station/bloc/mqtt/mqtt_state.dart';
import 'package:ev_charging_station/models/electric_data.dart';
import 'package:ev_charging_station/services/mqtt_service.dart';
import 'package:ev_charging_station/theme/app_theme.dart';
import 'package:ev_charging_station/widgets/charging_station_animation.dart';
import 'package:ev_charging_station/widgets/connection_status.dart';
import 'package:ev_charging_station/widgets/metric_card.dart';
import 'package:ev_charging_station/widgets/power_chart.dart';
import 'package:ev_charging_station/widgets/relay_control_card.dart';

class ChargingHomeScreen extends StatefulWidget {
  const ChargingHomeScreen({super.key});

  @override
  State<ChargingHomeScreen> createState() => _ChargingHomeScreenState();
}

class _ChargingHomeScreenState extends State<ChargingHomeScreen> {
  static const _dataTimeout = Duration(seconds: 15);

  ElectricData? _latest;
  final List<FlSpot> _powerHistory = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;
  bool _isUsingDefaultData = false;
  Timer? _dataTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _startDataTimeout();
  }

  @override
  void dispose() {
    _dataTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startDataTimeout() {
    _dataTimeoutTimer?.cancel();
    _dataTimeoutTimer = Timer(_dataTimeout, _onDataTimeout);
  }

  void _cancelDataTimeout() {
    _dataTimeoutTimer?.cancel();
    _dataTimeoutTimer = null;
  }

  void _onDataTimeout() {
    if (!mounted || _latest != null) return;
    setState(() => _isUsingDefaultData = true);
  }

  void _switchToDefaultData() {
    if (_latest != null) return;
    _cancelDataTimeout();
    setState(() => _isUsingDefaultData = true);
  }

  void _handleMqttState(MqttState state) {
    if (state is MqttConnecting) {
      setState(() {
        _isConnecting = true;
        _error = null;
      });
    } else if (state is MqttConnected) {
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _error = null;
      });
    } else if (state is MqttDisconnected) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
    } else if (state is MqttError) {
      setState(() {
        _error = state.message;
        _isConnecting = false;
      });
      _switchToDefaultData();
    } else if (state is MqttMessageReceived &&
        state.topic == MqttService.dataTopic) {
      try {
        final data = ElectricData.fromJson(
          json.decode(state.message) as Map<String, dynamic>,
        );
        _cancelDataTimeout();
        setState(() {
          _latest = data;
          _isUsingDefaultData = false;
          _powerHistory.add(
            FlSpot(_powerHistory.length.toDouble(), data.power),
          );
          if (_powerHistory.length > 30) {
            _powerHistory.removeAt(0);
            for (int i = 0; i < _powerHistory.length; i++) {
              _powerHistory[i] = FlSpot(i.toDouble(), _powerHistory[i].y);
            }
          }
        });
      } catch (_) {}
    }
  }

  Color get _statusColor {
    if (_isUsingDefaultData && _latest == null) {
      return AppColors.textSecondary;
    }
    final data = _latest ?? ElectricData.placeholder();
    if (data.hasAlarm) return AppColors.warning;
    if (data.isCharging) return AppColors.primary;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MqttBloc, MqttState>(
      listener: (context, state) => _handleMqttState(state),
      child: Scaffold(
        body: SafeArea(
          child: _latest == null && !_isUsingDefaultData
              ? _buildLoading()
              : _buildDashboard(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isConnecting ? 'Đang kết nối MQTT...' : 'Chờ dữ liệu từ trạm sạc',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ConnectionStatus(
            isConnected: _isConnected,
            isConnecting: _isConnecting,
            error: _error,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final data = _latest ?? ElectricData.placeholder();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EV Charging',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Trạm sạc năng lượng',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              ConnectionStatus(
                isConnected: _isConnected,
                isConnecting: _isConnecting,
                error: _error,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isUsingDefaultData) _buildDefaultDataBanner(),
          if (data.hasAlarm) _buildAlarmBanner(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface,
                  AppColors.surfaceLight.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                ChargingStationAnimation(
                  isCharging: data.isCharging,
                  hasAlarm: data.hasAlarm,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUsingDefaultData
                          ? 'Không có dữ liệu'
                          : data.statusLabel,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: [
              MetricCard(
                label: 'Điện áp',
                value: data.voltage.toStringAsFixed(1),
                unit: 'V',
                icon: Icons.bolt,
                accentColor: AppColors.accent,
              ),
              MetricCard(
                label: 'Dòng điện',
                value: data.current.toStringAsFixed(2),
                unit: 'A',
                icon: Icons.electric_bolt,
              ),
              MetricCard(
                label: 'Công suất',
                value: data.power.toStringAsFixed(2),
                unit: 'kW',
                icon: Icons.speed,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEnergyCard(data),
          const SizedBox(height: 16),
          const RelayControlCard(),
          const SizedBox(height: 16),
          PowerChart(spots: List.from(_powerHistory)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDefaultDataBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error != null
                  ? 'Không kết nối được MQTT. Đang hiển thị dữ liệu mặc định.'
                  : 'Không nhận được dữ liệu trong ${_dataTimeout.inSeconds}s. Đang hiển thị giao diện mặc định.',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.95),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cảnh báo: Phát hiện sự cố trên hệ thống sạc!',
              style: TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyCard(ElectricData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2332), Color(0xFF0F1923)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.energy_savings_leaf,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Năng lượng tiêu thụ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.energy.toStringAsFixed(3)} kWh',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Cập nhật',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              Text(
                data.timeLabel,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
