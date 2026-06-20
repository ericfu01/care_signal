import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Renders assistant text with **bold** markdown; user messages stay plain.
class SupportMessageBody extends StatelessWidget {
  const SupportMessageBody({
    super.key,
    required this.text,
    required this.isUser,
    required this.textColor,
  });

  final String text;
  final bool isUser;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return Text(
        text,
        style: TextStyle(
          color: textColor,
          height: 1.35,
          fontSize: 15,
        ),
      );
    }

    return MarkdownBody(
      data: text,
      shrinkWrap: true,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: textColor,
          height: 1.35,
          fontSize: 15,
        ),
        strong: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 15,
          height: 1.35,
        ),
        em: TextStyle(
          color: textColor,
          fontStyle: FontStyle.italic,
          fontSize: 15,
        ),
        listBullet: TextStyle(color: textColor, fontSize: 15),
        h1: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
        h2: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        h3: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        blockSpacing: 8,
        listIndent: 20,
      ),
    );
  }
}
