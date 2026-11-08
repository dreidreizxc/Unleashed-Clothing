import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Circular customer avatar with an initials fallback and an optional camera
/// badge. Supports the data URI stored in `photoUrl` today and a normal HTTPS
/// download URL if the project later moves to Firebase Storage.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.size = 62,
    this.onTap,
    this.showEditBadge = true,
    this.borderColor = AppColors.line,
    this.fallbackColor = AppColors.subtle,
    this.initialsColor = AppColors.ink,
    this.badgeColor = AppColors.surface,
    this.badgeIconColor = AppColors.ink,
  });

  final String? photoUrl;
  final String initials;
  final double size;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final Color borderColor;
  final Color fallbackColor;
  final Color initialsColor;
  final Color badgeColor;
  final Color badgeIconColor;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decodeDataUri(widget.photoUrl);
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _bytes = _decodeDataUri(widget.photoUrl);
    }
  }

  static Uint8List? _decodeDataUri(String? value) {
    final url = value?.trim() ?? '';
    if (!url.startsWith('data:image/')) return null;
    final comma = url.indexOf(',');
    if (comma < 0 || comma == url.length - 1) return null;
    try {
      return base64Decode(url.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  bool get _isRemote {
    final url = widget.photoUrl?.trim() ?? '';
    return url.startsWith('https://') || url.startsWith('http://');
  }

  Widget _fallback() {
    return Container(
      color: widget.fallbackColor,
      alignment: Alignment.center,
      child: Text(
        widget.initials,
        style: TextStyle(
          fontSize: widget.size * 0.34,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: widget.initialsColor,
        ),
      ),
    );
  }

  Widget _photo() {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    if (_isRemote) {
      return Image.network(
        widget.photoUrl!.trim(),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: widget.fallbackColor,
            alignment: Alignment.center,
            child: SizedBox(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    return _fallback();
  }

  @override
  Widget build(BuildContext context) {
    final badgeSize = widget.size * 0.34;
    final avatar = ClipOval(
      child: SizedBox(width: widget.size, height: widget.size, child: _photo()),
    );

    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.borderColor, width: 1.2),
          ),
          child: avatar,
        ),
        if (widget.showEditBadge)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: widget.badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.photo_camera_outlined,
                size: badgeSize * 0.55,
                color: widget.badgeIconColor,
              ),
            ),
          ),
      ],
    );

    if (widget.onTap == null) return content;

    return Semantics(
      button: true,
      label: 'Change or remove profile photo',
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: widget.onTap,
          radius: widget.size / 2,
          containedInkWell: false,
          highlightShape: BoxShape.circle,
          child: content,
        ),
      ),
    );
  }
}
