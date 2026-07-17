import 'package:flutter/foundation.dart';
import 'behavior_state.dart';

class StatsBloc extends ChangeNotifier {
  static final StatsBloc _instance = StatsBloc._internal();
  factory StatsBloc() => _instance;
  StatsBloc._internal();

  final _todayStatsStates = <String, BehaviorState<Map<String, dynamic>>>{};
  final _webHistoryStates =
      <String, BehaviorState<List<Map<String, dynamic>>>>{};

  Stream<Map<String, dynamic>> watchTodayStats(String childId) {
    return _todayStatsStates
        .putIfAbsent(childId, () => BehaviorState<Map<String, dynamic>>({}))
        .stream;
  }

  Map<String, dynamic> getTodayStats(String childId) {
    return _todayStatsStates
        .putIfAbsent(childId, () => BehaviorState<Map<String, dynamic>>({}))
        .value;
  }

  void updateTodayStats(String childId, Map<String, dynamic> stats) {
    final state = _todayStatsStates.putIfAbsent(
        childId, () => BehaviorState<Map<String, dynamic>>({}));
    state.setValue(stats);
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> watchWebHistory(String childId) {
    return _webHistoryStates
        .putIfAbsent(
            childId, () => BehaviorState<List<Map<String, dynamic>>>(const []))
        .stream;
  }

  List<Map<String, dynamic>> getWebHistory(String childId) {
    return _webHistoryStates
        .putIfAbsent(
            childId, () => BehaviorState<List<Map<String, dynamic>>>(const []))
        .value;
  }

  void updateWebHistory(String childId, List<Map<String, dynamic>> history) {
    final state = _webHistoryStates.putIfAbsent(
        childId, () => BehaviorState<List<Map<String, dynamic>>>([]));
    state.setValue(history);
    notifyListeners();
  }

  @override
  void dispose() {
    for (var s in _todayStatsStates.values) {
      s.dispose();
    }
    for (var s in _webHistoryStates.values) {
      s.dispose();
    }
    super.dispose();
  }
}
