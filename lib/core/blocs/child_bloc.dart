import 'package:flutter/foundation.dart';
import 'behavior_state.dart';

class ChildBloc extends ChangeNotifier {
  static final ChildBloc _instance = ChildBloc._internal();
  factory ChildBloc() => _instance;
  ChildBloc._internal();

  final _childrenState = BehaviorState<List<Map<String, dynamic>>>([]);
  final _deviceStatusStates = <String, BehaviorState<String>>{};
  final _locationStates = <String, BehaviorState<Map<String, dynamic>?>>{};
  final _geofencesStates =
      <String, BehaviorState<List<Map<String, dynamic>>>>{};

  Stream<List<Map<String, dynamic>>> get childrenStream =>
      _childrenState.stream;
  List<Map<String, dynamic>> get children => _childrenState.value;

  void updateChildren(List<Map<String, dynamic>> list) {
    _childrenState.setValue(list);
    notifyListeners();
  }

  Stream<String> watchDeviceStatus(String childId) {
    return _deviceStatusStates
        .putIfAbsent(childId, () => BehaviorState<String>('OFFLINE'))
        .stream;
  }

  String getDeviceStatus(String childId) {
    return _deviceStatusStates
        .putIfAbsent(childId, () => BehaviorState<String>('OFFLINE'))
        .value;
  }

  void updateDeviceStatus(String childId, String status) {
    final state = _deviceStatusStates.putIfAbsent(
        childId, () => BehaviorState<String>('OFFLINE'));
    if (state.value != status) {
      state.setValue(status);
      notifyListeners();
    }
  }

  Stream<Map<String, dynamic>?> watchLocation(String childId) {
    return _locationStates
        .putIfAbsent(childId, () => BehaviorState<Map<String, dynamic>?>(null))
        .stream;
  }

  void updateLocation(String childId, Map<String, dynamic>? location) {
    final state = _locationStates.putIfAbsent(
        childId, () => BehaviorState<Map<String, dynamic>?>(null));
    state.setValue(location);
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> watchGeofences(String childId) {
    return _geofencesStates
        .putIfAbsent(
            childId, () => BehaviorState<List<Map<String, dynamic>>>([]))
        .stream;
  }

  void updateGeofences(String childId, List<Map<String, dynamic>> geofences) {
    final state = _geofencesStates.putIfAbsent(
        childId, () => BehaviorState<List<Map<String, dynamic>>>([]));
    state.setValue(geofences);
    notifyListeners();
  }

  @override
  void dispose() {
    _childrenState.dispose();
    for (var s in _deviceStatusStates.values) {
      s.dispose();
    }
    for (var s in _locationStates.values) {
      s.dispose();
    }
    for (var s in _geofencesStates.values) {
      s.dispose();
    }
    super.dispose();
  }
}
