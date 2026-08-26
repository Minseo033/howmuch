import 'package:flutter/material.dart';

class SavingsGlobalState {
  static final SavingsGlobalState _instance = SavingsGlobalState._internal();
  factory SavingsGlobalState() => _instance;
  SavingsGlobalState._internal();

  // 서버에서 불러오기 전에는 미설정 상태로 둡니다.
  final ValueNotifier<int> monthlyGoal = ValueNotifier<int>(0);

  final ValueNotifier<int> currentSaved = ValueNotifier<int>(0);

  final ValueNotifier<int> visitCount = ValueNotifier<int>(0);

  double get achievementRate {
    if (monthlyGoal.value == 0) return 0;
    return currentSaved.value / monthlyGoal.value;
  }
}
