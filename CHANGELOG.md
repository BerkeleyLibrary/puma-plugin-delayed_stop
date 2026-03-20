# Changelog

## 0.1.1 (2026/03/20)

- Fix `uninitialized constant Puma::Plugin` error when Bundler auto-requires the gem before Puma is loaded

## 0.1.0 (2026/03/19)

- Initial release
- Supports Puma 5, 6, and 7
- Configurable signal via `PUMA_DELAYED_STOP_SIGNAL` (default: `QUIT`)
- Configurable drain period via `PUMA_DELAYED_STOP_DRAIN_SECONDS` (default: `5`)
- Validates that the configured signal does not conflict with Puma's built-in signal handlers
