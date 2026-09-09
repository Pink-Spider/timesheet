import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// AppSettings를 SharedPreferences에 개별 키로 저장/복원한다.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) : _settings = _read(_prefs);

  static const _keyTotalLeave = 'totalAnnualLeave';
  static const _keyLeaveAdjustment = 'leaveUsedAdjustment';
  static const _keyLeaveAdjustmentYear = 'leaveAdjustmentYearKey';
  static const _keyLeaveStartMonth = 'leaveYearStartMonth';
  static const _keyLeaveStartDay = 'leaveYearStartDay';
  static const _keyStandardDaily = 'standardDailyMinutes';
  static const _keyBreakPolicy = 'breakPolicy';
  static const _keyBreak = 'breakMinutes';
  static const _keyBreakThreshold = 'breakThresholdMinutes';
  static const _keyWorkStart = 'workStart';
  static const _keyWorkEnd = 'workEnd';
  static const _keyReminderEnabled = 'reminderEnabled';
  static const _keyReminderOffset = 'reminderOffsetMinutes';

  final SharedPreferences _prefs;
  AppSettings _settings;

  AppSettings get settings => _settings;

  static AppSettings _read(SharedPreferences prefs) {
    const d = AppSettings();
    return AppSettings(
      totalAnnualLeave:
          prefs.getDouble(_keyTotalLeave) ?? d.totalAnnualLeave,
      leaveUsedAdjustment:
          prefs.getDouble(_keyLeaveAdjustment) ?? d.leaveUsedAdjustment,
      leaveAdjustmentYearKey: prefs.getString(_keyLeaveAdjustmentYear) ??
          d.leaveAdjustmentYearKey,
      leaveYearStartMonth:
          prefs.getInt(_keyLeaveStartMonth) ?? d.leaveYearStartMonth,
      leaveYearStartDay:
          prefs.getInt(_keyLeaveStartDay) ?? d.leaveYearStartDay,
      standardDailyMinutes:
          prefs.getInt(_keyStandardDaily) ?? d.standardDailyMinutes,
      breakPolicy: BreakPolicy.fromName(prefs.getString(_keyBreakPolicy)),
      breakMinutes: prefs.getInt(_keyBreak) ?? d.breakMinutes,
      breakThresholdMinutes:
          prefs.getInt(_keyBreakThreshold) ?? d.breakThresholdMinutes,
      workStart: prefs.getString(_keyWorkStart) ?? d.workStart,
      workEnd: prefs.getString(_keyWorkEnd) ?? d.workEnd,
      reminderEnabled:
          prefs.getBool(_keyReminderEnabled) ?? d.reminderEnabled,
      reminderOffsetMinutes:
          prefs.getInt(_keyReminderOffset) ?? d.reminderOffsetMinutes,
    );
  }

  Future<void> update(AppSettings next) async {
    _settings = next;
    await _prefs.setDouble(_keyTotalLeave, next.totalAnnualLeave);
    await _prefs.setDouble(_keyLeaveAdjustment, next.leaveUsedAdjustment);
    await _prefs.setString(
        _keyLeaveAdjustmentYear, next.leaveAdjustmentYearKey);
    await _prefs.setInt(_keyLeaveStartMonth, next.leaveYearStartMonth);
    await _prefs.setInt(_keyLeaveStartDay, next.leaveYearStartDay);
    await _prefs.setInt(_keyStandardDaily, next.standardDailyMinutes);
    await _prefs.setString(_keyBreakPolicy, next.breakPolicy.name);
    await _prefs.setInt(_keyBreak, next.breakMinutes);
    await _prefs.setInt(_keyBreakThreshold, next.breakThresholdMinutes);
    await _prefs.setString(_keyWorkStart, next.workStart);
    await _prefs.setString(_keyWorkEnd, next.workEnd);
    await _prefs.setBool(_keyReminderEnabled, next.reminderEnabled);
    await _prefs.setInt(_keyReminderOffset, next.reminderOffsetMinutes);
    notifyListeners();
  }
}
