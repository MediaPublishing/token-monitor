#!/usr/bin/env python3
"""Validate prebuilt local-release assets before publishing them without a CI rebuild."""
import argparse
import importlib.util
import plistlib
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPARKLE = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'


def run(*args):
    subprocess.run(list(map(str, args)), check=True)


def verify(directory):
    spec = importlib.util.spec_from_file_location('apple_distribution', ROOT / 'scripts/apple-distribution.py')
    signing = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(signing)
    info = plistlib.loads((ROOT / 'Sources/TokenMonitorApp/Resources/Info.plist').read_bytes())
    version, build = info['CFBundleShortVersionString'], info['CFBundleVersion']
    name = f'TokenMonitor-{version}-{build}-macOS.zip'
    update = directory / name
    release = directory / 'TokenMonitor-macOS.zip'
    if update.read_bytes() != release.read_bytes():
        raise ValueError('GitHub and Sparkle archives differ')
    items = ET.parse(directory / 'appcast.xml').findall('./channel/item')
    if len(items) != 1:
        raise ValueError('Expected one release item')
    item = items[0]
    if item.findtext(SPARKLE + 'version') != build or item.findtext(SPARKLE + 'shortVersionString') != version:
        raise ValueError('Appcast version mismatch')
    enclosure = item.find('enclosure')
    expected_url = f'https://mediapublishing.github.io/token-monitor/updates/{name}'
    expected = {'url': expected_url, 'length': str(update.stat().st_size)}
    if enclosure is None or any(enclosure.get(k) != v for k, v in expected.items()):
        raise ValueError('Appcast does not match the release')
    run('swift', ROOT / 'scripts/verify-update-signature.swift', update,
        info['SUPublicEDKey'], enclosure.get(SPARKLE + 'edSignature', ''))
    dmg = directory / 'TokenMonitor-macOS.dmg'
    signing.verify_code(dmg, runtime=False)
    run('xcrun', 'stapler', 'validate', dmg)
    run('spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', dmg)
    with tempfile.TemporaryDirectory(prefix='token-monitor-signed-verify-') as temp:
        run('ditto', '-x', '-k', release, temp)
        app = Path(temp) / 'TokenMonitor.app'
        actual = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        for key in ('CFBundleShortVersionString', 'CFBundleVersion'):
            if actual[key] != info[key]:
                raise ValueError('Archive version mismatch')
        run('python3', ROOT / 'scripts/apple-distribution.py', 'verify', app, '--notarized')
        mount = Path(temp) / 'mount'
        mount.mkdir()
        run('hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', mount, dmg)
        try:
            mounted_app = mount / 'TokenMonitor.app'
            run('python3', ROOT / 'scripts/apple-distribution.py', 'verify', mounted_app, '--notarized')
            for relative in ('Contents/Info.plist', 'Contents/MacOS/TokenMonitorApp',
                             'Contents/_CodeSignature/CodeResources'):
                if (app / relative).read_bytes() != (mounted_app / relative).read_bytes():
                    raise ValueError('DMG and ZIP apps differ')
        finally:
            run('hdiutil', 'detach', mount)
    print(f'Verified signed release {version} ({build})')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    verify(parser.parse_args().directory.resolve())
