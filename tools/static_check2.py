"""Verification pass 2:
1. Every `implements X` class in lib+test overrides all interface members.
2. pubspec.yaml parses as YAML (if PyYAML available).
"""
import re
import sys
from pathlib import Path

root = Path('.').resolve()
errors = []

# ---------- 1. interface conformance ----------
dart_files = sorted(
    [p for p in (root / 'lib').rglob('*.dart')]
    + [p for p in (root / 'test').rglob('*.dart')]
)

# find abstract interface classes and their member signatures
member_re = re.compile(
    r'^\s{2}(?:Future<[^>]+>|Future|void|bool|String\??|int\??|double\??|List<[^>]+>|Map<[^>]+>|Stream<[^>]+>|[A-Z]\w*\??)\s+(\w+)\s*\([^)]*\)\s*;',
    re.M,
)
interface_re = re.compile(r'^\s*abstract\s+(?:interface\s+)?class\s+(\w+)', re.M)

interfaces = {}
for f in dart_files:
    src = f.read_text(encoding='utf-8')
    for m in interface_re.finditer(src):
        name = m.group(1)
        if name in interfaces:
            continue
        # collect members until the class body closes (rough: next top-level keyword)
        body = src[m.end():]
        members = set(member_re.findall(body[: body.find('\n}\n') if '\n}\n' in body else len(body)]))
        interfaces[name] = members

impl_re = re.compile(r'^\s*class\s+\w+\s+implements\s+(\w+)\s*\{', re.M)
rtype = r'(?:Future<[^>]+>|Future|void|bool|String\??|int\??|double\??|List<[^>]+>|Map<[^>]+>|Stream<[^>]+>|[A-Z]\w*\??)'
override_re = re.compile(r'@override\s*\n\s*' + rtype + r'\s+(\w+)\s*\(', re.M)

for f in dart_files:
    src = f.read_text(encoding='utf-8')
    for m in impl_re.finditer(src):
        iface = m.group(1)
        if iface not in interfaces:
            continue
        body = src[m.end():]
        overridden = set(override_re.findall(body))
        missing = interfaces[iface] - overridden
        if missing:
            errors.append(f'{f}: class implements {iface} but misses members {sorted(missing)}')

# ReminderScheduler-specific: the test fake must implement the full interface
rs_src = (root / 'lib/data/services/reminder_service.dart').read_text(encoding='utf-8')
test_src = (root / 'test/reminder_service_test.dart').read_text(encoding='utf-8')
if 'implements ReminderScheduler' in test_src:
    # crude: every abstract member name must appear as @override in the fake block
    fake_block = test_src[test_src.find('implements ReminderScheduler'):]
    fake_block = fake_block[: fake_block.find('\n}\n')]
    for member in interfaces.get('ReminderScheduler', set()):
        if member not in fake_block:
            errors.append(f'test fake for ReminderScheduler missing @override for {member}')

# ---------- 2. pubspec YAML ----------
try:
    import yaml  # type: ignore

    yaml.safe_load((root / 'pubspec.yaml').read_text(encoding='utf-8'))
    print('pubspec.yaml: valid YAML (PyYAML)')
except ImportError:
    print('pubspec.yaml: PyYAML unavailable — skipping YAML parse')
except Exception as e:
    errors.append(f'pubspec.yaml failed YAML parse: {e}')

# ---------- summary ----------
print()
if errors:
    print(f'FAIL: {len(errors)} issue(s)')
    for e in errors:
        print('  -', e)
    sys.exit(1)
print('PASS: interface implementations complete')
