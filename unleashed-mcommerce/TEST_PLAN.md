# Live Test Plan — Dedicated QA Accounts Only

**Status:** DRAFT — no test accounts created, no production data read or modified,
nothing deployed.
**Waiting on:** owner approval + dedicated QA credentials (see §3).
**Applies to:** Flutter customer app (`unleashed-mcommerce`) and admin dashboard
(`unleashed-app-web/apps/admin-dashboard`), project `unleashed-clothing` (Spark).

---

## 1. Non-negotiable safety rules

1. Use only the dedicated QA accounts listed in §3. Never sign in as a real
   customer or with the owner’s production admin account.
2. Never edit, cancel, refund, restock, or delete a real order, product, or
   customer. QA writes are limited to the tagged QA data in §4.
3. Perform all destructive or state-mutating scenarios on the **local emulator**
   first. Live-project mutations require a separate written approval.
4. Do not deploy rules, hosting, Functions, or indexes as part of testing.
5. Do not create Firebase Auth users, change custom claims, or seed production
   documents on the owner’s behalf. The owner (or an approved operator) creates
   the accounts and assigns claims.
6. Do not use or regenerate the exposed service-account key. Any claim change
   must use Application Default Credentials (`gcloud auth application-default
   login`) or the Firebase Console under the owner’s supervision.
7. Do not record or paste passwords, tokens, keys, or full customer documents in
   reports. Redact emails (keep domain/label only) and any address details.
8. Stop immediately if a test touches a non-QA document; report it instead of
   trying to “fix” it in production.

---

## 2. Test environments

| Tier | Environment | Purpose | Allowed changes |
| --- | --- | --- | --- |
| 1 | **Local emulator** (`demo-unleashed-rules`, port 8085) | Rules, request/confirmation, stock, notifications, isolation | Disposable; no production connection |
| 2 | **Local apps** (Vite `localhost:5173`, Flutter debug on emulator/device) | UI, validation, loading/empty/error states | Local only |
| 3 | **Live project, read-only** | Confirm deployed data/config renders correctly | No writes |
| 4 | **Live project, tagged QA writes** | End-to-end Auth/email/order flow | Only QA data, only with approval |

Tier 1 already exists (`tools/rules-tests`, 45/45 passing). Tier 4 is the only
tier that can validate actual email delivery, custom claims, and real Firebase
Auth behavior.

---

## 3. Required accounts (owner to create/approve)

| Role | Proposed account | Requirements | Used for |
| --- | --- | --- | --- |
| QA admin | `qa.admin@<owner-test-domain>` | Email verified; custom claim `admin: true`; profile document; **not** the production admin | Dashboard login, confirm/reject/cancel/restock, announcements, settings |
| QA customer 1 | `qa.customer1@<owner-test-domain>` | Email verified; `users/{uid}` with `role: customer`; real mailbox for the verification link | Checkout, orders, cancellation, notifications, chat, reviews |
| QA customer 2 | `qa.customer2@<owner-test-domain>` | Same as customer 1 | Cross-user isolation tests |
| Guest | No account | — | Public catalogue/announcements/cart persistence |

Optional: a second admin account to verify that one admin cannot silently grant
privileges through Settings (claims are server-assigned only).

**Do not** reuse the owner’s email, the production admin uid, or any real
customer email. Aliases/plus-addressing are acceptable only if the owner
explicitly authorizes them and can receive the verification/reset mail.

---

## 4. QA data set (owner to approve creation)

Create only if Tier 4 approval is given, and tag everything:

- Product: name begins with `QA TEST —`; status `active`; price e.g. ₱1.00–₱5.00
  so screenshots are obvious; sizes S/M/L/XL with stock `S=0, M=5, L=12, XL=0`
  for size tests.
- Second product with all sizes `0` to test the overall out-of-stock state.
- Announcement: title begins `QA TEST —`; `active: true`; one inactive twin.
- Store settings: leave production values alone; test shipping copy in the
  emulator or coordinate a temporary value with the owner.
- Orders: created only by QA customers; note the document ids and customer ids in
  the test log.
- Reviews/chat/messages: only on QA orders/products.

**Cleanup:** emulator data is disposable. Live QA data may be removed only via
Firebase Console/Admin SDK with explicit approval, after the evidence is
captured. Rules intentionally prevent hard-deleting orders.

---

## 5. Test matrix

Classification for every row: `PASSED`, `FAILED`, `NOT TESTED`, `BLOCKED`.
Rows are not “passed” until executed and evidenced.

### 5.1 Customer app — authentication and profile (Tier 4)

| ID | Test | Steps | Expected |
| --- | --- | --- | --- |
| CA-01 | Registration | Register QA customer 1 | Auth user + `users/{uid}` with `role: customer`, totals 0 |
| CA-02 | Verification link | Open the email link on another device/browser | Firebase marks `email_verified`; app does not advance until reload/token refresh |
| CA-03 | Resend cooldown | Tap resend twice | Second tap blocked for 60 s; clear message |
| CA-04 | Sign-in persistence | Close/reopen app | Session restored; profile loads |
| CA-05 | Password reset | Request reset; set a new password | Reset mail arrives; new password works; old fails |
| CA-06 | Sign-out | Sign out | Guest home; cart/orders inaccessible |
| CA-07 | Profile edit | Change name/phone | Saved; protected fields unchanged |
| CA-08 | Guest gate | Try checkout while signed out | Redirected to sign-in; no order created |

### 5.2 Customer app — cart and place order

| ID | Test | Steps | Expected |
| --- | --- | --- | --- |
| CC-01 | Guest cart | Add items as guest; reopen app | Cart persists |
| CC-02 | Guest merge | Sign in with a non-empty guest cart | Duplicate-free merge; quantities clamped |
| CC-03 | Selection | Deselect one line | Totals use selected lines only |
| CC-04 | Select/clear all | Toggle select-all | All selected, then none; checkout blocked when none |
| CC-05 | Partial checkout | Select subset and place order | Only selected lines submitted and removed; unselected remain |
| CC-06 | Place Order UI | Review screen | Copy says “Place Order”, unverified total labelled, no fake order number |
| CC-07 | Request created | Place COD order | `pending_confirmation`, `unpaid`, `totalsVerified: false`, `customerTotalsApplied: false`, no `orderNumber`, no stock change |
| CC-08 | Duplicate guard | Double-tap Place Order / retry network | One order document; second attempt shows duplicate message |
| CC-09 | Request notifications | After submission | Customer acknowledgement + admin alert with deterministic ids |
| CC-10 | Stock unchanged | Check product before/after submission | Identical stock and totalStock |
| CC-11 | Order history | Open My Orders | Request listed with pending status and requested total |
| CC-12 | Order detail | Open request | Timeline, shipping, requested items, tracking note |
| CC-13 | Withdraw pending | Cancel own pending request | Status `cancelled`; no stock/total change; admin alert |
| CC-14 | Cannot withdraw confirmed | Try cancel after admin confirmation | Blocked with guidance to contact the store |
| CC-15 | Rejected visibility | Admin rejects | Status/reason/timeline/notification visible |
| CC-16 | GCash/Card simulation | Place simulated payment order | No real credentials requested; unpaid remains |

### 5.3 Size-specific stock

| ID | Test | Setup | Expected |
| --- | --- | --- | --- |
| ST-01 | Zero size | S = 0 | S shows Out of Stock; disabled; M/L still purchasable |
| ST-02 | Low stock | M = 5 | Low Stock label; purchase allowed |
| ST-03 | In stock | L = 12 | In Stock label |
| ST-04 | All sizes zero | All = 0 | Product overall Out of Stock; purchase disabled |
| ST-05 | Restock size | Admin sets S = 3 | S becomes purchasable without app restart |
| ST-06 | Cart line for now-zero size | Add M, then admin sets M = 0 | Checkout blocked/line flagged; no order for unavailable size |
| ST-07 | Last item pending | M = 1, place request | Stock stays 1 while pending |
| ST-08 | Last item confirmation | Admin confirms | Stock becomes 0; M automatically Out of Stock |

### 5.4 Admin orders and inventory

| ID | Test | Steps | Expected |
| --- | --- | --- | --- |
| AO-01 | Dashboard login | QA admin signs in | Admin UI loads; claim recognized |
| AO-02 | Non-admin denial | QA customer opens dashboard | Access denied; no data |
| AO-03 | Request queue | Open Orders | Pending request visible, paginated/filterable |
| AO-04 | Price/stock review | Open request detail | Requested vs current price and per-size stock shown |
| AO-05 | Confirm | Confirm request | `UND-######`, verified totals, stock deducted per size, inventory log, customer totals updated, timeline + notification |
| AO-06 | Duplicate confirmation | Confirm same request again | Clean rejection; no second deduction |
| AO-07 | Insufficient stock | Two requests for the last item; confirm both | First succeeds; second fails/flagged; stock never negative |
| AO-08 | Reject | Reject with reason | `rejected`, reason stored, no stock/counter/totals change, customer notified |
| AO-09 | Cancel confirmed | Cancel a confirmed order | Stock restored once; logs written; customer totals reversed |
| AO-10 | Restock action | Use Restore stock on the cancelled order | Once only; second attempt rejected |
| AO-11 | Pending/rejected restock | Attempt restock | Rejected — no stock created |
| AO-12 | Track status | Move confirmed → shipped → delivered | Timeline and notifications update |
| AO-13 | Reports/dashboard | Compare metrics | Pending/rejected excluded from recorded sales; labels state requested vs verified |

### 5.5 Announcements

| ID | Test | Steps | Expected |
| --- | --- | --- | --- |
| AN-01 | Create/publish | Admin creates active QA announcement | Appears on customer home as guest and signed-in |
| AN-02 | Edit | Change body | App updates via listener/refresh |
| AN-03 | Deactivate | Set inactive | Disappears from customer app |
| AN-04 | Delete | Delete QA announcement | Removed |
| AN-05 | Permissions | Customer attempts write | Denied |

### 5.6 Notifications, messaging, reviews

| ID | Test | Expected |
| --- | --- | --- |
| NM-01 | Request notification icons | `order_requested`, `new_order_request`, `order_pending_confirmation`, `order_rejected` render |
| NM-02 | Unread counts | Mark read updates badge without duplicates |
| NM-03 | Customer → admin chat | Message appears in dashboard; unread state correct |
| NM-04 | Admin reply | Customer sees reply; sender role correct |
| NM-05 | Review gate | Review allowed only after delivered order; one per product/customer |
| NM-06 | Cross-user messages | Customer B cannot see A’s chat/notifications |

### 5.7 Security and isolation (Tier 1 + Tier 4)

| ID | Test | Expected |
| --- | --- | --- |
| SE-01 | Own-data access | QA customer 1 reads own profile, cart, order, notifications |
| SE-02 | Cross-user reads | QA customer 1 cannot read QA customer 2’s profile, cart, order, notifications, chat, transactions |
| SE-03 | Protected order fields | Customer cannot set order number, verified totals, paid status, confirmation/rejection |
| SE-04 | Confirmation ownership | Customer cannot confirm/cancel a reviewed order |
| SE-05 | Inventory protection | Customer cannot write products, counters, inventory logs, admin logs |
| SE-06 | Admin-only reads | Announcement drafts, counters, logs denied to customers |
| SE-07 | Role escalation | Customer cannot change `role`, `totalSpent`, `isActive`, or custom claims |
| SE-08 | Review ownership | Customer cannot review another customer’s delivered order |
| SE-09 | Guest boundaries | Guest can read active public data only |
| SE-10 | Existing rules | Deployed rules unchanged until owner approval |

Tier 1 already covers SE-01…SE-09 in the emulator suite.

### 5.8 Admin Settings

| ID | Test | Expected |
| --- | --- | --- |
| AS-01 | Profile edit | Display/first/last name saved; Auth display name updated |
| AS-02 | Password change | Reauthenticate, validate, update via Firebase Auth; new password works |
| AS-03 | Password mismatch | Client-side validation blocks |
| AS-04 | Email change | Reauthenticate, Firebase email-change, verification handling |
| AS-05 | Password reset | Reset mail delivered |
| AS-06 | Verification status | Accurate status shown |
| AS-07 | Store info | Store name/contact/address/shipping saved; customer app reads same document |
| AS-08 | Privilege self-grant | No UI/API path to grant admin; claims unchanged |
| AS-09 | Sign out | Returns to login; no lingering privileged state |
| AS-10 | No secrets | No service-account/key material shown or stored |

### 5.9 Build quality (can run now)

| ID | Command | Last result |
| --- | --- | --- |
| BQ-01 | `flutter analyze` | PASSED |
| BQ-02 | `flutter test` | PASSED — 62/62 |
| BQ-03 | `flutter build apk --debug` | PASSED |
| BQ-04 | Admin `npm run typecheck` | PASSED |
| BQ-05 | Admin `npm run build` | PASSED |
| BQ-06 | Rules emulator suite | PASSED — 46/46 |
| BQ-07 | `node --check functions/index.js` | PASSED |

---

## 6. Execution order

1. **Tier 1 (no approval needed):** emulator rules suite; local apps for UI
   validation with emulator-backed data where feasible.
2. **Tier 2:** local dashboard at `http://localhost:5173`; Flutter debug build.
3. **Tier 3 (needs read access):** sign in as QA accounts and confirm existing
   data renders; no writes.
4. **Tier 4 (needs explicit approval + credentials):** registration, verification
   email, full place-order → confirm/reject → cancel/restock → notify flow using
   only QA data.

Do not run Tier 4 mutations and Tier 3 checks in the same session without
recording the baseline (order counts, stock, counter value, customer totals).

---

## 7. Evidence and reporting

For each executed row record:

- ID, environment tier, timestamp, account label (not password).
- Expected vs actual.
- Screenshot or short screen recording (redact personal data).
- Firestore document excerpt (redacted) for state transitions.
- Console/network error text if any.
- Classification: PASSED / FAILED / NOT TESTED / BLOCKED.
- For failures: reproduction steps and whether it is a rules, client, or data
  issue.

A test is not PASSED if it was only reviewed in code or inferred from a build.
No test may claim server-authoritative pricing, payment, or stock reservation.

---

## 8. Cleanup and rollback

- Emulator: stop the emulator; data is discarded.
- Local apps: stop the dev server/process; no production effect.
- Live QA data: leave it tagged (`QA TEST —`) until the report is accepted, then
  remove only with owner approval via Console/Admin SDK. Orders are intentionally
  not hard-deletable by the apps.
- If a real document is touched: stop, capture the before/after, report it, and
  let the owner restore it. Do not attempt further writes.

---

## 9. Dependencies and blockers

| Item | Status |
| --- | --- |
| Java for emulator | DONE — Temurin 21 at `%LOCALAPPDATA%\Java\jdk-21.0.13+9` |
| Rules emulator suite | DONE — 46/46 |
| QA admin account + `admin` claim | WAITING on owner |
| QA customer mailboxes (verification links) | WAITING on owner |
| Approval for live QA writes | WAITING on owner |
| Revocation of exposed service-account key | WAITING on owner (Google Cloud IAM) |
| Rules deployment | NOT REQUESTED — must not happen during testing |
| Payment gateway | OUT OF SCOPE — simulated only |

---

## 10. Local commands

```powershell
# Rules emulator tests (offline; no production connection)
cd "C:\Users\Andrei San Juan\OneDrive\Documents\unleashed-mcommerce"
powershell -ExecutionPolicy Bypass -File tools\rules-tests\run.ps1

# Admin dashboard (already running locally)
cd "C:\Users\Andrei San Juan\OneDrive\Documents\unleashed-app-web\apps\admin-dashboard"
npm run dev        # http://localhost:5173

# Flutter app
cd "C:\Users\Andrei San Juan\OneDrive\Documents\unleashed-mcommerce"
flutter run
```
