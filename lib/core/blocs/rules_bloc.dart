import 'package:flutter/foundation.dart';
import '../../core/models/child_rules.dart';
import 'behavior_state.dart';

class RulesBloc extends ChangeNotifier {
  static final RulesBloc _instance = RulesBloc._internal();
  factory RulesBloc() => _instance;
  RulesBloc._internal();

  final _rulesStates = <String, BehaviorState<ChildRules>>{};
  final _installedAppsStates = <String, BehaviorState<List<String>>>{};
  final _blockedAppsStates = <String, BehaviorState<List<String>>>{};

  Stream<ChildRules> watchRules(String childId) {
    return _rulesStates
        .putIfAbsent(childId, () => BehaviorState<ChildRules>(ChildRules()))
        .stream;
  }

  ChildRules getRules(String childId) {
    return _rulesStates
        .putIfAbsent(childId, () => BehaviorState<ChildRules>(ChildRules()))
        .value;
  }

  void updateRules(String childId, ChildRules rules) {
    final state = _rulesStates.putIfAbsent(
        childId, () => BehaviorState<ChildRules>(ChildRules()));
    state.setValue(rules);

    // Also sync the blocked apps list from rules
    updateBlockedApps(childId, rules.blockedApps);

    notifyListeners();
  }

  Stream<List<String>> watchInstalledApps(String childId) {
    return _installedAppsStates
        .putIfAbsent(childId, () => BehaviorState<List<String>>([]))
        .stream;
  }

  void updateInstalledApps(String childId, List<String> apps) {
    final state = _installedAppsStates.putIfAbsent(
        childId, () => BehaviorState<List<String>>([]));
    state.setValue(apps);
    notifyListeners();
  }

  Stream<List<String>> watchBlockedApps(String childId) {
    return _blockedAppsStates
        .putIfAbsent(childId, () => BehaviorState<List<String>>([]))
        .stream;
  }

  void updateBlockedApps(String childId, List<String> blockedApps) {
    final state = _blockedAppsStates.putIfAbsent(
        childId, () => BehaviorState<List<String>>([]));
    state.setValue(blockedApps);
    notifyListeners();
  }

  @override
  void dispose() {
    for (var s in _rulesStates.values) {
      s.dispose();
    }
    for (var s in _installedAppsStates.values) {
      s.dispose();
    }
    for (var s in _blockedAppsStates.values) {
      s.dispose();
    }
    super.dispose();
  }
}
