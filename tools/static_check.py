"""Static verification for the VYRA worktree (no Dart SDK available):
1. Every import in lib/ and test/ resolves to an existing file.
2. Brace/paren/bracket balance per file (string/comment-aware).
3. Key symbols defined exactly where the code expects them.
Run: py tools/static_check.py
"""
import re
import sys
from pathlib import Path

root = Path('.').resolve()
errors = []
warnings = []

# ---------- 1. import resolution ----------
import_re = re.compile(r"^\s*import\s+'([^']+)'", re.M)
pkg_re = re.compile(r"^package:vyra/(.+)$")

dart_files = sorted(
    [p for p in (root / 'lib').rglob('*.dart')]
    + [p for p in (root / 'test').rglob('*.dart')]
)
print(f'[{len(dart_files)}] dart files scanned')

for f in dart_files:
    src = f.read_text(encoding='utf-8')
    for imp in import_re.findall(src):
        if imp.startswith('package:vyra/'):
            rel = pkg_re.match(imp).group(1)
            target = root / 'lib' / rel
        elif imp.startswith('package:'):
            continue  # third-party; can't resolve without pub cache
        elif imp.startswith('dart:'):
            continue
        else:
            # relative import: resolve from the file's directory
            target = (f.parent / imp).resolve()
        if not target.exists():
            errors.append(f'UNRESOLVED IMPORT {imp} in {f}')

# ---------- 2. brace balance (string/comment aware) ----------
def strip_dart(src):
    out = []
    i, n = 0, len(src)
    state = 'code'  # code | line_comment | block_comment | str | rawstr | triple
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ''
        if state == 'code':
            if c == '/' and nxt == '/':
                state = 'line_comment'; i += 2; continue
            if c == '/' and nxt == '*':
                state = 'block_comment'; i += 2; continue
            if c == "'" or c == '"':
                state = 'str'; i += 1; continue
            if c == 'r' and nxt in "'\"":
                state = 'rawstr'; i += 2; continue
            out.append(c); i += 1; continue
        if state == 'line_comment':
            if c == '\n':
                state = 'code'; out.append('\n')
            i += 1; continue
        if state == 'block_comment':
            if c == '*' and nxt == '/':
                state = 'code'; i += 2; continue
            i += 1; continue
        if state == 'str':
            if c == '\\':
                i += 2; continue
            if c == "'" or c == '"':
                state = 'code'
            i += 1; continue
        if state == 'rawstr':
            if c in "'\"":
                state = 'code'
            i += 1; continue
    return ''.join(out)

pairs = {'(': ')', '[': ']', '{': '}'}
for f in dart_files:
    src = f.read_text(encoding='utf-8')
    code = strip_dart(src)
    stack = []
    bad = None
    for ch in code:
        if ch in pairs:
            stack.append(ch)
        elif ch in pairs.values():
            if not stack or pairs[stack[-1]] != ch:
                bad = ch
                break
            stack.pop()
    if bad or stack:
        errors.append(f'UNBALANCED BRACES in {f} (open left: {len(stack)})')

# ---------- 3. key symbol cross-reference ----------
symbols = {
    # symbol -> expected defining file (any of these)
    'class ReminderScheduler': ['lib/data/services/reminder_service.dart'],
    'class LocalReminderScheduler': ['lib/data/services/reminder_service.dart'],
    'shouldScheduleReminder': ['lib/data/services/reminder_service.dart'],
    'resyncAll': ['lib/data/services/reminder_service.dart', 'lib/application/habits/habit_providers.dart'],
    'resyncReminders': ['lib/application/habits/habit_providers.dart', 'lib/presentation/screens/settings/settings_screen.dart'],
    'pendingReminderRoute': ['lib/data/services/reminder_service.dart', 'lib/app.dart', 'lib/main.dart'],
    'appReminderScheduler': ['lib/data/services/reminder_service.dart', 'lib/application/providers/app_providers.dart', 'lib/main.dart'],
    'class WeekReview': ['lib/domain/services/week_review.dart'],
    'WeekReviewService': ['lib/domain/services/week_review.dart', 'lib/application/analytics/week_review_provider.dart', 'test/week_review_test.dart'],
    'weekReviewProvider': ['lib/application/analytics/week_review_provider.dart', 'lib/presentation/screens/analytics/week_review_screen.dart'],
    'toggleDay': ['lib/application/habits/habit_providers.dart', 'lib/presentation/screens/habits/habit_detail_screen.dart'],
    'toggleCount': ['lib/domain/services/habit_stats.dart', 'lib/application/habits/habit_providers.dart', 'test/habit_toggle_test.dart'],
    'isDayEnabled': ['lib/core/widgets/month_calendar.dart', 'lib/presentation/screens/habits/habit_detail_screen.dart'],
    'weekdayName': ['lib/core/utils/date_utils.dart', 'lib/domain/services/week_review.dart'],
    'onSelectDay': ['lib/core/widgets/month_calendar.dart', 'lib/presentation/screens/habits/habit_detail_screen.dart'],
}
files_by_name = {p.name: p for p in dart_files}
for sym, expected in symbols.items():
    found = [str(p) for p in dart_files if sym in p.read_text(encoding='utf-8')]
    missing = [e for e in expected if str(root / e) not in found]
    if missing:
        errors.append(f'SYMBOL {sym!r} not found in expected file(s): {missing}')

# ---------- summary ----------
print()
if errors:
    print(f'FAIL: {len(errors)} issue(s)')
    for e in errors:
        print('  -', e)
    sys.exit(1)
print('PASS: all imports resolve, braces balanced, expected symbols present')
