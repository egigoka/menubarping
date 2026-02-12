# MenubarPing (SwiftUI)

Native macOS menubar rewrite of `menubar_ping` using SwiftUI and Swift Concurrency.

## What It Does

- Runs continuous connectivity checks:
- ICMP ping for hosts (default includes `8.8.8.8`)
- HTTP checks for Apple (`captive.apple.com`) and Microsoft (`msftncsi.com`)
- Public IP and country lookup (`api.ipify.org`, `ipinfo.io`)
- Updates menubar title with country + per-check emojis
- Shows `🚫` in menubar when VPN safety check detects a risky country (`ru`, `kz`, `cn`)
- Sends notifications for connectivity transitions/failures (VPN state uses emoji only)

## Build And Install

```bash
./build_and_install.sh
```

## Open In Xcode

- `open MenubarPing.xcodeproj`

## Structure

- `MenubarPing/`: app and logic code
- `MenubarPing/Info.plist`: app info (`LSUIElement=true`)
- `MenubarPing/MenubarPing.entitlements`: network client entitlement
- `MenubarPing/Assets.xcassets/`: app icon catalog

## Notes

- Settings persist via `UserDefaults`.
- Ping interval, ignored timeouts, optional checks, and custom domains are configurable from the menu UI.
