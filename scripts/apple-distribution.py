#!/usr/bin/env python3
"""Developer ID validation and explicitly requested notarization. Never creates credentials."""
import argparse
import json
import plistlib
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIREMENT = ('anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists '
               'and certificate leaf[field.1.2.840.113635.100.6.1.13] exists')
MACHO = {bytes.fromhex(x) for x in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
                                  'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}
FORBIDDEN = {'com.apple.security.get-task-allow', 'com.apple.security.cs.disable-library-validation',
             'com.apple.security.cs.allow-dyld-environment-variables',
             'com.apple.security.cs.allow-unsigned-executable-memory',
             'com.apple.security.cs.disable-executable-page-protection'}


def require(value, message):
    if not value:
        raise ValueError(message)


def run(*args, timeout=60):
    return subprocess.run(list(map(str, args)), capture_output=True, check=True, timeout=timeout)


def team_id():
    team = (ROOT/'packaging/apple-developer-team-id.txt').read_text().strip()
    require(re.fullmatch(r'[A-Z0-9]{10}', team), 'Invalid configured Apple team')
    return team


def identity(value):
    # Identity listing contains public certificate metadata only.
    listing = run('security', 'find-identity', '-v', '-p', 'codesigning').stdout.decode()
    matches = re.findall(r'\d+\) ([0-9A-Fa-f]{40}) "([^"]+)"', listing)
    require(any((value.upper() == sha.upper() or value == name)
                and name.startswith('Developer ID Application:')
                and name.endswith(f'({team_id()})') for sha, name in matches),
            'Existing valid Developer ID Application identity for configured team required')


def verify_code(path, runtime=True):
    run('codesign', '--verify', '--strict', '-R', '=' + REQUIREMENT, path)
    metadata = run('codesign', '-dv', '--verbose=4', path).stderr.decode()
    require(f'TeamIdentifier={team_id()}' in metadata.splitlines(), 'Wrong or missing Apple team')
    require(re.search(r'^Authority=Developer ID Application:', metadata, re.M), 'Developer ID required')
    require(re.search(r'^Timestamp=.+$', metadata, re.M), 'Secure timestamp required')
    if runtime:
        require(re.search(r'^CodeDirectory .*flags=.*\bruntime\b', metadata, re.M), 'Hardened runtime required')
        raw = run('codesign', '-d', '--entitlements', '-', '--xml', path).stdout
        entitlements = plistlib.loads(raw) if raw.strip() else {}
        require(not any(entitlements.get(key) for key in FORBIDDEN), 'Unsafe signing entitlement')


def verify(app, notarized=False):
    require(app.is_dir() and not app.is_symlink(), 'Regular app required')
    info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    expected = plistlib.loads((ROOT/'Sources/TokenMonitorApp/Resources/Info.plist').read_bytes())
    for key in ('CFBundleIdentifier', 'SUPublicEDKey', 'SUFeedURL'):
        require(info.get(key) == expected[key], f'Changed application/update identity: {key}')
    run('codesign', '--verify', '--deep', '--strict', app)
    verify_code(app)
    count = 0
    for path in sorted(app.rglob('*')):
        if path.is_symlink():
            require(path.resolve().is_relative_to(app.resolve()), 'Escaping bundle symlink')
        elif path.is_file():
            with path.open('rb') as stream:
                is_code = stream.read(4) in MACHO
            if is_code:
                verify_code(path)
                count += 1
    require(count > 0, 'No executable code found')
    if notarized:
        run('xcrun', 'stapler', 'validate', app)
        run('spctl', '--assess', '--type', 'execute', app)
    return {'teamID': team_id(), 'codeObjects': count, 'notarized': notarized}


def notarize(path, profile, receipt):
    require(not receipt.exists(), 'Receipt already exists; use a fresh output directory')
    is_app = path.suffix == '.app'
    require(is_app or path.suffix == '.dmg', 'Only app or DMG notarization supported')
    if is_app:
        verify(path)
    else:
        verify_code(path, runtime=False)
    with tempfile.TemporaryDirectory(prefix='token-monitor-notary-') as temp:
        archive = Path(temp)/'TokenMonitor-notarization.zip' if is_app else path
        if is_app:
            run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', path, archive, timeout=120)
        # EXTERNAL UPLOAD: run only after concrete artifact + Apple approval.
        result = run('xcrun', 'notarytool', 'submit', archive, '--keychain-profile', profile,
                     '--wait', '--timeout', '20m', '--output-format', 'json', timeout=1260)
        submission = json.loads(result.stdout)
        receipt.write_text(json.dumps(submission, indent=2)+'\n')
        require(submission.get('status') == 'Accepted', 'Apple did not accept artifact; no release allowed')
    run('xcrun', 'stapler', 'staple', path, timeout=120)
    run('xcrun', 'stapler', 'validate', path)
    if is_app:
        verify(path, notarized=True)
    else:
        run('spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('identity').add_argument('identity')
    check = sub.add_parser('verify'); check.add_argument('app', type=Path)
    check.add_argument('--notarized', action='store_true')
    submit = sub.add_parser('notarize', help='Uploads the named artifact to Apple; separate approval required')
    submit.add_argument('artifact', type=Path); submit.add_argument('--profile', required=True)
    submit.add_argument('--receipt', required=True, type=Path)
    args = parser.parse_args()
    if args.command == 'identity': identity(args.identity)
    elif args.command == 'verify': print(json.dumps(verify(args.app, args.notarized)))
    else: notarize(args.artifact, args.profile, args.receipt)


if __name__ == '__main__':
    main()
