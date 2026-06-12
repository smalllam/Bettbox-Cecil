# Dialogue Recovery Status

This file tracks the practical recovery of the white-label client from the
implementation dialogue. It is intentionally provider-neutral: no real panel
domains, support IDs, bootstrap proxy credentials, DNS hosts, signing material,
or private artwork belong here.

## Classified Dialogue Areas

1. Authentication and session gate
   - Login with email and password.
   - Do not show the main navigation before authentication.
   - Do not allow stale cached subscriptions to unlock the app after a failed
     session/subscription sync.
   - Support logout and one-click import through a custom URI scheme.

2. V2Board/xiaoV2b integration
   - Fetch authenticated subscription, user plan data, notices, tutorials,
     tickets, plans, orders, payment methods, and payment status.
   - Keep panel and API URLs configurable.
   - Hide the raw subscription URL from users.

3. Backend bootstrap proxy
   - Optional build-time bootstrap proxy URI.
   - Route panel/subscription requests through a temporary local proxy when
     direct access is unreliable.
   - Keep proxy credentials out of UI, logs, and Git.

4. Account and service center
   - Show app name, user data, plan/traffic/expiry, support, website, notices,
     tutorials, tickets, purchase, and logout.
   - Keep mobile layout compact and grouped.

5. Rich content
   - Notices, tutorials, tickets, and plan descriptions must render Markdown,
     HTML, inline style content, images, SVG, and links as far as the platform
     renderer supports them.

6. Purchase, order, and payment
   - Group plans by category and billing cycle.
   - Default recurring cycle is monthly.
   - Show plan descriptions and order detail.
   - Pending order detail includes cancel and continue payment.
   - Mobile payment pages can open external payment schemes and then poll order
     status.

7. Support window
   - Support URL is generic and can point to any support H5/vendor.
   - Desktop support uses a separate in-app WebView window.
   - Mobile support can return to a floating support entry and can be reopened.

8. Branding and splash
   - App display name, logo asset, URI scheme, installer metadata, package ID,
     and update URLs are build-time/provider configuration.
   - Public source keeps neutral placeholder assets.

9. Legal and about text
   - About description is white-label oriented.
   - Disclaimer text can be supplied by provider build configuration.
   - Disclaimer acceptance is stored and is not shown repeatedly after agree.

10. Packaging and update
    - Android and Windows build paths are supported.
    - Windows installer generation is verified with local Inno Setup.
    - Update manifest URLs are build-time/provider configuration.

## Current Recovery Status

| Area | Status | Notes |
| --- | --- | --- |
| Repository copy | Done | `Bettbox-Cecil` is an independent repository, not a branch. |
| Privacy cleanup | Done | Private Cecil domains, support IDs, DNS hosts, proxy secrets, and signing keys are excluded. |
| Login gate | Done | Main UI is blocked until subscription sync succeeds; stale local profile no longer bypasses failed sync. |
| Login localization | Done | Login form now uses simplified Chinese, traditional Chinese, or English according to locale. |
| V2Board API | Done | Generic API client covers login, subscription, notices, tutorials, tickets, plans, orders, checkout, and order status. |
| Bootstrap proxy | Done | Optional generic bootstrap proxy exists behind build-time config. |
| Account center | Done | Account/service entries are grouped through the white-label account section. |
| Rich content | Done | Shared rich renderer handles Markdown, HTML, images, SVG, links, and plan content. |
| Tickets | Done | List/create/view/reply flows are implemented. |
| Purchase/order/payment | Done | Plan filters, order detail, cancel order, WebView payment, external payment handoff, and payment polling exist. |
| Support | Done | Generic support URL opens in app on mobile and in a desktop WebView window on Windows. |
| Disclaimer | Done | Provider can pass `DISCLAIMER_TEXT`; acceptance remains stored in app settings. |
| Windows packaging | Done | Full compatible Windows installer build was verified locally. |
| Android packaging | Pending environment | Source is prepared, but final Android signing/build validation requires Android SDK/keystore setup in the build environment. |

## Next Recovery Steps

1. Run Android build validation in a machine/CI environment with Android SDK and
   signing secrets configured.
2. Add provider-specific private build scripts outside this public repository.
3. Smoke test a real provider panel:
   - login,
   - subscription import,
   - refresh subscription,
   - connect/disconnect,
   - notice/tutorial images and links,
   - ticket reply,
   - plan purchase,
   - payment return/polling,
   - logout.
4. If a provider needs backup/restore hidden more aggressively, add a
   build-time UI policy flag rather than deleting upstream code.

## Verification Commands

```bash
flutter pub get
dart run build_runner build -d
flutter analyze
dart setup.dart windows --arch amd64 --compatible
```

Before every push, scan for provider-private strings and inspect `git status`
so generated binaries, signing files, local logs, and private assets remain out
of Git.
