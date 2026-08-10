import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 퇴근 리마인더: 출근 시각 + 설정 오프셋에 한 번 울리는 일회성 알림.
/// 출근할 때 예약되고 퇴근하면 취소되므로 요일과 무관하게
/// 실제로 근무한 날에만 울린다.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _reminderId = 10;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    final localTz = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (_) {
      // 알 수 없는 타임존이면 UTC로 남는다. 리마인더 시각만 어긋날 뿐
      // 앱 동작에는 지장이 없다.
    }
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: initSettings);
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? true;
    }
    return true;
  }

  /// [at] 시각에 일회성 퇴근 리마인더를 예약한다. 과거 시각이면 무시.
  /// 호출은 멱등하다 (기존 예약을 대체).
  Future<void> scheduleClockOutReminder(DateTime at) async {
    await cancelClockOutReminder();
    final scheduled = tz.TZDateTime.from(at, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'clock_out_reminder',
        '퇴근 리마인더',
        channelDescription: '출근 후 설정한 시간이 지나면 퇴근 기록을 알려줍니다.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: '퇴근 시간입니다',
      body: '오늘의 퇴근 기록을 잊지 마세요!',
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelClockOutReminder() => _plugin.cancel(id: _reminderId);
}
