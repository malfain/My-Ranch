import 'package:flutter/foundation.dart';

/// Tab yang sedang dibuka dan jenis hewan yang dipilih di layar Ternak.
class UiState extends ChangeNotifier {
  int tab = 0;
  String kind = 'ayam';

  void go(int t) {
    tab = t;
    notifyListeners();
  }

  void openKind(String k) {
    kind = k;
    tab = 1;
    notifyListeners();
  }
}

final ui = UiState();
