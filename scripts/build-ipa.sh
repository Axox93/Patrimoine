#!/bin/bash
set -euo pipefail
mkdir -p build/logs
MODE="${SIGNING_MODE:-unsigned}"
[[ "$MODE" == unsigned || "$MODE" == signed ]] || { echo "Invalid signing mode"; exit 1; }
ARCHIVE="$PWD/build/Patrimoine.xcarchive"
SIGNING_ARGS=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
TASK_KEYCHAIN=""
TASK_PROFILE=""
cleanup() {
  if [[ -n "$TASK_KEYCHAIN" ]]; then security delete-keychain "$TASK_KEYCHAIN" || true; fi
  if [[ -n "$TASK_PROFILE" ]]; then rm -f "$TASK_PROFILE"; fi
  rm -f build/certificate.p12 build/profile.mobileprovision build/profile.plist
}
trap cleanup EXIT

if [[ "$MODE" == signed ]]; then
  : "${CERTIFICATE_BASE64:?Missing IOS_CERTIFICATE_BASE64 secret}"
  : "${CERTIFICATE_PASSWORD:?Missing IOS_CERTIFICATE_PASSWORD secret}"
  : "${PROFILE_BASE64:?Missing IOS_PROFILE_BASE64 secret}"
  python3 - <<'PY'
import base64, os, pathlib
for name, filename in [('CERTIFICATE_BASE64','certificate.p12'), ('PROFILE_BASE64','profile.mobileprovision')]:
    pathlib.Path('build', filename).write_bytes(base64.b64decode(os.environ[name], validate=True))
PY
  security cms -D -i build/profile.mobileprovision > build/profile.plist
  PROFILE_UUID=$(/usr/libexec/PlistBuddy -c 'Print UUID' build/profile.plist)
  TEAM_ID=$(/usr/libexec/PlistBuddy -c 'Print TeamIdentifier:0' build/profile.plist)
  export PROFILE_UUID TEAM_ID
  python3 - <<'PY'
import datetime, os, plistlib
p = plistlib.load(open('build/profile.plist','rb'))
assert p['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), 'Expired provisioning profile'
assert p['Entitlements']['application-identifier'] == os.environ['TEAM_ID']+'.'+os.environ['IOS_BUNDLE_ID'], 'Profile must explicitly match the bundle identifier'
assert p.get('ProvisionedDevices'), 'A development or ad hoc profile with registered iPhones is required'
PY
  KEYCHAIN_PASSWORD=$(openssl rand -hex 32)
  TASK_KEYCHAIN="$RUNNER_TEMP/patrimoine-${GITHUB_RUN_ID}.keychain-db"
  security create-keychain -p "$KEYCHAIN_PASSWORD" "$TASK_KEYCHAIN"
  security set-keychain-settings -lut 21600 "$TASK_KEYCHAIN"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$TASK_KEYCHAIN"
  security import build/certificate.p12 -P "$CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$TASK_KEYCHAIN" >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$TASK_KEYCHAIN" >/dev/null
  security list-keychains -d user -s "$TASK_KEYCHAIN" login.keychain-db
  IDENTITY=$(security find-identity -v -p codesigning "$TASK_KEYCHAIN" | sed -nE 's/.* ([A-F0-9]{40}) .*/\1/p' | head -1)
  [[ -n "$IDENTITY" ]] || { echo 'No valid signing identity in certificate'; exit 1; }
  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  TASK_PROFILE="$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"
  cp build/profile.mobileprovision "$TASK_PROFILE"
  export IDENTITY
  SIGNING_ARGS=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual "DEVELOPMENT_TEAM=$TEAM_ID" "CODE_SIGN_IDENTITY=$IDENTITY" "PROVISIONING_PROFILE_SPECIFIER=$PROFILE_UUID")
fi

xcodebuild archive -project Patrimoine.xcodeproj -scheme Patrimoine -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  "PRODUCT_BUNDLE_IDENTIFIER=${IOS_BUNDLE_ID:-fr.patrimoine.personal}" \
  "CURRENT_PROJECT_VERSION=${GITHUB_RUN_NUMBER:-1}" SKIP_INSTALL=NO \
  "${SIGNING_ARGS[@]}" 2>&1 | tee build/logs/archive.log

APP="$ARCHIVE/Products/Applications/Patrimoine.app"
[[ -d "$APP" && -x "$APP/Patrimoine" ]] || { echo 'Archive has no application executable'; exit 1; }
if [[ "$MODE" == unsigned ]]; then
  if codesign -dv "$APP" 2>/dev/null; then echo 'Unexpected signature in unsigned mode'; exit 1; fi
  mkdir -p build/unsigned/Payload
  ditto "$APP" build/unsigned/Payload/Patrimoine.app
  ditto -c -k --keepParent build/unsigned/Payload build/Patrimoine-iOS.ipa
else
  python3 - <<'PY'
import os, plistlib
options = {'method': os.environ.get('EXPORT_METHOD','release-testing'), 'signingStyle':'manual',
           'teamID':os.environ['TEAM_ID'], 'signingCertificate':os.environ['IDENTITY'],
           'provisioningProfiles':{os.environ['IOS_BUNDLE_ID']:os.environ['PROFILE_UUID']},
           'manageAppVersionAndBuildNumber':False}
with open('build/ExportOptions.plist','wb') as f: plistlib.dump(options,f)
PY
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath build/export \
    -exportOptionsPlist build/ExportOptions.plist 2>&1 | tee build/logs/export.log
  cp build/export/Patrimoine.ipa build/Patrimoine-iOS.ipa
fi
python3 scripts/verify-ipa.py build/Patrimoine-iOS.ipa "$MODE"
shasum -a 256 build/Patrimoine-iOS.ipa > build/SHA256SUMS.txt
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo '### Patrimoine iOS'
    echo "- Signature : **$MODE**"
    echo "- Commit : $GITHUB_SHA"
    echo "- Build : $GITHUB_RUN_NUMBER"
    echo '- Tests du moteur et de persistance exécutés avant la création du paquet.'
    if [[ "$MODE" == unsigned ]]; then echo '- IPA non signé : une signature Apple valide est nécessaire avant toute installation.'; fi
  } >> "$GITHUB_STEP_SUMMARY"
fi
