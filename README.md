# XM6 Hub

Menu bar app for the Sony WH-1000XM6. Uses [libmdr](https://github.com/mos9527/SonyHeadphonesClient) (vendored in `vendor/SonyHeadphonesClient/`).

Not affiliated with Sony.

## Requirements

- macOS 14+
- Xcode 15+
- `brew install xcodegen cmake`
- WH-1000XM6 paired in System Settings → Bluetooth

## Build & run

```bash
git clone https://github.com/sahana-n-h/xm6hub.git
cd xm6hub
./scripts/install-local.sh
```

Or open in Xcode:

```bash
xcodegen generate
open XM6Hub.xcodeproj
```

Release build + widget App Groups: set `DEVELOPMENT_TEAM` in `Config.xcconfig`.

## License

MIT. See [LICENSE](LICENSE). Third-party notices in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
