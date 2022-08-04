# Firebase Messaging Helper

This plugin combine firebase_messaging with awesome_notification to help you esier to implement firebase notification.

## Setup

### - Apple integration: [Read here](https://firebase.flutter.dev/docs/messaging/apple-integration)

### - Android integration

Add the following `meta-data` schema within the `application` component:

``` xml
<meta-data
android:name="com.google.firebase.messaging.default_notification_channel_id"
android:value="normal_channel" />
```

Add this intent-filter in AndroidManifest in the `<activity>` tag with `android:name=".MainActivity"`:

``` xml
<intent-filter>
    <action android:name="FLUTTER_NOTIFICATION_CLICK" />
    <category android:name="android.intent.category.DEFAULT" />
</intent-filter>
```

## Usage

### Initialize plugin

``` dart
FirebaseMessagingHelper.initial(
    /// Show a dialog before asking for the permission
    preDialogConfig: PreDialogConfig(
        context: context,
    ),

    /// Callback when users tap on the notification
    onTapped: (message) => print('tapped message = ${message.notification?.toMap()}'),

    /// Callback when receving the notification on foreground
    onForegroundMessage: (message) => print('foreground message =  ${message.notification?.toMap()}'),

    /// Callback when receving the notification on background
    onBackgroundMessage: backgroundNotificationHandler,

    /// Show debug log
    isDebug: true,
);
```

The `backgroundNotificationHandler` must be static or top-level method (do not support anonymous method)

``` dart
Future<void> backgroundNotificationHandler(RemoteMessage message) async {
    print('On background message = ${message.notification?.toMap()}');
}

```
