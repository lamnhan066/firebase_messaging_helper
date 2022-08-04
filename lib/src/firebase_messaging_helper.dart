import 'dart:async';
import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:box_widgets/box_widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages, implementation_imports
import 'package:hive/src/hive_impl.dart' show HiveImpl;
import 'package:hive_flutter/hive_flutter.dart';

import 'package:http/http.dart' as http;

part 'dialog.dart';

class FirebaseMessagingHelper {
  FirebaseMessagingHelper._();

  static String? get fcmToken => _fcmToken;

  static final _awesomeNotifications = AwesomeNotifications();
  static String? _fcmToken;
  static final HiveImpl _hive = HiveImpl();
  static Box? _box;
  static bool _isDebug = false;

  static FutureOr<void> Function(RemoteMessage message)? _backgroundHandler;

  static Future<void> initial({
    /// To show dialog before showing requesting permission
    PreDialogData? preDialogData,

    /// Tap on notification
    void Function(RemoteMessage message)? onNotificationTapped,

    /// foreground message
    void Function(RemoteMessage message)? onForegroundMessage,

    /// Background handler. All methods here must be static or top-level
    FutureOr<void> Function(RemoteMessage message)? onBackgroundMessage,

    /// Debug log
    bool isDebug = false,
  }) async {
    _isDebug = isDebug;
    _backgroundHandler = onBackgroundMessage;

    await _hive.initFlutter('FirebaseMessagingHelper');
    _box = await _hive.openBox('config');

    await _requestPermission(preDialogData: preDialogData);

    _fcmToken = await FirebaseMessaging.instance.getToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _fcmToken = token;
    }).onError((err) {
      _printDebug('Fcm Token Error: $err');
    });

    _printDebug('Fcm Token: $_fcmToken');

    await _awesomeNotifications.initialize(
      null, // default app icon
      [
        NotificationChannel(
          channelGroupKey: 'normal_channel_group',
          channelKey: 'normal_channel',
          channelName: 'Normal Notification',
          channelDescription: 'Normal Notification',
          playSound: true,
          enableVibration: true,
          ledColor: Colors.white,
          importance: NotificationImportance.Max,
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

    if (onNotificationTapped != null) {
      _setupInteractedMessage(onNotificationTapped);
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessagingHandler);

    FirebaseMessaging.onMessage.listen((message) {
      _firebaseForegroundMessagingHandler(message);
      if (onForegroundMessage != null) {
        onForegroundMessage(message);
      }
    });
  }

  static Future<void> _requestPermission({PreDialogData? preDialogData}) async {
    // await FirebaseMessaging.instance
    //     .setForegroundNotificationPresentationOptions();
    _awesomeNotifications.isNotificationAllowed().then((isAllowed) async {
      if (!isAllowed) {
        final isLocalAllowed = _box!.get('isAllowNotification') as bool?;

        if (isLocalAllowed != null) return;

        if (preDialogData != null) {
          // ignore: use_build_context_synchronously
          await _requestPermisstion(preDialogData);
        } else {
          final result = await FirebaseMessaging.instance.requestPermission();

          _box!.put('isAllowNotification',
              result.authorizationStatus == AuthorizationStatus.authorized);
        }
      }
    });
  }

  // It is assumed that all messages contain a data field with the key 'type'
  static Future<void> _setupInteractedMessage(
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

  static int _notificationId = 0;
  static Future<void> _firebaseForegroundMessagingHandler(
      RemoteMessage message) async {
    _printDebug('Handling a foreground message: ${message.messageId}');

    if (message.notification != null) {
      String? imageUrl;
      imageUrl ??= message.notification!.android?.imageUrl;
      imageUrl ??= message.notification!.apple?.imageUrl;

      _awesomeNotifications.createNotification(
        content: NotificationContent(
          id: ++_notificationId,
          channelKey: 'normal_channel',
          title: message.notification!.title,
          body: message.notification!.body,
          notificationLayout: imageUrl == null || imageUrl.isEmpty
              ? NotificationLayout.Default
              : NotificationLayout.BigPicture,
          bigPicture: imageUrl,
        ),
      );
    } else {
      _awesomeNotifications.createNotificationFromJsonData(message.data);
    }
  }

  static Future<void> _firebaseBackgroundMessagingHandler(
      RemoteMessage message) async {
    _printDebug('Handling a background message: ${message.messageId}');

    await _awesomeNotifications.initialize(
      null, // default app icon
      [
        NotificationChannel(
          channelGroupKey: 'normal_channel_group',
          channelKey: 'normal_channel',
          channelName: 'Normal Notification',
          channelDescription: 'Normal Notification',
          playSound: true,
          enableVibration: true,
          ledColor: Colors.white,
          importance: NotificationImportance.Max,
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

    Completer completer = Completer();
    completer.complete(_backgroundHandler);
    await completer.future;
  }

  static Future<bool> _requestPermisstion(PreDialogData dialogFormat) async {
    final isPermissionAllowed =
        await _awesomeNotifications.isNotificationAllowed();

    if (isPermissionAllowed) {
      return false;
    }

    final result = await boxDialog<bool>(
      context: dialogFormat.context,
      title: dialogFormat.title, //'Quyền Thông Báo',
      content: Text(
        dialogFormat.content,
        // 'Ứng dụng cần bạn cấp quyền để gửi được những thông báo mới nhất và cần thiết nhất.'
        // '\n\nBạn có muốn cấp quyền không?',
        textAlign: TextAlign.center,
      ),
      buttons: [
        Buttons(
          axis: Axis.vertical,
          align: MainAxisAlignment.end,
          buttons: [
            BoxButton(
              title: Text(dialogFormat.maybeLaterButtonText), //'Hỏi lại sau'),
              backgroundColor: Colors.grey,
              onPressed: () {
                Navigator.pop(dialogFormat.context, false);
              },
            ),
            BoxButton(
              title: Text(dialogFormat.allowButtonText), //'Đồng ý'),
              onPressed: () {
                _awesomeNotifications
                    .requestPermissionToSendNotifications()
                    .then((value) {
                  _box!.put('isAllowNotification', value);
                  Navigator.pop(dialogFormat.context, value);
                });
              },
            ),
          ],
        )
      ],
    );

    return result ?? false;
  }

  /// Source: https://github.com/rithik-dev/firebase_notifications_handler
  ///
  /// Trigger FCM notification.
  ///
  /// [cloudMessagingServerKey] : The server key from the cloud messaging console.
  /// This key is required to trigger the notification.
  ///
  /// [title] : The notification's title.
  ///
  /// [body] : The notification's body.
  ///
  /// [imageUrl] : The notification's image URL.
  ///
  /// [fcmTokens] : List of the registered devices' tokens.
  ///
  /// [payload] : Notification payload, is provided in the [onTap] callback.
  ///
  /// [additionalHeaders] : Additional headers,
  /// other than 'Content-Type' and 'Authorization'.
  ///
  /// [notificationMeta] : Additional content that you might want to pass
  /// in the "notification" attribute, apart from title, body, image.
  static Future<http.Response> sendNotification({
    required String cloudMessagingServerKey,
    required String title,
    required List<String> fcmTokens,
    String? body,
    String? imageUrl,
    Map? payload,
    Map? additionalHeaders,
    Map? notificationMeta,
  }) async {
    return await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$cloudMessagingServerKey',
        ...?additionalHeaders,
      },
      body: jsonEncode({
        if (fcmTokens.length == 1)
          "to": fcmTokens.first
        else
          "registration_ids": fcmTokens,
        "notification": {
          "title": title,
          "body": body,
          "image": imageUrl,
          ...?notificationMeta,
        },
        "data": {
          "click_action": "FLUTTER_NOTIFICATION_CLICK",
          ...?payload,
        },
      }),
    );
  }

  static void _printDebug(Object? object) =>
      // ignore: avoid_print
      _isDebug ? print('[Firebase Messaging Helper] $object') : null;
}
