import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/air_service.dart';

class AqiCard extends StatelessWidget {
  final double pm25;
  final Map<String, dynamic> data;

  const AqiCard({super.key, required this.pm25, required this.data});

  @override
  Widget build(BuildContext context) {
    final airSvc = AirService();
    final level = airSvc.getAqiLevel(pm25);
    final label = airSvc.getAqiLabel(pm25);
    final advice = airSvc.getAqiAdvice(pm25);
    final color = AppTheme.levelColor(level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), AppTheme.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PM2.5 Hiện tại',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(pm25.toStringAsFixed(1),
                          style: GoogleFonts.outfit(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: color,
                              height: 1)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text('µg/m³',
                            style: GoogleFonts.outfit(
                                fontSize: 14, color: AppTheme.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
              _buildLevelBadge(label, color),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: AppTheme.border,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (pm25 / 100).clamp(0.02, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [AppTheme.good, AppTheme.moderate, AppTheme.poor, AppTheme.bad],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(advice,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
          const SizedBox(height: 14),
          Row(
            children: [
              _chip('QCVN 05:2023', AppTheme.primary),
              const SizedBox(width: 8),
              _chip('Điểm neo TDM', AppTheme.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: GoogleFonts.outfit(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
