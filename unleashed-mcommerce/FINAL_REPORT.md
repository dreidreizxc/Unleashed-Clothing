# Unleashed Clothing — Spark-Only Order-Request Implementation

Final implementation, trust-boundary, and verification report  
Date: 2026-11-07 (editorial redesign pass)  
Firebase project: `unleashed-clothing` (Spark plan)  
Android application id: `com.mcommerce.customer_app`  
Repositories: `unleashed-mcommerce` (Flutter app and canonical rules) and
`unleashed-app-web/apps/admin-dashboard` (React dashboard)

---

## 1. Executive summary

The customer app and administrator dashboard now use a **Spark-only order-request
architecture**. No Cloud Functions, Firebase Storage, Blaze billing, paid Google
services, or managed backups are required by the live flow. Nothing was deployed,
published, or upgraded as part of this work.

The customer submits a **provisional request** with `pending_confirmation` status.
The request records catalogue prices as *requested* values but does not reserve
stock, receive an official order number, or count toward customer totals. Only an
administrator can confirm or reject it. Confirmation re-verifies current prices and
per-size stock, assigns the next `UND-######` order number, deducts stock, writes
inventory logs, replaces requested totals with verified totals, updates customer
totals, and writes a customer notification. Rejection changes no stock and records
a customer-facing reason.

Email verification now uses Firebase's **verification-link** flow
(`sendEmailVerification`, `reload`, token refresh, resend cooldown). The previous
six-digit email OTP flow is inactive; the remaining OTP reference code in
`functions/index.js` is not deployed and is documented as requiring a trusted
backend.

**Final status: implementation and local verification complete; production
transactions are not live.** Deployment, rules publication, and live end-to-end
testing remain blocked on owner approval, credentials/test data, and Java for the
rules emulator.

### Status summary

| Area | Status |
| --- | --- |
| Flutter implementation | Passed |
| Flutter editorial redesign | Passed — design system + all screens restyled, no feature removed |
| Flutter static analysis | Passed — no issues |
| Flutter unit/widget tests | Passed — 67/67 |
| Flutter debug APK build | Passed — 176.5 MB |
| Admin editorial redesign | Passed — token refresh + override layer, class names unchanged |
| Admin TypeScript check | Passed |
| Admin production build | Passed — 794.38 kB JS / 203.07 kB gzip |
| Functions reference syntax | Passed — `node --check` |
| Firestore rules emulator tests | Passed — 46/46 (local emulator, no production connection) |
| Live authenticated end-to-end tests | Not tested — no credentials/test data |
| Rules/dashboard deployment | Blocked — explicit owner approval required |
| Service-account key removal | Removed locally; revocation still owner action |

### Addendum — rules review and offline emulator verification (2026-11-06)

After the initial report, the canonical rules were reviewed against the local
Firestore emulator. Two critical defects were found and fixed **in the local
file only** (nothing was deployed):

1. **Checkout pre-read was denied.** The customer transaction reads the
   deterministic order id before creating it. Reading a missing document was
   denied, which would have failed every checkout. Signed-in reads of
   non-existent orders are now allowed (no content is exposed).
2. **Notifications could not see the new order.** Checkout writes the order and
   its notifications in one transaction; `get()` cannot see staged writes, so
   the notification rules now use `existsAfter()`/`getAfter()`.

A third hardening change makes `isAdmin()` use `token.get('admin', false)` so a
token without the claim cannot raise an evaluation error.

The offline suite now passes **46/46** tests covering public data, profiles,
request creation, the atomic checkout transaction, pending-only cancellation,
cross-user isolation, admin-only confirmation/stock/counter/log writes,
notifications, chat, reviews, addresses, payment records, product images, and
the deny-all catch-all. See `RULES_REVIEW.md` for the access matrix and residual
risks, and `TEST_PLAN.md` for the dedicated-QA-account live plan.

The deployed rules remain unchanged. The service-account key has not been used
or regenerated.

### Addendum — editorial redesign pass (2026-11-07)

Both interfaces were re-skinned with a premium editorial streetwear system while
keeping every Firebase query, model, service, route, collection, and business
rule intact. No mock data, hardcoded metrics, duplicate services, or new runtime
dependencies were introduced.

**Brand tokens**

| Token | Value | Use |
| --- | --- | --- |
| Ink / black | `#0A0303` | Primary surfaces, type, sidebar |
| Off-white | `#EBEBEB` | Canvas |
| Warm gray | `#9B9995` | Secondary text |
| Dark gray | `#242424` | Body copy on light surfaces |
| Burnt orange | `#E32301` | Decisive actions, status accents, focus |
| Radii | `0px` cards/panels, pill chips/steppers | Sharp editorial geometry |

**Flutter**

- `lib/core/app_theme.dart` was rewritten around the tokens above: display/body
  type scale, sharp card and dialog shapes, uppercase 0.1em-tracked labels,
  accent-filled primary buttons, hairline-outlined secondary buttons, quiet
  inputs, and `AppMotion` curves/durations.
- `lib/widgets/editorial.dart` is a reusable layer (`Reveal`, `Eyebrow`,
  `AccentMark`, `EditorialSectionHeader`, `OutlinePill`, `EditorialPanel`,
  `EditorialHeader`, `SkeletonBox`, `ProductGridSkeleton`, `EditorialPageIntro`,
  `Hairline`, `StatusDot`) so screens compose one system instead of one-off
  styling.
- `lib/widgets/common.dart`, `product_card.dart`, `product_image.dart`,
  `quantity_stepper.dart`, and `status_badge.dart` were restyled without changing
  their public constructors or call sites.
- Redesigned screens: Home/Shop (single scrolling editorial storefront with live
  hero, ticker, search, category pills, sort, new-arrivals rail, announcement
  strip, responsive grid), Product Detail, Main Shell, Cart, Checkout, Order
  Success, Payment Simulation, Orders, Order Detail/Tracking, Notifications,
  Chat/Messaging, Profile, Auth scaffold, Login, Register, Forgot Password,
  Verify Email, Complete Profile, Edit Profile, Write Review, Transactions.
- Loading, empty, success, and error states use the same system (skeletons,
  accent-marked empty states, hairline error panels).
- `dart fix --apply` cleared residual `const` lints; `flutter analyze` is clean.

**React admin dashboard**

- `src/styles.css` tokens now mirror the brand palette and set all structural
  radii to `0px`.
- A single appended "UNLEASHED EDITORIAL LAYER" override section restyles the
  shell, sidebar, topbar, page headers, panels, stats, tables, buttons, forms,
  badges/chips, search, empty/error states, image upload, order timeline, modals,
  toasts, notifications, messages, reviews, login/auth, and setup notice while
  preserving every existing class name.
- `src/components/Layout.tsx` brand copy is now `UNLEASHED` / `Admin console`.
- `src/pages/DashboardPage.tsx` adds a `dashboard-hero` block driven only by the
  real clock and the existing load/error state — no fabricated metrics.
- `npm run typecheck` and `npm run build` both pass. The only build output is the
  pre-existing >500 kB chunk warning.

**What the redesign deliberately did not change**

- Firestore reads/writes, transactions, order-request semantics, payment
  semantics, stock handling, notification logic, auth/RBAC, or collection names.
- Firebase project configuration, credentials, rules, or deployed state.
- Category scope (`T-Shirt`, `Cap`, `Hoodie`); caps remain `One Size`, clothing
  keeps its configured size presets.

---

## 2. Final architecture

### 2.1 Customer order request

1. The signed-in, email-verified customer selects cart lines and opens checkout.
2. The app re-reads products and store settings, validates the address, contact
   number, payment method, quantities, and stock, and computes requested totals.
3. A single Firestore transaction writes:
   - `orders/{clientOrderId}` with `status: pending_confirmation`;
   - `requestedItems` with the current catalogue prices;
   - `requestedSubtotal`, `requestedShippingFee`, `requestedTotal`;
   - `items`, `subtotal`, `shippingFee`, `total` mirrors so existing reads work;
   - `totalsVerified: false`, `customerTotalsApplied: false`,
     `paymentStatus: unpaid`;
   - `itemCount`, `requestReference`, `customerNote`, shipping address, and the
     first timeline entry;
   - one deterministic customer acknowledgement;
   - one deterministic administrator alert;
   - deletion of only the selected cart lines.
4. No stock is reserved or deducted. No official order number is assigned.
5. The customer may withdraw the request only while it is
   `pending_confirmation`. Confirmed orders are administrator-only cancellations.

### 2.2 Administrator confirmation

`confirmOrderRequest` runs one Firestore transaction that:

- refuses any request not in `pending_confirmation`;
- reads every referenced product and the `counters/orders` document;
- re-verifies current integer prices and per-size stock, accumulating quantities
  per product so two lines of the same size cannot overdraw stock;
- aborts with no changes if any line is missing, invalid, or short on stock;
- assigns `UND-######` from `counters/orders.lastNumber`;
- deducts stock, writes `inventory_logs` per size, and updates `totalStock`;
- replaces requested line items with the verified items and current prices;
- sets `totalsVerified: true`, `customerTotalsApplied: true`, `status: confirmed`,
  and `paymentStatus: unpaid`;
- increments the customer's `totalOrders` and `totalSpent`;
- writes a deterministic `confirmed` customer notification and an admin activity
  log.

### 2.3 Administrator rejection

`rejectOrderRequest` requires a reason (≤500 characters), sets `status: rejected`,
`rejectionReason`, `rejectedAt`/`rejectedBy`, appends a timeline entry, writes a
deterministic customer notification, and writes an admin activity log. It does not
change stock, counters, payment, or customer totals.

### 2.4 Administrator cancellation and restock

- Only confirmed orders ever deducted stock. Cancellation restores stock, writes
  inventory logs, sets `restockedAt`, and reverses customer totals only when
  `customerTotalsApplied` is true.
- Pending, rejected, and never-confirmed requests cannot restore stock; the code
  rejects such attempts rather than creating inventory.
- The detail page exposes an explicit **Restore stock** action for cancelled orders
  whose stock is still outstanding. Repeated restock attempts are rejected.
- Closed orders (`cancelled`, `rejected`, `refunded`) cannot be reopened.

### 2.5 Email verification

- Registration and sign-in use Firebase Auth email/password.
- New accounts receive a Firebase verification link.
- `AuthGate` shows a verification-pending screen when the optional
  `settings/security.emailVerificationRequired` policy is true and the token's
  `email_verified` claim is false.
- The screen supports **I have verified my email** (`reload` plus token refresh),
  a resend button with a 60-second cooldown, and clear pending/error states.
- Firestore rules optionally enforce verification for order requests when the
  policy document is present and true.
- The six-digit OTP service/screen files were removed from the active Flutter app.
  `functions/index.js` still contains OTP and order callables as **undeployed
  reference code**; they are not called by the app.

### 2.6 Product images

Product images remain browser-compressed bytes in `product_images` Firestore
documents (target ≤320 KB). No Firebase Storage bucket or Storage rules are
required. The unused `firebase_storage` dependency was removed from
`pubspec.yaml` after confirming no `lib/` code depended on it.

---

## 3. Implementation inventory

### 3.1 Flutter app

- `lib/models/order.dart` — request lifecycle, requested-vs-verified totals,
  rejection/cancellation state, timeline synthesis, `canCancel` restricted to
  `pending_confirmation`.
- `lib/services/order_service.dart` — request submission transaction, duplicate
  guard via deterministic client order id, requested totals, selective cart
  clearing, customer/admin notifications, pending-only cancellation.
- `lib/screens/checkout/checkout_screen.dart` and
  `lib/screens/checkout/order_success_screen.dart` — request review, unverified
  total labelling, provisional-request success copy with no official order
  number, and tracking guidance.
- `lib/screens/orders/orders_screen.dart`,
  `lib/screens/orders/order_detail_screen.dart` — pending/rejected/confirmed
  states, requested and verified totals, rejection reason, tracking timeline,
  pending-only cancellation.
- `lib/screens/auth/verify_email_screen.dart`,
  `lib/services/auth_service.dart` — verification-link flow, resend cooldown,
  reload/token refresh, optional policy check.
- `lib/screens/notifications/notifications_screen.dart` — icons for
  `order_requested`, `order_pending_confirmation`, `order_rejected`, and the
  legacy `order_placed` case.
- `lib/core/formatters.dart` — customer-facing labels and notes for the new
  statuses; legacy `placed` remains readable.
- `lib/core/notification_ids.dart` — deterministic request/rejection/status ids.
- `lib/config/app_config.dart` — Spark configuration and inactive OTP constants.

### 3.2 React admin dashboard

- `src/lib/firestore.ts`
  - bounded/paginated order reads (`fetchOrdersPage`, 50 per page, hard caps);
  - `fetchOrders` bounded for dashboards/reports (≤400 rows);
  - `confirmOrderRequest`, `rejectOrderRequest` transactions;
  - guarded `updateOrder` and `restockCancelledOrder`;
  - verified totals, requested-vs-current item mapping, stock protection,
    inventory logs, order counter, customer totals, timeline, notifications, and
    admin activity logs;
  - bounded ancillary reads for products, customers, inventory logs, chats,
    messages, reviews, and announcements.
- `src/pages/OrderDetailPage.tsx` — requested-vs-current price/stock review,
  verified-total preview, confirm/reject modals, rejection reason, cancellation
  warning, restock action, closed-order restrictions, requested/verified totals.
- `src/pages/OrdersPage.tsx` — 50-row pagination, status/payment filters,
  pending/active/recorded-sales metrics, requested-total labelling.
- `src/pages/DashboardPage.tsx` — pending requests, active pipeline, monthly
  income, items sold, requested-vs-verified totals, low stock.
- `src/pages/ReportsPage.tsx` — newest 400 orders, pending/rejected excluded from
  recorded sales, explicit limit notice.
- `src/pages/CustomersPage.tsx` — pending/rejected excluded from order counts and
  spend.
- `src/pages/SettingsPage.tsx` — Spark order-request and verification model.
- `src/lib/customerNotifications.ts`, `src/lib/notifications.ts`,
  `src/lib/useAdminNotifications.ts` — status/rejection copy and capped admin feed.
- `src/types.ts`, `src/components/ui.tsx`, `src/styles.css` — new statuses, badge
  tones, table notes, and price-change styling.

### 3.3 Rules and backend reference

- `unleashed-mcommerce/firestore.rules` — canonical rules for the Spark model.
  Customers may create only their own `pending_confirmation` request, cannot
  write privileged order fields, and may update only a still-pending request into
  `cancelled` with frozen items, totals, payment, and order number. Only an
  `admin == true` claim may write verified totals, stock, counters, inventory
  logs, payment status, or reviewed-order state.
- `functions/index.js` — inactive reference callables/triggers. `node --check`
  passes, but none are deployed and none are required by the live flow.
- Do **not** deploy `unleashed-app-web/firestore.rules`; it is older and weaker
  than the canonical Flutter copy.

### 3.4 Order document fields

| Field group | Fields |
| --- | --- |
| Identity | `customerId`, `customerName`, `customerEmail`, `clientOrderId`, `requestReference`, `source` |
| Request lines | `requestedItems`, `items` (mirror), `itemCount` |
| Requested totals | `requestedSubtotal`, `requestedShippingFee`, `requestedTotal`, `subtotal`, `shippingFee`, `total` |
| Verification | `totalsVerified`, `customerTotalsApplied`, `orderNumber`, `confirmedAt`, `confirmedBy` |
| Payment | `paymentMethod`, `paymentStatus`, `paymentSimulated`, `simulatedPaymentStatus` |
| Delivery | `shippingAddress`, `shippingAddressMap`, `customerNote`, `fulfillmentStatus` |
| Lifecycle | `status`, `timeline`, `createdAt`, `updatedAt`, `cancelledAt`, `cancelledBy`, `cancelReason`, `rejectionReason`, `rejectedAt`, `rejectedBy`, `restockPending`, `restockedAt` |

---

## 4. Trust boundaries and Spark limitations

This architecture is honest about what a Spark project can enforce.

1. **There is no server-authoritative checkout.** The customer's client computes
   the requested total for display and writes it. Firestore rules require internal
   consistency (`requestedTotal = requestedSubtotal + requestedShippingFee`) and
   freeze privileged fields, but they cannot recompute each line from `products`
   or prove that the requested prices match the current catalogue.
2. **The admin dashboard is the trusted operator interface.** Confirmation,
   rejection, stock deduction, restock, order numbering, verified totals, payment
   status, and customer totals are performed by the dashboard's transactions under
   the administrator's `admin == true` custom claim. A compromised administrator
   session or a malicious administrator can bypass the UI safeguards. Spark has no
   Cloud Function or trusted backend to enforce these invariants independently.
3. **The official order number is assigned only on confirmation.** A request is
   identified by its document id and `requestReference` until then.
4. **Stock is not reserved.** Two pending requests can both reference the same
   stock. The first valid confirmation succeeds; later confirmations fail cleanly
   if stock is insufficient, and the administrator can reject them.
5. **Payment stays unpaid.** No payment is captured in the app. Payment status is
   an administrator-managed record, not a payment-gateway result.
6. **Notifications are in-app only.** Both customer and administrator notifications
   are Firestore documents. There is no guaranteed background push while an app is
   closed, and no email/SMS delivery.
7. **Email verification is a link flow.** Optional Firestore enforcement checks the
   ID token's `email_verified` claim. Without Functions or Identity Platform
   blocking functions, per-login enforcement and OTP-style freshness rules are not
   available.
8. **Spark quotas apply.** The project baseline is roughly 50k document reads,
   20k writes, and 20k deletes per day. Admin reads are bounded, but a confirmation
   transaction still touches orders, products, counters, notifications, inventory
   logs, and the customer document. Large orders or repeated restocks consume
   multiple writes.
9. **No managed backups.** Firestore export/backup requires Blaze or external
   tooling; retention and disaster recovery remain an owner responsibility.

---

## 5. Verification results

### 5.1 Executed and passed

From `C:\Users\Andrei San Juan\OneDrive\Documents\unleashed-mcommerce`:

```powershell
flutter analyze
# No issues found! (17.9 s)

flutter test
# All tests passed! 67 tests

node --check functions\index.js
# syntax OK

flutter build apk --debug
# Built build\app\outputs\flutter-apk\app-debug.apk — 176.5 MB

powershell -ExecutionPolicy Bypass -File tools\rules-tests\run.ps1
# Offline Firestore emulator: 46/46 tests passed
```

From `C:\Users\Andrei San Juan\OneDrive\Documents\unleashed-app-web\apps\admin-dashboard`:

```powershell
npm run typecheck
# tsc --noEmit passed

npm run build
# tsc --noEmit && vite build passed
# dist/assets/index-*.js  794.38 kB (203.07 kB gzip)
# dist/assets/index-*.css 57.45 kB (11.17 kB gzip)
# warning: one JS chunk exceeds 500 kB
```

### 5.2 What the 67 Flutter tests cover

- guest cart persistence, malformed stored lines, quantity clamping;
- cart selection defaults, partial/select-all/clear-all, restored selections;
- selective guest cart removal and duplicate-free merge reporting;
- announcement parsing/serialization;
- profile completeness and delivery address validation;
- T-shirt/cap/hoodie catalogue scope;
- deterministic admin/customer notification ids, including request and rejection
  ids and collision separation;
- checkout validation: guest, stale session, inactive account, empty cart,
  unsupported payment method, incomplete address, missing contact number, line
  quantities/identities, idempotency format;
- order timeline parsing, fallback request event, timestamps;
- `canCancel` true only for `pending_confirmation`;
- request model: unverified requested totals, confirmed verified totals, rejection
  reason, closed-state handling, label fallbacks;
- formatters, validators, address/cart/order helpers;
- customer profile `photoUrl` mapping, document round-trip, and `withPhotoUrl`;
- profile photo compression to a 512 px square JPEG data URI and rejection of
  non-JPEG/PNG bytes.

### 5.3 Failed checks

None in the executed suite. The only build output issue is the existing Vite
>500 kB chunk warning; it is not a failure.

### 5.4 Not tested

- Live registration, sign-in, sign-out, password reset, and verification-link
  delivery.
- Live checkout submission, duplicate-submission rejection, selective cart
  clearing, and the customer confirmation acknowledgement.
- Live administrator confirmation/rejection, order numbering, stock deduction,
  inventory logs, verified totals, customer-total updates, cancellation, and
  restock.
- Live notification creation, unread counts, navigation, messaging, reviews, and
  announcements.
- Cross-user isolation with two real accounts.
- Firestore rules behavior against the **deployed** ruleset (the local file is
  emulator-tested).
- Device/emulator UI behavior, offline behavior, memory/CPU/network profiling, and
  load testing.
- Background push notifications (not implemented; in-app only).

### 5.5 Blocked

| Blocker | Consequence |
| --- | --- |
| ~~Java is unavailable~~ | Resolved: Temurin 21 installed locally; emulator suite passes 46/46 |
| No test credentials or seeded test data | Live authenticated end-to-end tests cannot run (see `TEST_PLAN.md`) |
| No deployment approval | Rules, dashboard, and any settings documents remain unpublished |
| Owner has not revoked the exposed Admin SDK key | The key remains a critical security exposure |
| Divergent web rules copy still exists | Risk of deploying the weaker rules by mistake |

No claim is made that any untested flow works in production.

---

## 6. Security findings requiring owner action

### 6.1 Critical — exposed Admin SDK service-account key

The plaintext service-account JSON that was present at:

`C:\Users\Andrei San Juan\OneDrive\Documents\unleashed-app-web\unleashed-clothing-firebase-adminsdk-fbsvc-f694afd9ea.json`

has been **deleted from the project folder**. It was referenced by the local
admin-claim scripts, which will no longer run until a secure credential mechanism
is configured. No key material is reproduced in this report.

Deleting the local file does **not** invalidate the credential. Because the key was
stored in a OneDrive-synced folder, assume it was exposed and rotate it.

Required actions:

1. Disable/delete the key in Google Cloud Console → IAM & Admin → Service Accounts.
2. Review Cloud Audit Logs for unexpected `setCustomUserClaims`, Auth, or Firestore
   admin activity.
3. Remove the key from OneDrive version history/backups and any other copies.
4. Use Application Default Credentials, Workload Identity, or a secret manager for
   any future claim administration.

### 6.2 Critical — duplicate, divergent rules files

- Canonical: `unleashed-mcommerce/firestore.rules`
- Stale/weaker: `unleashed-app-web/firestore.rules`

Deploy only the canonical copy. The web copy lacks the Spark request model and
other hardening. Consider deleting or clearly deprecating it and adding a
`.firebaserc` or documented `--project unleashed-clothing` flag to prevent mistakes.

### 6.3 High — dashboard dependency vulnerabilities

A prior `npm audit --omit=dev` run reported 13 vulnerabilities (0 critical, 5 high,
8 moderate), mostly transitive through `firebase` 10.x and `react-router-dom`
6.30.x. Remediation requires major upgrades followed by dashboard regression
testing. No upgrade was performed.

### 6.4 Medium / operational

- **Rules not emulator-tested** — install Java and add rules unit tests for
  cross-user isolation, request creation, pending-only cancellation, confirmation,
  rejection, restock, notifications, chat, reviews, and announcements.
- **No App Check or rate limiting** — the Spark flow relies on Firebase Auth and
  rules. Enable App Check and monitoring before public launch.
- **API key restrictions unverified** — restrict the Android key to the package and
  signing certificates, and the web key to authorized referrers.
- **Release APK is debug-signed** — configure a real keystore and build an app
  bundle before distribution.
- **No alerting** — monitor permission-denied writes, failed confirmations, and
  quota usage.
- **Announcements query fix is not deployed** — the canonical rules use
  `resource.data.active == true`, but the deployed rules may still reject the
  public `where('active', '==', true)` query.
- **Inactive OTP reference code** — keep `functions/index.js` OTP paths
  undeployed; re-enabling them requires Blaze plus a trusted email backend.
- **Administrator email not verified** — the signed-in admin account reports
  `email verified: no` in Settings. Verify it before relying on the optional
  verification policy.

---

## 7. Performance and Spark quota review

- Admin order list loads 50 rows at a time with a hard page cap; reports read at
  most 400 rows; customers/products/chats/reviews/notifications are bounded.
- Confirmation and restock remain multi-document transactions. They are
  intentionally transactional for integrity and therefore consume several writes
  per action.
- Flutter notifications are capped at 100 and chat messages at 200.
- Product images live in Firestore documents and must stay compressed well below
  the ~1 MiB document limit; they are also counted as document reads.
- Flutter image caching is in-memory only.
- The admin bundle is 794.38 kB minified (203.07 kB gzip); route-level code
  splitting would reduce initial load.
- No runtime profiling, load testing, or memory/CPU trace was performed. Build
  sizes and static review are not substitutes for runtime measurement.

---

## 8. Deployment checklist — not executed

Nothing below was performed. Each item requires explicit owner approval.

### 8.1 Immediate security

1. Revoke the exposed Admin SDK key in Google Cloud IAM (the local JSON has been
   deleted, but the credential itself is still valid until revoked).
2. Choose `unleashed-mcommerce/firestore.rules` as the only deployment source.
3. Restrict Firebase API keys.
4. Review accounts holding the `admin == true` claim.

### 8.2 Firestore rules

```powershell
cd "C:\Users\Andrei San Juan\OneDrive\Documents\unleashed-mcommerce"
firebase deploy --only firestore:rules --project unleashed-clothing
```

Then verify the public announcements query, customer request creation, pending-only
cancellation, and administrator-only writes. Do not deploy the web rules copy.

### 8.3 Optional verification policy

Create `settings/security { emailVerificationRequired: true }` only after
verification-link delivery and the pending-verification screen are confirmed on a
real device. This document is public-readable; never store secrets in it.

### 8.4 Admin dashboard

1. Build `apps/admin-dashboard` with `npm run build`.
2. Deploy the existing `dist` output through the current static hosting provider.
3. Confirm the operator has the `admin` custom claim.
4. Add the hosting domain to Firebase Auth authorized domains.
5. Smoke-test login, product CRUD, inventory, confirmation, rejection,
   cancellation, restock, notifications, messages, reviews, and reports.

### 8.5 Android release

1. Create a real release keystore and `android/key.properties`.
2. Replace the debug signing config.
3. Build an app bundle.
4. Register the release SHA-1/SHA-256 with Firebase and API key restrictions.

---

## 9. Manual QA checklist after deployment

1. Register a new customer; confirm the profile document and verification-link
   screen.
2. Verify the email, use **I have verified my email**, and confirm the app advances
   only after `reload`/token refresh.
3. Test the resend cooldown and the pending/error states.
4. Sign in/out repeatedly; confirm session persistence and profile load.
5. Add products to the cart as a guest, sign in, and confirm a duplicate-free merge.
6. Select cart lines, confirm selected totals, and confirm checkout is blocked when
   nothing is selected.
7. Submit a COD request; confirm `pending_confirmation`, no order number, no stock
   change, no customer total change, the acknowledgement, the admin alert, and
   selective cart clearing.
8. Repeat with simulated GCash/card; confirm no real credentials are requested.
9. Double-submit checkout; confirm the deterministic client id prevents duplicates.
10. As administrator, review requested-vs-current prices and stock.
11. Confirm a request; verify the order number, verified totals, stock deduction,
    inventory logs, customer totals, timeline, and customer notification.
12. Try to confirm the same stock twice; verify the second confirmation fails
    cleanly.
13. Reject a request; verify the reason, timeline, customer notification, and that
    stock is unchanged.
14. Withdraw a pending request as the customer; verify cancellation and that no
    stock or totals change.
15. Cancel a confirmed order as administrator; verify stock restoration, logs, and
    totals reversal exactly once.
16. Confirm a pending/rejected request cannot restore stock.
17. Test tracking status changes from confirmed through delivered and confirm the
    timeline and in-app notifications update.
18. Send chat messages both ways; confirm unread states, navigation, and no
    duplicates.
19. Submit a review only for a delivered product; confirm one review per customer
    and product.
20. With two accounts, confirm customer B cannot read A's cart, orders,
    notifications, chat, transactions, or profile.
21. Create an announcement and verify it appears publicly after the rules fix.
22. Run the admin build, Flutter analyze/tests, a debug APK, and a device smoke test
    after every deployment.

---

## 10. Authorization needed / stop point

The implementation is complete and locally verified. The following require explicit
owner approval or owner action:

1. Revoke the exposed service-account key in Google Cloud IAM and replace the
   admin-claim process with a secure credential mechanism. The local JSON file has
   already been deleted, but deleting a local copy does not invalidate the key.
2. Retire the stale `unleashed-app-web/firestore.rules` copy.
3. Deploy the canonical Firestore rules.
4. Deploy the admin dashboard to the existing static host.
5. Create `settings/security { emailVerificationRequired: true }` after live
   verification testing.
6. Provide test accounts/test data for authenticated end-to-end testing.
7. ~~Install Java and run the rules emulator/unit tests.~~ Resolved: Temurin 21
   installed and the offline suite passes 46/46.
8. Configure release signing and publish the Android app.
9. Upgrade admin dependencies and add App Check, indexes, and monitoring.

Until those are done, the correct status is: **code complete and locally tested,
not deployed, and not proven in live production.**

---

## 11. Per-feature status matrix (redesign pass, 2026-11-07)

Legend: **Fully implemented/tested** — code complete and covered by automated
checks. **Implemented, needs manual verification** — complete and build-clean,
but the live Firebase path needs a real signed-in session/device.
**Not implemented** — out of scope or intentionally left inactive.
**Blocked** — external action required.

### 11.1 Flutter customer app

| Feature | Status | Notes |
| --- | --- | --- |
| Editorial design system (`app_theme.dart`, `editorial.dart`) | Fully implemented/tested | Analyze clean; used across screens |
| Home / Shop storefront (hero, ticker, search, pills, sort, rails) | Fully implemented/tested | Live product streams; 67/67 tests pass |
| Product detail + size/stock selection | Fully implemented/tested | Caps `One Size`, clothing presets |
| Cart (guest + signed-in, selection, quantity) | Fully implemented/tested | Persistence/clamping covered by tests |
| Checkout request submission | Fully implemented/tested | Validation + idempotency covered by tests; live submit needs manual QA |
| Order success / provisional request copy | Fully implemented/tested | No fake order number or payment |
| Payment simulation (GCash/card demo) | Implemented, needs manual verification | UI only; no real payment captured |
| Orders list + tracking timeline | Fully implemented/tested | Pending-only cancel covered |
| Order detail (requested vs verified, rejection) | Fully implemented/tested | Model/formatters covered |
| Notifications (in-app) | Implemented, needs manual verification | Rules emulator-tested; delivery needs session |
| Chat / messaging | Implemented, needs manual verification | Rules emulator-tested; live send needs session |
| Profile + edit profile + addresses | Fully implemented/tested | Validation covered |
| Auth (login, register, reset, verify email, complete profile) | Implemented, needs manual verification | Link flow needs a real mailbox |
| Reviews (write/update) | Implemented, needs manual verification | Delivered-purchase gate rules-tested |
| Transactions ledger | Implemented, needs manual verification | Read-only demo labels; needs session |
| Category scope (`T-Shirt`, `Cap`, `Hoodie`) | Fully implemented/tested | Test updated to required catalog |
| Push notifications | Not implemented | In-app only by design |
| Email/SMS OTP | Not implemented (inactive) | Reference code undeployed |

### 11.2 React admin dashboard

| Feature | Status | Notes |
| --- | --- | --- |
| Editorial layer (`styles.css`, tokens, overrides) | Fully implemented/tested | Typecheck + build pass |
| Shell / sidebar / topbar / auth gate | Fully implemented/tested | Login + authenticated Overview/Products/Orders/Settings inspected read-only; no console errors |
| Dashboard + analytics hero | Implemented, needs manual verification | Live figures + hero rendered in authenticated read-only check; no fabricated metrics |
| Products list + form (Cap `One Size`) | Implemented, needs manual verification | Category/size logic verified in code |
| Inventory + stock adjustments | Implemented, needs manual verification | Needs admin session |
| Orders list/detail, confirm/reject/cancel/restock | Implemented, needs manual verification | Rules emulator-tested; live action needs admin |
| Customers | Implemented, needs manual verification | Needs admin session |
| Messages | Implemented, needs manual verification | Needs admin session |
| Notifications | Implemented, needs manual verification | Needs admin session |
| Reviews | Implemented, needs manual verification | Needs admin session |
| Announcements | Implemented, needs manual verification | Public query rules-tested |
| Reports | Implemented, needs manual verification | Bounded reads; needs admin session |
| Settings | Implemented, needs manual verification | Rendered read-only with admin claim details; no console errors |
| Automated admin unit/e2e tests | Not implemented | No test runner configured in this workspace |
| Deployment to static host | Blocked | Owner approval required |

### 11.3 Platform / security

| Item | Status |
| --- | --- |
| Canonical Firestore rules (local file) | Fully implemented/tested — 46/46 emulator |
| Deployed Firestore rules | Blocked — owner approval; deployed copy may be older |
| Exposed Admin SDK key | Blocked — owner must revoke in Google Cloud IAM |
| Release signing / App Store-ready bundle | Not implemented |
| App Check | Not implemented |
| Dependency upgrades / audit remediation | Not implemented (documented) |
| Live end-to-end QA | Blocked — no QA credentials/test data |

**Bottom line:** every in-scope screen and admin area now uses the editorial
system and preserves the Spark order-request architecture. Automated checks pass.
Anything that requires a real Firebase session, a live mailbox, admin claims, a
device, or deployment remains explicitly unverified rather than assumed working.

---

## 12. OTP login 500 investigation (2026-11-08)

### Root cause

The failing `POST /auth/request-otp` calls ran against a backend process that
started **two minutes before** `otp-backend/.env` was updated. `dotenv` reads the
environment once at startup, so the process kept using the previous Resend API
key. Requests passed password authentication and the Firestore challenge
transaction, then failed at Resend with an unhandled provider error, which the
error middleware reported as `An internal server error occurred.` Because the
failure happened after the rate-limit transaction committed, each failed attempt
also consumed one of the five hourly OTP slots and left no challenge behind.
The account under test is the Resend owner and the key is now valid; a direct
delivery check returned HTTP 200.

### Fixes applied

- `otp-backend/index.js`
  - `HttpError` now carries an `expose` flag; the error middleware only lets
    curated messages through. Unexpected 5xx errors remain generic, and
    5xx logs redact email addresses.
  - Resend failures map to safe, actionable 503 messages (auth/config, testing
    restriction, throttling, network) instead of a generic internal error.
  - A failed email delivery now deletes only its own challenge **and refunds the
    hourly rate-limit slot**, so unreachable email does not lock the customer
    out.
  - Startup logs warn when the test sender `onboarding@resend.dev` is used and
    perform a non-blocking Resend credential check.
  - `app` and the route helpers are exported for tests; `app.listen` only runs
    under `require.main === module`.
- `otp-backend/test/otp.test.js` (new, `npm test`): health, request validation,
  malformed JSON, verify validation, hashing/OTP format, sender parsing, email
  redaction, provider 403/429/network mapping, and curated vs generic errors.
- `lib/services/auth_service.dart`: `_postOtp` now tolerates non-JSON bodies,
  maps empty-body 429/5xx to safe messages, and adds a 20-second timeout with a
  specific timeout message.
- Removed the stale `otp_rate_limits` record left by the failed sends (ephemeral
  `otp_*` state only; no customer, order, or catalog data touched).

### Verification

- Backend: 13/13 tests pass; `/health` returns 200; validation returns
  `400 {"error":"Please provide a valid email and password."}`; startup logs
  show the sender warning and `Resend credential check: ok`.
- Live retry against a non-owner recipient returned the new
  `503 "This email address cannot receive verification codes yet..."` instead of
  the generic 500. Five failed sends left the hourly counters at 0/1 rather than
  5, confirming the rollback; no challenges were left behind. A successful
  verification session exists for the Resend owner account.
- Flutter: `flutter analyze` reports no issues; `flutter test` 62/62 pass.
- Not fully exercised: a real customer login still needs valid credentials and a
  non-owner recipient needs a verified sending domain at resend.com/domains
  (owner action). Nothing was deployed.

**Operational note:** restart the backend after any `.env` change; editing the
file does not affect an already-running process.

---

## 13. Customer profile email verification and photo (2026-11-08)

### 13.1 Storage plan probe — Spark, no bucket

The photo feature was gated on checking whether Firebase Storage was usable on the
current plan. Findings:

```powershell
gcloud billing projects describe unleashed-clothing
# billingEnabled: False

gcloud storage buckets list --project=unleashed-clothing
# (no buckets)

# Direct REST probes for both possible bucket hostnames:
# unleashed-clothing.firebasestorage.app  -> HTTP 404
# unleashed-clothing.appspot.com          -> HTTP 404
```

Firebase Storage requires the Blaze plan. No billing account was enabled, no bucket
was created, no paid service was turned on, and no Storage rules were written or
deployed.

**Chosen implementation:** the customer's photo is compressed to a 512×512 JPEG and
stored as a `data:image/jpeg;base64,...` value in the existing nullable
`users/{uid}.photoUrl` field. The profile model, service boundary, and UI are the
same ones a future Storage migration would use; only the persistence call would
change. This keeps the whole feature inside Spark.

### 13.2 Files changed and added

| File | Change |
| --- | --- |
| `lib/models/user_profile.dart` | Nullable `photoUrl`, `fromDoc` parsing, `toMap` output, `withPhotoUrl(...)` |
| `lib/services/auth_service.dart` | `sendEmailVerification()`, `reloadEmailVerified()`, `updatePhotoUrl()` (photo-only atomic update; `FieldValue.delete()` on removal; size/format guard) |
| `lib/state/app_state.dart` | `sendVerificationEmail()`, `reloadEmailVerified()`, `setProfilePhoto()` (in-memory profile updated only after the write succeeds) |
| `lib/services/profile_photo_service.dart` | **New** — gallery picking, JPG/PNG magic-byte validation, 15 MB source cap, center crop, 512 px resize, iterative JPEG compression, 300 KB stored cap, staged progress |
| `lib/widgets/profile_avatar.dart` | **New** — circular avatar, cached data-URI decode, HTTPS fallback, initials fallback, camera badge, accessible tap target |
| `lib/screens/profile/profile_screen.dart` | Stateful profile header, photo menu (Change / Remove when present / Cancel), preview dialog, removal confirmation, inline progress, readable errors, email-verification card |
| `lib/screens/profile/edit_profile_screen.dart` | Preserves `photoUrl` when the profile is edited |
| `lib/screens/auth/complete_profile_screen.dart` | Preserves `photoUrl` when the profile is completed |
| `test/user_profile_photo_test.dart` | **New** — 5 tests: nullable mapping, document round-trip, `withPhotoUrl`, compression to square JPEG data URI, non-image rejection |
| `pubspec.yaml` | Added `image` and `image_picker` |

No login, registration, checkout, admin-auth, or admin-dashboard code was changed.
The existing OTP customer login remains untouched.

### 13.3 Email verification (Profile page only)

- The Profile page shows the account email plus a `VERIFIED` / `NOT VERIFIED` pill.
- **Send verification email** calls Firebase `sendEmailVerification()` for the
  signed-in user. A 60-second cooldown disables the button and shows a countdown;
  repeated sends are throttled.
- **I have verified — refresh status** calls `user.reload()` and reads the fresh
  `emailVerified` value. If the link has not been clicked yet, the app explains
  that clearly instead of failing silently.
- Confirmation and error messages are plain-language snackbars; Firebase error
  codes are mapped through the existing `readableAuthError` helper.
- Copy states that verification is optional and never blocks checkout. Nothing in
  registration, login, or checkout sends or requires verification.

### 13.4 Profile photo (change, preview, remove, persist)

- Tapping the circular avatar opens a bottom sheet: **Change profile photo**, and
  **Remove profile photo** only when a photo exists, plus **Cancel**.
- The picker accepts gallery JPG/JPEG/PNG only, validated by magic bytes after
  reading (file extensions are not trusted).
- Images are center-cropped square, resized to 512 px, and JPEG-compressed in a
  background isolate until they fit the 300 KB stored cap.
- A preview dialog shows the processed image, its size, and the 512 px target
  before saving.
- Saving writes only `photoUrl` and `updatedAt` on the customer's own document, so
  the rest of the profile cannot be overwritten. Rotation and replacement are
  atomic from the UI's point of view: the in-memory profile changes only after the
  Firestore write succeeds.
- Removal asks for confirmation, deletes the field with `FieldValue.delete()`, and
  restores the initials fallback.
- Missing `photoUrl` is treated as "no photo", so profiles created before this
  change remain valid.

### 13.5 Firestore rules — no change required

The existing `/users/{userId}` rule already allows a self-only update while keeping
role and totals immutable:

```text
allow update: if isAdmin() || (
  isSelf(userId)
  && role unchanged
  && totalOrders unchanged
  && totalSpent unchanged
  ...
)
```

`photoUrl` and `updatedAt` are not in the frozen set, so the customer can manage
their own photo and nobody else's. **No rules were edited and nothing was
deployed.** Reads of `/users/{userId}` remain `isAdmin() || isSelf(userId)`, so the
base64 photo is not publicly readable.

### 13.6 Dependencies

```yaml
dependencies:
  image: ^4.12.0        # decode, crop, resize, JPEG encode
  image_picker: ^1.2.4  # Android Photo Picker / gallery
```

`flutter pub add image image_picker` also brought their platform packages
(`image_picker_android`, `image_picker_ios`, `image_picker_for_web`,
`file_selector_*`, `cross_file`, `mime`, etc.). `firebase_storage` was deliberately
**not** added, because there is no bucket on Spark.

### 13.7 Validation results

| Check | Result |
| --- | --- |
| `flutter pub get` (via `pub add`) | Passed |
| `dart format` on all touched files | Passed |
| `flutter analyze` | **No issues found** |
| `flutter test` | **67/67 passed** (62 existing + 5 new) |
| `flutter build apk --debug --dart-define=OTP_API_BASE_URL=http://10.0.2.2:3000` | Passed |
| Install on `emulator-5554` | Passed |
| Backend tests | 13/13 passed earlier; backend code untouched |

Live device checks (Android emulator, signed-in test customer):

1. Profile shows the email, `NOT VERIFIED`, **Send verification email**, and
   **I have verified — refresh status**. Refresh returned the expected
   “Not verified yet…” message.
2. With no photo, the avatar menu showed only **Change profile photo** and
   **Cancel**.
3. Selected a generated JPEG through the Android Photo Picker. The preview dialog
   reported `JPG or PNG · 11 KB · resized to 512 px`.
4. Confirmed with **Use photo**. Firestore verification (Admin SDK read, metadata
   only) reported `photoUrl` as a string of 15,687 characters beginning
   `data:image/jpeg;base64,`, with `updatedAt` present.
5. The header rendered the photo instead of the initials, and the photo survived a
   force-stop and relaunch.
6. **Remove profile photo** → confirmation → Firestore reported `photoUrl`
   undefined and the `DS` initials returned.
7. The generated test image and its MediaStore entry were deleted; the temporary
   local verification script was removed.

The final APK (rebuilt after the testability refactor) was reinstalled and the
upload/preview/save/remove cycle was repeated. Firestore again reported the
15,687-character `data:image/jpeg;base64,` value, then
`photoUrlPresent=false` after removal, with the initials restored.

No real verification email was sent during automated checks (to avoid an
unrequested mailbox side effect); the send path is exercised by the same Firebase
API and the refresh path was verified live. The test account remains unverified.

### 13.8 Firebase configuration summary

- Project: `unleashed-clothing`; plan: **Spark**; billing: **disabled**.
- No Cloud Storage bucket, no Storage rules, no Blaze upgrade.
- Firestore: `users/{uid}.photoUrl` is optional; no index or schema migration
  needed. Existing documents without the field remain valid.
- Auth: Email/Password provider already enabled; default Firebase verification
  email template is used. No new provider, secret, domain, or template change.
- `google-services.json`, `.firebaserc`, API keys, and service-account files were
  not modified.
- Nothing was deployed (`firebase deploy` was not run).

### 13.9 Manual steps for the owner

1. **Verify an email:** sign in as a customer on Profile → **Send verification
   email** → open the message in the inbox (check spam) → click the link → return
   to Profile → **I have verified — refresh status**. The pill should change to
   `VERIFIED`.
2. **Change a photo:** Profile → avatar → **Change profile photo** → pick a
   JPG/JPEG/PNG → review the 512 px preview → **Use photo** → restart the app and
   confirm it persists.
3. **Remove a photo:** Profile → avatar → **Remove profile photo** → confirm; the
   initials should return and `photoUrl` should be gone after a refresh.
4. **If Storage is added later:** enabling Blaze, creating a bucket, and deploying
   Storage rules are owner decisions. Then replace the data-URI output in
   `ProfilePhotoService` / `AuthService.updatePhotoUrl` with an upload to
   `profile_photos/{uid}/profile.jpg` and store the HTTPS download URL in the same
   `photoUrl` field; the model, avatar, and UI need no changes.

### 13.10 Known limitations

- The photo lives inside the profile document. At the enforced 300 KB binary cap
  (~400 KB base64, plus the 480,000-character guard) it stays well below the 1 MiB
  Firestore document limit, but it is still counted as part of every profile read
  by its owner/admin.
- Because reads are self/admin only, the photo cannot be shown to other customers
  (not needed for this feature).
- The repo has no complete iOS runner (`ios/Runner/Info.plist` is absent), so only
  Android was built and tested. An iOS build would need
  `NSPhotoLibraryUsageDescription` in `Info.plist`.
- Android 13+ uses the system Photo Picker, which grants access only to the chosen
  image; no broad storage permission is requested. Older Android versions rely on
  `image_picker`'s compatibility path.
- A base64 data URI is not a CDN URL; if many customers use large photos, migrate
  to Cloud Storage when billing is acceptable.

