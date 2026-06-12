# Dialogue Recovery Plan

This document turns the product decisions from the implementation dialogue into
a neutral recovery plan for the `Bettbox-Cecil` repository.

No merchant-specific domains, support IDs, bootstrap proxy credentials, DNS TXT
hosts, signing keys, private logos, or update endpoints belong in this file or
in the public source tree. Those values must be provided by build-time
configuration, local files, CI secrets, or a private deployment process.

## Source Of Truth

- Use this repository as the clean recovery target.
- Use a clean Bettbox source tree as the implementation baseline.
- Use the previously edited local tree only as a reference for recoverable
  ideas. Do not copy private configuration or corrupted files.
- Use the dialogue-derived requirements below to rebuild missing behavior in
  small, reviewable commits.

## Requirement Categories

### 1. Product Scope

- The app is a dedicated white-label proxy client for a single service
  provider.
- Users log in with email and password.
- After login, the app automatically obtains the user's subscription.
- The subscription URL is not displayed to the user.
- Primary supported platforms are Android and Windows.
- Other platforms may keep upstream Bettbox behavior until explicitly adapted.

### 2. Generic White-Label Configuration

- Display name, package ID, URI scheme, official website URL, update manifest
  URLs, support URL, V2Board panel URL, API base URL, bootstrap proxy URI, delay
  multiplier, and optional remote encrypted config must be configurable.
- Public source must not hard-code a specific provider.
- Support must be vendor-neutral: Crisp, Intercom, Telegram bot pages, custom
  H5 support systems, or self-hosted ticket systems should all be possible.
- Online update endpoints must be configurable separately for Android and
  Windows.
- Build artifacts and signing materials must remain out of Git.

### 3. Authentication And Session Gate

- Add a login page before the main app shell.
- Do not show the main navigation before a valid session is available.
- Failed login or failed token refresh must not allow entry into the proxy UI.
- A network error after a previous session should not silently unlock the app
  unless the cached session is still explicitly valid.
- Add logout, clear session, and return to login.
- Support one-click login/import through a custom URI:
  `yourapp://install-config?authData=<auth-data>`.

### 4. V2Board / xiaoV2b API Integration

- Implement a small API client for login, user info, subscription, notices,
  knowledge/tutorials, tickets, plans, orders, and payments.
- Keep API base URL configurable and compatible with common V2Board-like
  deployments.
- Fetch and store only the authenticated subscription result needed by the
  client.
- Provide clear error messages for invalid credentials, expired plans, missing
  plans, blocked panel access, and unexpected API responses.

### 5. Bootstrap Proxy For Backend Access

- If configured, start a temporary local proxy from the bootstrap node before
  panel API or subscription requests.
- Route panel and subscription HTTP requests through that local proxy when
  direct access is unreliable.
- If no bootstrap proxy is configured, use direct access.
- The proxy URI is sensitive and must come from private configuration.
- Avoid exposing bootstrap proxy details in UI or logs.

### 6. Subscription And Proxy UI

- Automatically import/update the authenticated subscription after login.
- Add a refresh subscription action on the proxy page.
- Keep node display and selection behavior consistent with Bettbox.
- Preserve working connect/start behavior only after subscription import has
  succeeded.
- Avoid YAML parsing crashes by validating subscription responses before import.

### 7. Main UI And Account Area

- More/account page should show app name, user data, plan/traffic/expiry, and
  logout.
- Account service entries should be grouped or collapsible so the page remains
  compact on mobile.
- Remove or hide unrelated upstream entries when they do not fit the provider
  workflow, such as generic backup/restore for a locked white-label client.
- Remove development/pre-release badges from release builds.
- The disclaimer should be provider-configurable and, after acceptance, should
  not appear again unless the text/version changes.

### 8. Notice, Tutorial, Ticket, Purchase, And Order Pages

- Notices must support rich content: HTML, Markdown, inline styles, links,
  images, and SVG where the platform renderer allows it.
- Tutorials must support the same rich content and should correctly render
  Markdown links instead of showing raw `[[title]](url)` text.
- Tickets must list, create, view, and reply to tickets.
- Purchase flow must show plans grouped by category, with cycle filters such as
  monthly/yearly where the API data supports it.
- Default purchase filter should be monthly when available.
- Plan cards should be compact and close to the provider site's presentation,
  while still remaining generic.
- Plan descriptions must render rich HTML/Markdown/inline styles.
- Order detail must include cancel order when the API permits it.
- Payment page must handle web payment pages and external app schemes without
  crashing. On mobile, payment apps should be opened through intent/deep-link
  handling when available, with useful fallback messages.

### 9. Support Entry

- Support opens inside the app when possible.
- On desktop, support should use an in-app webview window or non-blocking
  support window and must not crash the main app.
- On Android, closing support with the close button should dismiss it; returning
  with back may leave a floating entry when designed to do so.
- Long-press or explicit close should only close the current floating instance,
  and reopening support later must be able to create it again.
- The implementation must not assume a specific support vendor.

### 10. Branding And Assets

- App name, launcher icon, splash logo, installer icon, and about-page branding
  must be configurable or replaceable.
- Public template assets must be neutral placeholders.
- Provider-specific logos and generated logo concepts must not be committed to
  the generic repository unless they are explicitly licensed for reuse.
- Splash screen should be full-screen and should not reveal the main navigation
  before authentication completes.

### 11. About, Links, And Legal Text

- About page versioning should start from the provider build version, not
  upstream experimental labeling.
- About text should describe the white-label app generically as a Mihomo-based
  proxy client.
- Official website and community/support links must be configurable.
- Contributor lists should preserve required upstream license attribution while
  allowing the provider UI to hide non-user-facing lists.
- Disclaimer text must be configurable by provider.

### 12. Packaging And Update

- Android builds need independent package ID, signing, launcher icon, URI
  scheme registration, and update metadata.
- Windows builds need independent executable name, installer metadata, URI
  scheme registration, helper service name, icon, and update metadata.
- Android should support modern devices and a reasonable older-device baseline
  agreed during build validation.
- Windows compatibility target should be verified against the Flutter/WebView2
  toolchain used by the project.
- Release packages should be produced outside Git and documented in the release
  process.

## Recovery Sequence

1. Create a clean `Bettbox-Cecil` repository copy.
2. Audit the repository for private values and generated/binary clutter.
3. Compare the clean repository with the recoverable local Bettbox tree and copy
   only generic code.
4. Restore or reimplement build-time white-label configuration.
5. Restore authentication/session gate and one-click import.
6. Restore V2Board API client and subscription auto-import.
7. Restore optional bootstrap proxy routing for panel and subscription access.
8. Restore account/more page, user data, logout, disclaimer, and about changes.
9. Restore notice/tutorial/ticket pages with rich content rendering.
10. Restore purchase/order/payment flows.
11. Restore generic support WebView/floating support behavior.
12. Restore Android and Windows branding hooks, package metadata, update hooks,
    and URI scheme registration.
13. Run privacy scan, static checks, Android build, Windows build, and manual
    smoke tests.
14. Push reviewed commits to the public repository.

## Privacy Checklist Before Every Push

- No real provider domains or panel URLs.
- No bootstrap proxy URI or credentials.
- No support vendor ID or private support URL.
- No DNS TXT host used by a private deployment.
- No signing key, keystore password, SSH key, token, cookie, or API secret.
- No private generated logo or customer screenshot.
- No APK, EXE, build directory, local toolchain cache, or debug log.
- No test account email, password, session token, or auth data.

