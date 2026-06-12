# Cecil Recovery Guide

This guide tracks the Cecil-owned build recovery. Public source should keep
provider secrets out of Git: panel hosts, DNS TXT hosts, bootstrap proxy URIs,
support IDs, update endpoints, signing files, test accounts, and auth tokens
must stay in private files, DNS, CI secrets, or local build parameters.

## Recovery Priorities

1. Authentication and session gate
   - Show a full-screen login flow before the app shell.
   - Email and password login must fetch the subscription automatically.
   - Never show the raw subscription URL.
   - Failed login, failed token refresh, failed subscription sync, or blocked
     backend access must not unlock the main proxy UI.
   - One-click import must support the Cecil URI scheme.

2. DNS-delivered merchant config
   - Merchant config is encrypted and delivered through DNS TXT.
   - Build-time secrets only decrypt the DNS payload.
   - Keep bootstrap proxy, support target, panel/API URLs, update endpoints,
     delay multiplier, home URL, and display name out of committed source.

3. Bootstrap proxy for backend access
   - When configured, panel API and subscription requests must route through the
     bootstrap proxy.
   - Proxy details must not appear in UI, user logs, or public source.

4. Cecil account and more page
   - Show app name, user data, announcements, tutorials, tickets, purchase,
     website, support, disclaimer, about, and logout.
   - Keep the page compact on mobile through grouping/collapse behavior.
   - Hide upstream backup/restore and unrelated generic entries.
   - Remove release-blocking development badges.

5. Rich content
   - Announcements, tutorials, tickets, and plan descriptions must render
     Markdown, HTML, inline styles, images, SVG, and links where supported.
   - Markdown links should render as links, not raw source text.
   - Image failures should not degrade into broken or misleading content.

6. Purchase, orders, and payment
   - Plans should be grouped by category and billing cycle.
   - Default cycle should be monthly where available.
   - Plan cards should be compact and close to the Cecil website design.
   - Order detail must support cancel and continue payment.
   - Mobile payment handoff should open payment apps when available and poll
     order status after return.

7. Support
   - Support should open inside the app when possible.
   - Android support supports close/back/floating entry behavior and can be
     reopened after floating entry dismissal.
   - Windows support uses a non-blocking in-app WebView window and must not
     crash the main app.

8. Branding
   - App name, launcher icon, installer icon, splash logo, about page, URI
     scheme, executable names, helper service names, and update metadata must
     be Cecil branded.
   - Splash animation should be full-screen and must not reveal navigation
     before authentication completes.
   - About version starts from 1.0.0 and uses Cecil wording.

9. Proxy page
   - Add refresh subscription action on the proxy page.
   - Nodes should only appear after a valid subscription import.
   - YAML/subscription parsing errors should be caught and shown clearly.
   - Delay display should use the configured multiplier.

10. Packaging and update
    - Android should support modern and older target devices agreed during
      validation.
    - Windows uses the compatible build path and targets Windows 7 through 11
      as far as the Flutter/WebView2 toolchain allows.
    - Release artifacts stay under `dist/` and out of Git.

## Execution Order

1. Fix visible text, localization, and corrupted strings.
2. Verify login/session/subscription gate.
3. Verify DNS merchant config and bootstrap proxy behavior.
4. Verify rich announcement/tutorial/plan rendering.
5. Verify purchase, order, cancel, continue payment, and polling.
6. Verify support windows on Android and Windows.
7. Verify icons, splash, about page, package names, and installers.
8. Run analyze, Android build, Windows build, privacy scan, and push.

## Verification Checklist

- `flutter analyze`
- Android arm64 and arm release builds
- Windows compatible installer build
- Privacy scan for plaintext panel/support/proxy/DNS secrets
- Manual login, subscription refresh, connect/disconnect, rich content, ticket
  reply, purchase/payment, support, disclaimer, logout, and update checks
