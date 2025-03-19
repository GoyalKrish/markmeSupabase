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
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (withShadow)
            Container(
              height: variant == LogoVariant.icon ? size : size * 0.75,
              width: variant == LogoVariant.icon ? size : size * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB800).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
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