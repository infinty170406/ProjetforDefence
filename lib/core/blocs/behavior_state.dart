import 'dart:async';

class BehaviorState<T> {
  T _value;
  final _controller = StreamController<T>.broadcast();

  BehaviorState(this._value);

  T get value => _value;

  void setValue(T newValue) {
    _value = newValue;
    _controller.add(newValue);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _controller.stream;
  }

  void dispose() {
    _controller.close();
  }
}
