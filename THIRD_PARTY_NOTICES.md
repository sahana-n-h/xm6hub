# Third-Party Notices

XM6 Hub includes or depends on the following third-party software. This file
satisfies attribution requirements for redistribution and open-source publication.

## libmdr / SonyHeadphonesClient (vendored)

- **Location:** `vendor/SonyHeadphonesClient/`
- **Upstream:** https://github.com/mos9527/SonyHeadphonesClient (`rewrite` branch)
- **License:** MIT License
- **Copyright:** Copyright (c) 2026 mos9527, Amr Satrio and other contributors
- **Full license text:** `vendor/SonyHeadphonesClient/LICENSE`

This repository contains a **vendored copy** of SonyHeadphonesClient (not a git
submodule). XM6 Hub statically links against **libmdr** from that tree. Bluetooth
device communication, protocol handling, and much of the low-level headphone logic
come from libmdr.

SonyHeadphonesClient describes itself as a spiritual successor to
[Plutoberth's original SonyHeadphonesClient](https://github.com/Plutoberth/SonyHeadphonesClient).

To update the vendored copy, sync `vendor/SonyHeadphonesClient/` from upstream and
commit the changes.

**Not bundled in XM6 Hub:** the SDL3 / Dear ImGui desktop client in the upstream
repository is not linked into XM6 Hub. Only libmdr and its platform support are built.

## {fmt} (fetched at build time by libmdr)

- **Upstream:** https://github.com/fmtlib/fmt (tag 12.1.0, via libmdr CMake)
- **License:** MIT License
- **Copyright:** Copyright (c) 2012 - present, Victor Zverovich and {fmt} contributors

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

{fmt} is downloaded into `build/libmdr/_deps/fmt-src/` on first build and linked
statically into XM6 Hub.

## System / Apple frameworks

XM6 Hub uses the following platform components (not bundled):

| Component | Use |
|-----------|-----|
| **SwiftUI / Swift Charts** | User interface and battery history chart |
| **SQLite3** | Local battery history storage |
| **IOBluetooth / CoreWLAN / CoreLocation / EventKit** | Device and context features |
| **WidgetKit** | Notification Center battery widget |

## Trademarks

**Sony**, **WH-1000XM6**, and **Sound Connect** are trademarks of Sony Corporation.
XM6 Hub is an independent, community-built project and is **not affiliated with,
endorsed by, or sponsored by Sony Corporation**.
