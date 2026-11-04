import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';

class ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const ShimmerBox({super.key, required this.height, this.width, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.card,
      highlightColor: AppTheme.border,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
