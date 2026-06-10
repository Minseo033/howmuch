import 'package:flutter/material.dart';

class SavingsGlobalState {
  static final SavingsGlobalState _instance = SavingsGlobalState._internal();
  factory SavingsGlobalState() => _instance;
  SavingsGlobalState._internal();

  // 이번 달 절약 목표 (기본값 30000)
  final ValueNotifier<int> monthlyGoal = ValueNotifier<int>(30000);

  // 현재 달성 금액 (기본값 24500)
  final ValueNotifier<int> currentSaved = ValueNotifier<int>(24500);

  double get achievementRate {
    if (monthlyGoal.value == 0) return 0;
    return currentSaved.value / monthlyGoal.value;
  }
}
