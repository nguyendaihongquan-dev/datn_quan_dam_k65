import 'package:equatable/equatable.dart';

abstract class RelayState extends Equatable {
  const RelayState();

  @override
  List<Object?> get props => [];
}

class RelayInitial extends RelayState {}

class RelayLoading extends RelayState {}

class RelayReady extends RelayState {
  final bool isOn;
  final bool isSyncing;
  final String? error;
  final String updatedBy;

  const RelayReady({
    required this.isOn,
    this.isSyncing = false,
    this.error,
    this.updatedBy = 'init',
  });

  RelayReady copyWith({
    bool? isOn,
    bool? isSyncing,
    String? error,
    String? updatedBy,
    bool clearError = false,
  }) {
    return RelayReady(
      isOn: isOn ?? this.isOn,
      isSyncing: isSyncing ?? this.isSyncing,
      error: clearError ? null : (error ?? this.error),
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [isOn, isSyncing, error, updatedBy];
}
