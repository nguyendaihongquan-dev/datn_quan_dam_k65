import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ev_charging_station/bloc/mqtt/mqtt_bloc.dart';
import 'package:ev_charging_station/bloc/mqtt/mqtt_event.dart';
import 'package:ev_charging_station/bloc/mqtt/mqtt_state.dart';
import 'package:ev_charging_station/bloc/relay/relay_bloc.dart';
import 'package:ev_charging_station/bloc/relay/relay_event.dart';
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
    _isConnecting = true;
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
    if (!mounted) return;
    setState(() {
      _latest = null;
      _isUsingDefaultData = true;
      _powerHistory.clear();
    });
  }

  void _switchToDefaultData() {
    _cancelDataTimeout();
    setState(() {
      _latest = null;
      _isUsingDefaultData = true;
      _powerHistory.clear();
    });
  }

  void _applyElectricData(ElectricData data) {
    _cancelDataTimeout();
    setState(() {
      _latest = data;
      _isUsingDefaultData = false;
      _powerHistory.add(FlSpot(_powerHistory.length.toDouble(), data.power));
      if (_powerHistory.length > 30) {
        _powerHistory.removeAt(0);
        for (int i = 0; i < _powerHistory.length; i++) {
          _powerHistory[i] = FlSpot(i.toDouble(), _powerHistory[i].y);
        }
      }
    });
    _startDataTimeout();
  }

  void _handleMqttState(MqttState state) {
    if (state is MqttConnecting) {
      _cancelDataTimeout();
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
      _startDataTimeout();
    } else if (state is MqttDisconnected) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _switchToDefaultData();
    } else if (state is MqttError) {
      setState(() {
        _error = state.message;
        _isConnecting = false;
      });
      _switchToDefaultData();
    } else if (state is MqttMessageReceived && _isElectricTopic(state.topic)) {
      try {
        final data = ElectricData.fromJson(
          json.decode(state.message) as Map<String, dynamic>,
        );
        _applyElectricData(data);
      } catch (_) {}
    }
  }

  bool get _hasLiveData => _latest != null && !_isUsingDefaultData;

  bool _isChargingFor(ElectricData data) => _hasLiveData && data.isCharging;

  bool _hasAlarmFor(ElectricData data) => _hasLiveData && data.hasAlarm;

  bool _isElectricTopic(String topic) {
    final normalized = topic.replaceFirst(RegExp(r'^/'), '');
    return normalized == MqttService.dataTopic;
  }

  Color get _statusColor {
    if (!_hasLiveData) {
      return AppColors.textSecondary;
    }
    final data = _latest!;
    if (data.hasAlarm) return AppColors.warning;
    if (data.isCharging) return AppColors.primary;
    return AppColors.textSecondary;
  }

  Future<void> _handleRefresh() async {
    final mqttBloc = context.read<MqttBloc>();
    context.read<RelayBloc>().add(const RelayInitEvent());

    final refreshFuture = mqttBloc.stream
        .firstWhere((state) => state is MqttConnected || state is MqttError)
        .timeout(const Duration(seconds: 12));

    mqttBloc.add(const MqttReconnectEvent());

    try {
      await refreshFuture;
    } catch (_) {
      // Hết thời gian chờ — vẫn kết thúc indicator.
    }

    if (!mounted) return;
    if (_latest == null) {
      _startDataTimeout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MqttBloc, MqttState>(
      listener: (context, state) => _handleMqttState(state),
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            strokeWidth: 2.5,
            onRefresh: _handleRefresh,
            child: _buildDashboard(),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectingBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Đang kết nối MQTT...',
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final data = _latest ?? ElectricData.placeholder();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Energy Monitoring',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ConnectionStatus(
                isConnected: _isConnected,
                isConnecting: _isConnecting,
                error: _error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isConnecting && !_isConnected) _buildConnectingBanner(),
        if (_isUsingDefaultData) _buildDefaultDataBanner(),
        if (_hasAlarmFor(data)) _buildAlarmBanner(),
        // Container(
        //   width: double.infinity,
        //   padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        //   decoration: BoxDecoration(
        //     gradient: LinearGradient(
        //       begin: Alignment.topLeft,
        //       end: Alignment.bottomRight,
        //       colors: [
        //         AppColors.surface,
        //         AppColors.surfaceLight.withValues(alpha: 0.5),
        //       ],
        //     ),
        //     borderRadius: BorderRadius.circular(24),
        //     border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
        //   ),
        //   child: Column(
        //     children: [
        //       // ChargingStationAnimation(
        //       //   isCharging: _isChargingFor(data),
        //       //   hasAlarm: _hasAlarmFor(data),
        //       // ),
        //       const SizedBox(height: 8),
        //       // Row(
        //       //   mainAxisAlignment: MainAxisAlignment.center,
        //       //   children: [
        //       //     Container(
        //       //       width: 10,
        //       //       height: 10,
        //       //       decoration: BoxDecoration(
        //       //         color: _statusColor,
        //       //         shape: BoxShape.circle,
        //       //         boxShadow: [
        //       //           BoxShadow(
        //       //             color: _statusColor.withValues(alpha: 0.5),
        //       //             blurRadius: 8,
        //       //           ),
        //       //         ],
        //       //       ),
        //       //     ),
        //       //     const SizedBox(width: 8),
        //       //     // Text(
        //       //     //   !_hasLiveData ? 'Không có dữ liệu' : data.statusLabel,
        //       //     //   style: TextStyle(
        //       //     //     color: _statusColor,
        //       //     //     fontSize: 16,
        //       //     //     fontWeight: FontWeight.w600,
        //       //     //   ),
        //       //     // ),
        //       //   ],
        //       // ),
        //     ],
        //   ),
        // ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 340 ? 2 : 3;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 2 ? 1.35 : 0.9,
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
                  value: data.power.toStringAsFixed(1),
                  unit: 'W',
                  icon: Icons.speed,
                ),
                MetricCard(
                  label: 'Tần số',
                  value: data.frequency.toStringAsFixed(1),
                  unit: 'Hz',
                  icon: Icons.waves,
                ),
                MetricCard(
                  label: 'Hệ số công suất',
                  value: data.pf.toStringAsFixed(2),
                  unit: 'PF',
                  icon: Icons.power,
                ),
                MetricCard(
                  label: 'Nhiệt độ',
                  value: data.temperature.toStringAsFixed(1),
                  unit: '°C',
                  icon: Icons.thermostat,
                  accentColor: AppColors.warning,
                ),
                MetricCard(
                  label: 'Độ ẩm',
                  value: data.humidity.toStringAsFixed(1),
                  unit: '%',
                  icon: Icons.water_drop_outlined,
                  accentColor: AppColors.accent,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildDeviceTimeCard(data),
        const SizedBox(height: 16),
        _buildStatusCard(data),
        const SizedBox(height: 16),
        _buildEnergyCard(data),
        const SizedBox(height: 16),
        const RelayControlCard(),
        const SizedBox(height: 16),
        PowerChart(spots: List.from(_powerHistory)),
        const SizedBox(height: 32),
      ],
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

  Widget _buildDeviceTimeCard(ElectricData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.schedule, color: AppColors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasLiveData && data.rtcValid != 0
                      ? 'Thời gian thiết bị'
                      : 'Thời gian thiết bị (RTC chưa hợp lệ)',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.dateLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.timeLabel,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ElectricData data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildStatusChip('WiFi', data.wifi != 0),
          _buildStatusChip('MQTT', data.mqttConnected != 0),
          _buildStatusChip('PZEM', data.pzemValid != 0),
          _buildStatusChip('DHT', data.dhtValid != 0),
          _buildStatusChip('RTC', data.rtcValid != 0),
          _buildStatusChip('Relay', data.relayOn, activeLabel: 'Bật'),
          if (data.temperatureAlarm != 0)
            _buildStatusChip('Nhiệt độ', true, activeLabel: 'Cảnh báo'),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isActive, {String? activeLabel}) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: ${isActive ? (activeLabel ?? 'OK') : 'OFF'}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${data.energy.toStringAsFixed(3)} kWh',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Cập nhật',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    data.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
