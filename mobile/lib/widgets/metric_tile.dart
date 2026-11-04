import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class MetricTile extends StatelessWidget {
  final String label;
  final dynamic value;
  final String unit;
  final Color color;
  final double maxValue;
  final String levelLabel;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.maxValue = 100,
    this.levelLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    final val = (value as num?)?.toDouble() ?? 0;
    final pct = (val / maxValue).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1B38).withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              if (levelLabel.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    levelLabel,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  val.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          buildGradientBar(pct, color),
        ],
      ),
    );
  }

  Widget buildGradientBar(double pct, Color dotColor) {
    return LayoutBuilder(builder: (context, constraints) {
      final barWidth = constraints.maxWidth;
      final dotX = (barWidth * pct).clamp(5.0, barWidth - 5.0);
      return SizedBox(
        height: 10,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 3,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF34D399),
                      Color(0xFFFBBF24),
                      Color(0xFFFB923C),
                      Color(0xFFF87171),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: dotX - 5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
