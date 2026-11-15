import json
import sys
import re

devices = json.load(sys.stdin)["devices"]
def version(runtime):
    return tuple(int(n) for n in re.findall(r'\d+', runtime.split('iOS-')[-1]))

sdk = tuple(int(n) for n in sys.argv[1].split('.'))
for runtime in sorted(devices, key=version, reverse=True):
    if "iOS" not in runtime:
        continue
    if version(runtime) > sdk:
        continue
    for device in devices[runtime]:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No available iPhone simulator: tests cannot be reported as passed.")
