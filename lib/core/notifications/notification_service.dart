// lib/core/notifications/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'tasks_reminders';
  static const String _channelName = 'Recordatorios de tareas';
  static const String _channelDesc =
      'Notificaciones programadas para vencimientos de tareas';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Inicializa base de datos de zonas horarias
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // ANDROID 13+: solicitud de permiso para notificaciones
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    // iOS (por si lo usas en el futuro): pide permisos
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    // Crea el canal de notificaciones (Android)
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  tz.TZDateTime _toTz(DateTime when) {
    return tz.TZDateTime.from(when, tz.local);
  }

  int notificationIdForTask(String taskId) => taskId.hashCode & 0x7fffffff;

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    String? body,
    required DateTime when,
  }) async {
    await init();

    // Evita programar notificaciones en el pasado
    if (when.isBefore(DateTime.now())) return;

    final id = notificationIdForTask(taskId);
    // ↓ Esta línea no puede ser const porque anida un AndroidNotificationDetails no-const
// ignore: prefer_const_constructors
    final details = NotificationDetails(
      // ↓ AndroidNotificationDetails tampoco es const en esta versión del plugin
      // ignore: prefer_const_constructors
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body ?? 'Tienes una tarea pendiente',
      _toTz(when),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      payload: taskId,
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await init();
    await _plugin.cancel(notificationIdForTask(taskId));
  }
}
