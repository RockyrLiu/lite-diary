import 'package:flutter/material.dart';

class TabVisibilityNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final tabVisibilityNotifier = TabVisibilityNotifier();
