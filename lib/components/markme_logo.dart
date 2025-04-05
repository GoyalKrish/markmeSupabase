import 'package:flutter/material.dart';

class MarkMeLogo extends StatelessWidget {
  final double size;
  final LogoVariant variant;

  const MarkMeLogo({
    super.key,
    this.size = 64.0,
    this.variant = LogoVariant.full,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: variant == LogoVariant.icon ? size : size * 0.75,
      width: variant == LogoVariant.icon ? size : size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            variant == LogoVariant.icon
                ? 'assets/images/markme_icon.png'
                : 'assets/images/Markme_logo_transparent.png',
            fit: BoxFit.contain,
            height: variant == LogoVariant.icon ? size : size * 0.75,
            width: variant == LogoVariant.icon ? size : size * 2,
          ),
        ],
      ),
    );
  }
}

enum LogoVariant {
  full,    // Full logo with text
  icon,    // Just the icon
}