"""Verification pass 3 (focused): for each new API from this session, print the
definition signature and every call site, so each can be checked directly.
"""
import re
from pathlib import Path

root = Path('.').resolve()
dart_files = sorted(
    [p for p in (root / 'lib').rglob('*.dart')]
    + [p for p in (root / 'test').rglob('*.dart')]
)

# symbol -> files to scan for call sites
FOCUS = {
    'zonedSchedule': ['lib/data/services/reminder_service.dart'],
    'scheduleDaily': ['lib/application/habits/habit_providers.dart',
                      'lib/data/services/reminder_service.dart'],
    'resyncAll': ['lib/application/habits/habit_providers.dart',
                  'lib/data/services/reminder_service.dart'],
    'cancel': ['lib/application/habits/habit_providers.dart'],
    'requestPermission': ['lib/presentation/screens/habits/habit_editor_screen.dart'],
    'launchPayload': ['lib/main.dart'],
    'initialize(': ['lib/main.dart', 'lib/data/services/reminder_service.dart'],
    'toggleDay': ['lib/presentation/screens/habits/habit_detail_screen.dart',
                  'lib/application/habits/habit_providers.dart',
                  'test/habit_toggle_test.dart'],
    'toggleCount': ['lib/application/habits/habit_providers.dart',
                    'lib/domain/services/habit_stats.dart'],
    'setCount': ['lib/application/habits/habit_providers.dart'],
    'setArchived': ['lib/application/habits/habit_providers.dart'],
    'getAll(': ['lib/application/habits/habit_providers.dart'],
    'resyncReminders': ['lib/presentation/screens/settings/settings_screen.dart',
                        'lib/application/habits/habit_providers.dart'],
    'isDayEnabled': ['lib/core/widgets/month_calendar.dart',
                     'lib/presentation/screens/habits/habit_detail_screen.dart'],
    'onSelectDay': ['lib/core/widgets/month_calendar.dart',
                    'lib/presentation/screens/habits/habit_detail_screen.dart'],
    'WeekReviewService': ['lib/application/analytics/week_review_provider.dart',
                          'lib/domain/services/week_review.dart',
                          'test/week_review_test.dart'],
    'build(': ['lib/application/analytics/week_review_provider.dart',
               'lib/domain/services/week_review.dart'],
    'weekdayName': ['lib/core/utils/date_utils.dart', 'lib/domain/services/week_review.dart'],
}

line_re = re.compile(r'^\s*.*', re.M)

for sym, files in FOCUS.items():
    print(f'===== {sym} =====')
    for rel in files:
        f = root / rel
        src = f.read_text(encoding='utf-8')
        for i, line in enumerate(src.splitlines(), 1):
            if sym in line:
                stripped = line.strip()
                # skip pure comment/import lines
                if stripped.startswith('//') or stripped.startswith('import'):
                    continue
                print(f'  {rel}:{i}: {stripped[:150]}')
    print()
