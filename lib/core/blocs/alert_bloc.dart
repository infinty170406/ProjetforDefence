import 'package:flutter/foundation.dart';
import 'behavior_state.dart';

class AlertBloc extends ChangeNotifier {
  static final AlertBloc _instance = AlertBloc._internal();
  factory AlertBloc() => _instance;
  AlertBloc._internal();

  final _alertsStates = <String, BehaviorState<List<Map<String, dynamic>>>>{};

  Stream<List<Map<String, dynamic>>> watchAlerts(String childId) {
    return _alertsStates
        .putIfAbsent(
            childId, () => BehaviorState<List<Map<String, dynamic>>>([]))
        .stream;
  }

  List<Map<String, dynamic>> getAlerts(String childId) {
    return _alertsStates
        .putIfAbsent(
            childId, () => BehaviorState<List<Map<String, dynamic>>>([]))
        .value;
  }

  void updateAlerts(String childId, List<Map<String, dynamic>> alerts) {
    final state = _alertsStates.putIfAbsent(
        childId, () => BehaviorState<List<Map<String, dynamic>>>([]));
    state.setValue(alerts);
    notifyListeners();
  }

  @override
  void dispose() {
    for (var s in _alertsStates.values) {
      s.dispose();
    }
    super.dispose();
  }
}
