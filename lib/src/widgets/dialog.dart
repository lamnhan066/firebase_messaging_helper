import 'package:flutter/material.dart';

class PreDialogData {
  final BuildContext context;
  final String title;
  final String content;
  final String allowButtonText;
  final String maybeLaterButtonText;

  PreDialogData({
    required this.context,
    this.title = 'Notification',
    this.content =
        'Enable notification permission to receive news from the app',
    this.allowButtonText = 'Allow',
    this.maybeLaterButtonText = 'Maybe later',
  });
}
