# Contributing

Thank you for your interest in XM6 Hub.

## Getting started

```bash
git clone https://github.com/sahana-n-h/xm6hub.git
cd xm6hub
brew install xcodegen cmake
./scripts/install-local.sh
```

`vendor/SonyHeadphonesClient/` is a vendored copy of upstream libmdr and is already
included in the repository.

## Pull requests

1. Open an issue first for large changes (new device families, protocol work, UI redesigns).
2. Keep changes focused — one feature or fix per PR when possible.
3. Match existing Swift style and naming in `XM6Hub/`.
4. Test on macOS 14+ with a paired WH-1000XM6 when touching Bluetooth or device code.
5. Do not commit personal `DEVELOPMENT_TEAM` values or build artifacts (`build/`, `dist/`).

## libmdr / protocol changes

Bluetooth protocol and libmdr changes usually belong in
[SonyHeadphonesClient](https://github.com/mos9527/SonyHeadphonesClient) upstream.
Open an issue here if XM6 Hub needs a vendor tree update after upstream merges.

## License

By contributing, you agree that your contributions will be licensed under the
MIT License in `LICENSE`.
