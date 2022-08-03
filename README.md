# Firebase Messaging Helper

This plugin combine firebase_messaging with awesome_notification to help you esier to implement firebase notification.

## Setup

### [Apple integration](https://firebase.flutter.dev/docs/messaging/apple-integration)

### Android integration (Optional)

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

Initialize plugin:

    ``` dart
    FirebaseMessagingHelper.initial(
        context: context, // To show dialog before showing permission requested
        isDebug: true, // To show debug log
    );
    ```
