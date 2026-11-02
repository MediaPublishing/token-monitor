#!/usr/bin/env python3
"""Offline regression checks. No keys, identities, credential reads or uploads."""
import importlib.util
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('apple',Path(__file__).with_name('apple-distribution.py'))
apple=importlib.util.module_from_spec(spec);spec.loader.exec_module(apple)
TEAM='F7ZC4PZ39V'
GOOD=f'Authority=Developer ID Application: Fixture ({TEAM})\nTeamIdentifier={TEAM}\nTimestamp=fixture\nCodeDirectory v=20500 flags=0x10000(runtime)\n'

class DistributionTests(unittest.TestCase):
    def test_identity_requires_exact_existing_certificate_and_team(self):
        listing=' 1) '+('A'*40)+f' "Developer ID Application: Fixture ({TEAM})"\n'
        with patch.object(apple,'run',return_value=subprocess.CompletedProcess([],0,listing.encode(),b'')):
            apple.identity('A'*40)
            apple.identity(f'Developer ID Application: Fixture ({TEAM})')
            for bad in ['-', 'A'*39, 'Developer ID Application:', 'B'*40]:
                with self.subTest(bad=bad), self.assertRaises(ValueError): apple.identity(bad)
        with patch.object(apple,'run',return_value=subprocess.CompletedProcess([],0,listing.replace(TEAM,'OTHER12345').encode(),b'')), self.assertRaises(ValueError): apple.identity('A'*40)

    def test_signature_requires_team_runtime_timestamp_and_safe_entitlements(self):
        def probe(metadata,entitlements):
            def call(*args,**kwargs):
                return subprocess.CompletedProcess(args,0,plistlib.dumps(entitlements) if '--entitlements' in args else b'',metadata.encode())
            return call
        with patch.object(apple,'run',side_effect=probe(GOOD,{})): apple.verify_code(Path('/fixture'))
        for line in GOOD.splitlines():
            with self.subTest(line=line),patch.object(apple,'run',side_effect=probe(GOOD.replace(line+'\n',''),{})),self.assertRaises(ValueError): apple.verify_code(Path('/fixture'))
        for key in apple.FORBIDDEN:
            with self.subTest(key=key),patch.object(apple,'run',side_effect=probe(GOOD,{key:True})),self.assertRaises(ValueError): apple.verify_code(Path('/fixture'))

    def test_notary_rejection_stops_before_stapling(self):
        with tempfile.TemporaryDirectory() as temp:
            receipt=Path(temp)/'receipt.json'
            with patch.object(apple,'verify'),patch.object(apple,'run',return_value=subprocess.CompletedProcess([],0,b'{"status":"Invalid"}',b'')) as run:
                with self.assertRaises(ValueError): apple.notarize(Path('/fixture.app'),'fixture',receipt)
                self.assertFalse(any('stapler' in c.args for c in run.call_args_list))
                self.assertEqual(json.loads(receipt.read_text())['status'],'Invalid')

    def test_notary_acceptance_staples_then_verifies(self):
        with tempfile.TemporaryDirectory() as temp:
            with patch.object(apple,'verify') as verify,patch.object(apple,'run',return_value=subprocess.CompletedProcess([],0,b'{"status":"Accepted"}',b'')) as run:
                apple.notarize(Path('/fixture.app'),'fixture',Path(temp)/'receipt.json')
                self.assertTrue(any(c.args[:3]==('xcrun','stapler','staple') for c in run.call_args_list))
                verify.assert_called_with(Path('/fixture.app'),notarized=True)

    def test_strict_packaging_fails_before_build_without_notarize(self):
        import os
        env={k:v for k,v in os.environ.items() if not k.startswith('TOKEN_MONITOR_')}
        p=subprocess.run(['bash',str(apple.ROOT/'scripts/package-release.sh'),'--require-distribution-ready'],env=env,capture_output=True,text=True)
        self.assertNotEqual(p.returncode,0)
        self.assertIn('requires TOKEN_MONITOR_NOTARIZE=1',p.stderr)

if __name__=='__main__':unittest.main(verbosity=2)
