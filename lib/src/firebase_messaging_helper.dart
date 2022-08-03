import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:box_widgets/box_widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages, implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FirebaseMessagingHelper {
  static String? _fcmToken;
  static final instance = FirebaseMessaging.instance;
  static String? get fcmToken => _fcmToken;
  static final HiveImpl _hive = HiveImpl();
  static Box? _box;
  static bool _isDebug = false;

  static Future<void> initial({
    BuildContext? context,
    bool isDebug = false,
  }) async {
    _isDebug = isDebug;

    await _hive.initFlutter('FirebaseMessagingHelper');
    _box = await _hive.openBox('config');

    if (context != null) {
      // ignore: use_build_context_synchronously
      await requestPermisstion(context);
    } else {
      await FirebaseMessaging.instance.requestPermission();
    }

    _fcmToken = await FirebaseMessaging.instance.getToken();
    instance.onTokenRefresh.listen((token) {
      _fcmToken = token;
    }).onError((err) {
      _printDebug('Fcm Token Error: $err');
    });

    _printDebug('Fcm Token: $_fcmToken');

    await AwesomeNotifications().initialize(
      null, // default app icon
      [
        NotificationChannel(
          channelGroupKey: 'normal_channel_group',
          channelKey: 'normal_channel',
          channelName: 'Normal Notification',
          channelDescription: 'Normal Notification',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          vibrationPattern: highVibrationPattern,
        )
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupkey: 'normal_channel_group',
          channelGroupName: 'Normal channel group',
        )
      ],
      debug: true,
    );

    // print('User granted permission: ${settings.authorizationStatus}');
    FirebaseMessaging.onMessage
        .listen((message) => _firebaseMessagingHandler(message));
  }

  static initialBackground() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingHandler);
  }

  // It is assumed that all messages contain a data field with the key 'type'
  static Future<void> setupInteractedMessage(
    void Function(RemoteMessage message) handler,
  ) async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen
    if (initialMessage != null) {
      handler(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  // void _handleMessage(RemoteMessage message) {
  //   if (message.data['type'] == 'chat') {
  //     Navigator.pushNamed(
  //       context,
  //       '/chat',
  //       arguments: ChatArguments(message),
  //     );
  //   }
  // }

  static Future<void> _firebaseMessagingHandler(
    RemoteMessage message,
  ) async {
    // If you're going to use other Firebase services in the background, such as Firestore,
    // make sure you call `initializeApp` before using other Firebase services.
    await Firebase.initializeApp();
    _printDebug('Handling a background message: ${message.messageId}');

    if (!AwesomeStringUtils.isNullOrEmpty(
          message.notification?.title,
          considerWhiteSpaceAsEmpty: true,
        ) ||
        !AwesomeStringUtils.isNullOrEmpty(
          message.notification?.body,
          considerWhiteSpaceAsEmpty: true,
        )) {
      _printDebug(
          'message also contained a notification: ${message.notification}');

      String? imageUrl;
      imageUrl ??= message.notification!.android?.imageUrl;
      imageUrl ??= message.notification!.apple?.imageUrl;

      Map<String, dynamic> notificationAdapter = {
        NOTIFICATION_CHANNEL_KEY: 'normal_channel',
        NOTIFICATION_ID: message.data[NOTIFICATION_CONTENT]?[NOTIFICATION_ID] ??
            message.messageId ??
            Random().nextInt(2147483647),
        NOTIFICATION_TITLE: message.data[NOTIFICATION_CONTENT]
                ?[NOTIFICATION_TITLE] ??
            message.notification?.title,
        NOTIFICATION_BODY: message.data[NOTIFICATION_CONTENT]
                ?[NOTIFICATION_BODY] ??
            message.notification?.body,
        NOTIFICATION_LAYOUT: AwesomeStringUtils.isNullOrEmpty(imageUrl)
            ? 'Default'
            : 'BigPicture',
        NOTIFICATION_BIG_PICTURE: imageUrl
      };

      AwesomeNotifications()
          .createNotificationFromJsonData(notificationAdapter);
    } else {
      AwesomeNotifications().createNotificationFromJsonData(message.data);
    }
  }

  static Future<bool> requestPermisstion(BuildContext context) async {
    final isLocalAllowed = _box!.get('isAllowNotification') as bool?;
    final isPermissionAllowed =
        await AwesomeNotifications().isNotificationAllowed();

    if (isLocalAllowed != null || isPermissionAllowed) {
      return false;
    }

    final result = await boxDialog<bool>(
      context: context,
      title: 'Quyền Thông Báo',
      content: const Text(
        'Ứng dụng cần bạn cấp quyền để gửi được những thông báo mới nhất và cần thiết nhất.'
        '\n\nBạn có muốn cấp quyền không?',
        textAlign: TextAlign.center,
      ),
      buttons: [
        Buttons(
          axis: Axis.vertical,
          align: MainAxisAlignment.end,
          buttons: [
            BoxButton(
              title: const Text('Không'),
              onPressed: () {
                _box!.put('isAllowNotification', false);

                Navigator.pop(context, false);
              },
            ),
            BoxButton(
              title: const Text('Hỏi lại sau'),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
            BoxButton(
              title: const Text('Đồng ý'),
              onPressed: () {
                AwesomeNotifications()
                    .requestPermissionToSendNotifications()
                    .then((value) {
                  _box!.put('isAllowNotification', value);
                  Navigator.pop(context, value);
                });
              },
            ),
          ],
        )
      ],
    );

    return result ?? false;
  }

  static void _printDebug(Object? object) =>
      // ignore: avoid_print
      _isDebug ? print('[Firebase Messaging Helper] $object') : null;
}
