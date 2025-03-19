import 'package:flutter/material.dart';

class MarkMeLogo extends StatelessWidget {
  final double size;
  final LogoVariant variant;
  final bool withShadow;

  const MarkMeLogo({
    super.key,
    this.size = 64.0,
    this.variant = LogoVariant.full,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: variant == LogoVariant.icon ? size : size * 0.75,
      width: variant == LogoVariant.icon ? size : size * 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(variant == LogoVariant.icon ? size / 4 : size / 8),
        boxShadow: withShadow ? [
          BoxShadow(
            color: const Color(0xFFFFB800).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Image.asset(
        variant == LogoVariant.icon
            ? 'assets/images/markme_icon.png'
            : 'assets/images/Markme_logo_transparent.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

enum LogoVariant {
  full,    // Full logo with text
  icon,    // Just the icon
}