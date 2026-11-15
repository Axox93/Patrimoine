import datetime
import json
import os
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import zipfile

ipa, mode = sys.argv[1:]
with zipfile.ZipFile(ipa) as z:
    assert z.testzip() is None, 'Corrupt IPA'
    info = plistlib.loads(z.read('Payload/Patrimoine.app/Info.plist'))
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS'], 'Device build required'
    assert info['UIDeviceFamily'] == [1], 'iPhone-only build required'
    binary = z.read('Payload/Patrimoine.app/' + info['CFBundleExecutable'])
    assert len(binary) > 4096 and binary[:4] in [b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'], 'Missing Mach-O executable'
    if mode == 'signed':
        assert 'Payload/Patrimoine.app/embedded.mobileprovision' in z.namelist(), 'Missing provisioning profile'
        with tempfile.TemporaryDirectory() as folder:
            z.extractall(folder)
            app = str(pathlib.Path(folder, 'Payload/Patrimoine.app'))
            subprocess.run(['codesign','--verify','--deep','--strict',app],check=True)
            details = subprocess.run(['codesign','-dv','--verbose=4',app],check=True,capture_output=True,text=True).stderr
            assert 'Signature=adhoc' not in details and 'TeamIdentifier=not set' not in details
    else:
        assert 'Payload/Patrimoine.app/embedded.mobileprovision' not in z.namelist()

metadata = {
    'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
    'built_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'commit': os.environ.get('GITHUB_SHA','local'), 'signing':mode,
    'minimum_ios':info['MinimumOSVersion'], 'bundle_id':info['CFBundleIdentifier'],
    'requires_resigning':mode == 'unsigned',
    'installation_verified_on_iphone':False
}
pathlib.Path('build/build-info.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps(metadata,indent=2))
