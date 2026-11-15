# In-app VPN (PacketTunnel)

`PacketTunnel/vpn/**` and `PacketTunnelProvider.swift` are a port of the iOS
packet tunnel in [ProxyPin](https://github.com/wanghongenpin/proxypin) 1.4.0
(Apache License 2.0 — see `LICENSE-ProxyPin.txt`). The only changes are the
target it builds into and this document.

## What it does

- **HTTP proxy mode (default)** — sets `NEProxySettings` for the whole device, so
  every app's HTTP/HTTPS traffic leaves through the proxy. This is the mode the
  activation screen uses.
- **IP mode** (`ipProxy: true`) — `ProxyVpnService` reads raw packets from
  `NEPacketTunnelFlow` and forwards TCP/UDP to the proxy address itself.

## Why it may report "Unavailable"

Starting a tunnel requires the **Network Extension** entitlement:

```
com.apple.developer.networking.networkextension = [ packet-tunnel-provider ]
com.apple.developer.networking.vpn.api          = [ allow-vpn ]
```

Those can only be signed with an Apple Developer Program profile (paid) that has
the Network Extension capability enabled for both bundle ids:

- app: `com.apple.mobile.MobileHouseArrest`
- extension: `com.apple.mobile.MobileHouseArrest.tunnel`

`PacketTunnel/PacketTunnel.entitlements` holds them, but it is **not wired into
the build on purpose**: an unsigned/sideload IPA that carries these entitlements
fails to install with a free certificate. To enable the feature:

1. Create an explicit App ID for both identifiers with Network Extension enabled.
2. Set `CODE_SIGN_ENTITLEMENTS = PacketTunnel/PacketTunnel.entitlements` on the
   `PacketTunnel` target, and add an equivalent file to the app target.
3. Sign with that profile (Xcode automatic signing, or `scripts/resign-ipa.sh`
   with the matching `.mobileprovision`).

Without that profile the app itself is unaffected: the card shows "Unavailable"
and the proxy-in-app transport (URLSession through the proxy) still works.
