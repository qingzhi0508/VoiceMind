# Optional Remote Access

## Default Policy

VoiceMind for macOS defaults to local network access only:

- QR pairing only publishes a private IPv4 LAN address.
- The macOS socket server only accepts peers from private IPv4 ranges:
  - `10.0.0.0/8`
  - `172.16.0.0/12`
  - `192.168.0.0/16`
- Public IP, port forwarding, and internet-exposed pairing are intentionally unsupported by default.

This keeps the default setup aligned with the product expectation that Mac and iPhone are on the same local network during pairing.

## If Remote Access Is Needed Later

Remote access should be treated as an explicit product feature, not a small config tweak. At minimum, future work should address:

1. Address publishing

- Do not reuse the current QR payload directly.
- Introduce an explicit remote connection mode with its own address source and UI copy.
- Make it clear to users when a connection leaves the local network boundary.

2. Transport security

- Add authenticated encryption for the transport itself, not only post-pairing message validation.
- Prefer TLS with certificate pinning or a similarly strong trust model.
- Revisit pairing secrets, expiration, replay protection, and device trust revocation.

3. Network traversal

- Decide whether remote connectivity relies on:
  - manual public host configuration
  - port forwarding
  - relay service
  - VPN / mesh network
- Each option has different reliability, UX, and security tradeoffs.

4. Access control

- Add an explicit server-side switch for allowing remote peers.
- Log remote connection attempts separately from LAN connections.
- Consider rate limiting, allowlists, and remote-session approval prompts.

5. Product UX

- Add separate copy for LAN pairing vs remote pairing.
- Show the current trust boundary in the UI so users know whether they are pairing locally or remotely.
- Document troubleshooting for NAT, firewall, relay, or VPN behavior.

## Recommended Future Direction

If remote access becomes important, the safest direction is usually:

- keep the current LAN-only mode as the default
- add a separate opt-in remote mode
- implement remote mode through a well-defined relay or VPN-style path instead of exposing the raw socket server to the internet

That preserves the simple local-network onboarding flow while keeping remote connectivity as an intentional, reviewable capability.
