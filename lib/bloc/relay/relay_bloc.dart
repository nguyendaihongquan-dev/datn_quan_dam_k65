import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ev_charging_station/services/relay_service.dart';

import 'relay_event.dart';
import 'relay_state.dart';

class RelayBloc extends Bloc<RelayEvent, RelayState> {
  final RelayService _relayService;
  StreamSubscription? _watchSub;

  RelayBloc({RelayService? relayService})
      : _relayService = relayService ?? RelayService(),
        super(RelayInitial()) {
    on<RelayInitEvent>(_onInit);
    on<RelayToggleEvent>(_onToggle);
    on<RelaySyncEvent>(_onSync);
  }

  Future<void> _onInit(RelayInitEvent event, Emitter<RelayState> emit) async {
    emit(const RelayReady(isOn: false, isSyncing: true));

    try {
      final initial = await _relayService.ensureInitialized();
      emit(RelayReady(isOn: initial.isOn, updatedBy: initial.updatedBy));

      await _watchSub?.cancel();
      _watchSub = _relayService.watchState().listen((model) {
        add(RelaySyncEvent(isOn: model.isOn, updatedBy: model.updatedBy));
      });
    } catch (e) {
      emit(RelayReady(isOn: false, error: e.toString()));
    }
  }

  Future<void> _onToggle(RelayToggleEvent event, Emitter<RelayState> emit) async {
    final current = state;
    if (current is! RelayReady) return;

    emit(current.copyWith(isSyncing: true, clearError: true));

    try {
      await _relayService.setState(event.isOn, source: 'app');
      emit(current.copyWith(
        isOn: event.isOn,
        isSyncing: false,
        updatedBy: 'app',
        clearError: true,
      ));
    } catch (e) {
      emit(current.copyWith(isSyncing: false, error: e.toString()));
    }
  }

  void _onSync(RelaySyncEvent event, Emitter<RelayState> emit) {
    final current = state;
    if (current is RelayReady && !current.isSyncing) {
      if (current.isOn != event.isOn || current.updatedBy != event.updatedBy) {
        emit(current.copyWith(
          isOn: event.isOn,
          updatedBy: event.updatedBy,
          clearError: true,
        ));
      }
    } else if (current is RelayReady && current.isSyncing) {
      emit(current.copyWith(
        isOn: event.isOn,
        updatedBy: event.updatedBy,
      ));
    }
  }

  @override
  Future<void> close() {
    _watchSub?.cancel();
    _relayService.dispose();
    return super.close();
  }
}
