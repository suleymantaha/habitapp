import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
      ),
    );
}
