import 'package:flutter/foundation.dart';

class ProgressRefreshNotifier extends ChangeNotifier {
  bool _shouldRefresh = false;

  bool get shouldRefresh => _shouldRefresh;

  void triggerRefresh() {
    _shouldRefresh = true;
    notifyListeners();
  }

  void consumeRefresh() {
    _shouldRefresh = false;
  }
}