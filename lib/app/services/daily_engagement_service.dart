import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hnsnap/app/features/tabs/data/repositories/quote_repository.dart';
import 'package:hnsnap/app/features/tabs/data/models/quote_entry.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class DailyEngagementService {
  DailyEngagementService._({QuoteRepository? quoteRepository})
    : _quoteRepository = quoteRepository ?? QuoteRepository();

  static final DailyEngagementService instance = DailyEngagementService._();

  static const _notificationChannelId = 'daily_engagement';
  static const _notificationChannelName = 'Nhắc hằng ngày';
  static const _notificationChannelDescription =
      'Nhắc giữ streak và gửi quote mỗi sáng lúc 7h';
  static const _welcomeNotificationId = 6999;
  static const _notificationBaseId = 7000;
  static const _scheduledNotificationCount = 14;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final QuoteRepository _quoteRepository;

  Future<void>? _initializationFuture;
  bool _isInitialized = false;
  bool _hasNotificationPermission = true;

  Future<void> ensureInitialized() {
    if (_isInitialized) {
      return Future.value();
    }

    return _initializationFuture ??= _initialize();
  }

  Future<void> scheduleDailyNotifications({required int streakCount}) async {
    await ensureInitialized();
    if (!_hasNotificationPermission) {
      return;
    }

    await _cancelScheduledNotifications();

    final now = tz.TZDateTime.now(tz.local);
    final firstSchedule = _nextSevenAm(now);
    final quotes = await _quoteRepository.getQuotesForSchedule(
      count: _scheduledNotificationCount,
    );
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: _notificationChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    for (var offset = 0; offset < _scheduledNotificationCount; offset += 1) {
      final scheduledAt = firstSchedule.add(Duration(days: offset));
      final quote = quotes[offset % quotes.length];
      await _notificationsPlugin.zonedSchedule(
        id: _notificationBaseId + offset,
        title: _buildTitle(streakCount),
        body: _buildBody(quote, streakCount),
        scheduledDate: scheduledAt,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<bool> showWelcomeNotification() async {
    await ensureInitialized();
    if (!_hasNotificationPermission) {
      return false;
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: _notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await Future<void>.delayed(const Duration(milliseconds: 900));

    try {
      await _notificationsPlugin.show(
        id: _welcomeNotificationId,
        title: 'Chào mừng bạn đến với hnsnap',
        body:
            'Thông báo đã hoạt động rồi. Từ giờ mình có thể nhắc bạn giữ streak và gửi quote lúc 7 giờ sáng.',
        notificationDetails: notificationDetails,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initialize() async {
    await _configureLocalTimezone();
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
    _hasNotificationPermission = await _requestPermissions();
    _isInitialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    tz_data.initializeTimeZones();

    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> _requestPermissions() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted =
        await androidPlugin?.requestNotificationsPermission() ?? true;

    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted =
        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    return androidGranted && iosGranted;
  }

  Future<void> _cancelScheduledNotifications() async {
    for (
      var id = _notificationBaseId;
      id < _notificationBaseId + _scheduledNotificationCount;
      id += 1
    ) {
      await _notificationsPlugin.cancel(id: id);
    }
  }

  tz.TZDateTime _nextSevenAm(tz.TZDateTime now) {
    final todaySevenAm = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      7,
    );

    if (now.isBefore(todaySevenAm)) {
      return todaySevenAm;
    }

    return todaySevenAm.add(const Duration(days: 1));
  }

  String _buildTitle(int streakCount) {
    if (streakCount > 0) {
      return 'Đừng bỏ lỡ chuỗi $streakCount ngày của bạn';
    }

    return '7 giờ sáng rồi, mở hnsnap thôi';
  }

  String _buildBody(QuoteEntry quote, int streakCount) {
    if (streakCount > 0) {
      return '${quote.formattedLine}\nMở app vài giây để giữ nhịp hôm nay.';
    }

    return quote.formattedLine;
  }
}
