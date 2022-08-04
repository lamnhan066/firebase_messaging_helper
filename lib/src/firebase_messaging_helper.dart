import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:box_widgets/box_widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages, implementation_imports

import 'package:http/http.dart' as http;

part 'dialog.dart';

class FirebaseMessagingHelper {
  FirebaseMessagingHelper._();

  static String? get fcmToken => _fcmToken;

  static final _awesomeNotifications = AwesomeNotifications();
  static String? _fcmToken;
  static bool _isDebug = false;

  /// Initialize the plugin
  ///
  /// [preDialogConfig] config for the dialog showing before asking permission
  ///
  /// [onBackgroundTapped] called when user tapping notification on background mode
  ///
  /// [onForegroundMessage] called when there is a notification on foreground
  ///
  /// [onBackgroundMessage] called when there is a notification on background
  /// All methods here must be static or top-level, can't be anonymous
  ///
  /// [isDebug] show debug log
  static Future<void> initial({
    PreDialogConfig? preDialogConfig,
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(RemoteMessage message)? onBackgroundTapped,
    Future<void> Function(RemoteMessage message)? onBackgroundMessage,
    bool isDebug = false,
  }) async {
    _isDebug = isDebug;
    if (onBackgroundMessage != null) {
      FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
    }

    await _requestPermission(preDialogData: preDialogConfig);

    _fcmToken = await FirebaseMessaging.instance.getToken();
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _fcmToken = token;
    }).onError((err) {
      _printDebug('Fcm Token Error: $err');
    });

    _printDebug('Fcm Token: $_fcmToken');

    if (Platform.isAndroid) {
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
        debug: isDebug,
      );
    }

    if (onBackgroundTapped != null) {
      _setupInteractedMessage(onBackgroundTapped);
    }

    FirebaseMessaging.onMessage.listen((message) {
      _firebaseForegroundMessagingHandler(message);
      if (onForegroundMessage != null) {
        onForegroundMessage(message);
      }
    });
  }

  /// Request permission with dialog if provided
  static Future<void> _requestPermission({
    PreDialogConfig? preDialogData,
  }) async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined &&
        (preDialogData == null || await _permissionDialog(preDialogData))) {
      await FirebaseMessaging.instance.requestPermission();
    }
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(alert: true);
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

  /// Auto increment id
  static int _notificationId = 0;

  /// Push notification for Android on foreground mode
  static Future<void> _firebaseForegroundMessagingHandler(
    RemoteMessage message,
  ) async {
    _printDebug('Handling a foreground message: ${message.messageId}');

    if (message.notification != null &&
        message.notification?.android != null &&
        Platform.isAndroid) {
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
          icon: message.notification?.android?.smallIcon,
        ),
      );
    }
  }

  /// Show permission dialog
  static Future<bool> _permissionDialog(PreDialogConfig dialogFormat) async {
    final result = await boxDialog<bool>(
      context: dialogFormat.context,
      title: dialogFormat.title,
      content: Text(
        dialogFormat.content,
        textAlign: TextAlign.center,
      ),
      buttons: [
        Buttons(
          axis: Axis.vertical,
          align: MainAxisAlignment.end,
          buttons: [
            BoxButton(
              title: Text(dialogFormat.maybeLaterButtonText),
              backgroundColor: Colors.grey,
              onPressed: () {
                Navigator.pop(dialogFormat.context, false);
              },
            ),
            BoxButton(
              title: Text(dialogFormat.allowButtonText),
              onPressed: () {
                Navigator.pop(dialogFormat.context, true);
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
