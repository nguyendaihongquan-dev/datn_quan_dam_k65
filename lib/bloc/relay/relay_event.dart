import 'package:equatable/equatable.dart';

abstract class RelayEvent extends Equatable {
  const RelayEvent();

  @override
  List<Object?> get props => [];
}

class RelayInitEvent extends RelayEvent {
  const RelayInitEvent();
}

class RelayToggleEvent extends RelayEvent {
  final bool isOn;

  const RelayToggleEvent(this.isOn);

  @override
  List<Object?> get props => [isOn];
}

class RelaySyncEvent extends RelayEvent {
  final bool isOn;
  final String updatedBy;

  const RelaySyncEvent({required this.isOn, required this.updatedBy});

  @override
  List<Object?> get props => [isOn, updatedBy];
}
