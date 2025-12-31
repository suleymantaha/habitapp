import 'package:flutter/foundation.dart';

abstract class ViewModel extends ChangeNotifier {
  bool _disposed = false;

  bool get isBusy => _isBusy;
  bool _isBusy = false;

  Object? get error => _error;
  Object? _error;

  void setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    if (_disposed) return;
    notifyListeners();
  }

  void setError(Object? value) {
    _error = value;
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
