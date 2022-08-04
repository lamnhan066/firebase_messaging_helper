part of 'firebase_messaging_helper.dart';

class PreDialogConfig {
  final BuildContext context;
  final String title;
  final String content;
  final String allowButtonText;
  final String maybeLaterButtonText;

  PreDialogConfig({
    required this.context,
    this.title = 'Notification',
    this.content =
        'Enable notification permission to receive news from the app',
    this.allowButtonText = 'Allow',
    this.maybeLaterButtonText = 'Maybe later',
  });
}
