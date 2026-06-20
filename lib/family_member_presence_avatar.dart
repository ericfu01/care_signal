import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Avatar with optional green online dot (bottom-right).
class FamilyMemberPresenceAvatar extends StatelessWidget {
  const FamilyMemberPresenceAvatar({
    super.key,
    required this.radius,
    required this.initials,
    required this.backgroundColor,
    required this.isOnline,
    this.photoBytes,
    this.photoUrl,
  });

  final double radius;
  final String initials;
  final Color backgroundColor;
  final bool isOnline;
  final Uint8List? photoBytes;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final dotSize = radius * 0.42;
    final imageBytes = photoBytes;
    final url = photoUrl?.trim();
    ImageProvider? backgroundImage;
    if (imageBytes != null) {
      backgroundImage = MemoryImage(imageBytes);
    } else if (url != null && url.isNotEmpty) {
      backgroundImage = NetworkImage(url);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          backgroundImage: backgroundImage,
          child: backgroundImage == null
              ? Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.72,
                  ),
                )
              : null,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: const Color(0xFF43A047),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
