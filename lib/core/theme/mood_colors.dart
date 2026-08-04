import 'package:flutter/material.dart';

import '../../domain/models/mood.dart';

/// Maps each mood to a recognizable color for UI decoration.
extension MoodColors on Mood {
  Color get color => switch (this) {
        Mood.happy => const Color(0xFFF59E0B),
        Mood.excited => const Color(0xFFEC4899),
        Mood.grateful => const Color(0xFF10B981),
        Mood.calm => const Color(0xFF14B8A6),
        Mood.focused => const Color(0xFF6366F1),
        Mood.neutral => const Color(0xFF94A3B8),
        Mood.tired => const Color(0xFF8B5CF6),
        Mood.anxious => const Color(0xFFF97316),
        Mood.sad => const Color(0xFF3B82F6),
        Mood.angry => const Color(0xFFEF4444),
      };
}
