import 'package:flutter/material.dart';

class DialogFormat {
  final BuildContext context;
  final String title;
  final String content;
  final String allowButtonText;
  final String maybeLaterButtonText;

  DialogFormat({
    required this.context,
    this.title = 'Notification',
    this.content =
        'Enable notification permission to receive news from our app',
    this.allowButtonText = 'Allow',
    this.maybeLaterButtonText = 'Maybe later',
  });
}

Future<bool?> dialog(DialogFormat dialog) {
  return showDialog<bool>(
    context: dialog.context,
    builder: (ctx) => AlertDialog(
      title: Text(
        dialog.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
      content: Text(
        dialog.content,
        textAlign: TextAlign.center,
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx, true);
          },
          child: Text(dialog.allowButtonText),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx, false);
          },
          child: Text(dialog.maybeLaterButtonText),
        ),
      ],
    ),
  );
}
