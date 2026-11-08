# Firestore Rules Security Review

**File reviewed:** `unleashed-mcommerce/firestore.rules` (canonical copy, 488 lines)
**Project:** `unleashed-clothing` (Spark)
**Date:** 2026-11-06
**Deployment status:** **NOT DEPLOYED.** The currently deployed rules are unchanged. Nothing in this review was pushed to Firebase.

> This review was performed against the local file and validated with the
> offline Firestore emulator (`demo-unleashed-rules`, `127.0.0.1:8085`). The
> deployed ruleset cannot be read without Firebase Console/CLI access, so a
> line-by-line comparison with production is **not** available yet.

---

## 1. Security model in one paragraph

Every privileged operation is gated on the `admin == true` custom claim. Guests
can read products, product images, active announcements, and the public
`settings/store` + `settings/security` documents. Customers can read and write
only their own profile, addresses, cart, chat, and notifications, can read only
their own orders, and can create **only** a provisional `pending_confirmation`
order whose price/stock/confirmation/payment fields are frozen. Only an
administrator can confirm, reject, cancel confirmed orders, assign order numbers,
move stock, write inventory logs, or change payment state. A final catch-all
denies every collection that is not explicitly matched.

---

## 2. Access matrix (as implemented)

| Collection / path | Guest | Customer | Administrator | Notes |
| --- | --- | --- | --- | --- |
| `users/{uid}` | deny | read/update self; create self | read/update/delete all | Customer cannot change `role`, `totalOrders`, `totalSpent`, `email`, `isActive`, `admin` |
| `users/{uid}/addresses/{id}` | deny | read/write own | read/write all | Owner-scoped |
| `products/{id}` | read | read | read/create/update/delete | Prices/stock admin-only |
| `product_images/{id}` | read | read | read/write | Compressed bytes in Firestore |
| `announcements/{id}` | read if `active == true` | read if `active == true` | full CRUD | Public query `where('active','==',true)` is rule-safe |
| `carts/{uid}/items/{id}` | deny | read/write own | read/write all | Private cart |
| `orders/{id}` | deny | create own pending request; read own; withdraw pending only | read/create/update all; **delete denied for everyone** | Customer cannot set `orderNumber`, verified totals, paid status, rejection, confirmation |
| `transactions/{id}` | deny | read own | CRUD | Payment records are admin-written |
| `notifications/{id}` | deny | read own; limited create; mark read; delete own | CRUD | Customer can only create request/rejection/chat alerts tied to their own order |
| `chats/{uid}` + `messages` | deny | own chat; customer-role messages | read/write/reply | Admin replies use `senderRole: 'admin'` |
| `reviews/{id}` | read | create/update own after a delivered order; delete own | read/delete | ID must be `<productId>_<uid>` |
| `settings/{docId}` | `store` + `security` read | `store` + `security` read | full CRUD | Other settings docs are admin-only |
| `counters/{id}` | deny | deny | read/write | Order number counter |
| `admin_activity_logs/{id}` | deny | deny | read/create; no update/delete | Append-only audit |
| `inventory_logs/{id}` | deny | deny | read/create; no update/delete | Append-only inventory trail |
| anything else | deny | deny | deny | Catch-all `/{document=**}` |

---

## 3. Defects found during emulator verification

These were **not** caught by the earlier static review. Both were fixed in the
local rules file only.

### 3.1 Critical — checkout could never start: pre-read of a new order was denied

`orders` previously allowed reads only through
`isAdmin() || isSelf(resource.data.customerId)`. The Flutter checkout transaction
first reads the deterministic order id to reject duplicate submissions. For a
not-yet-created document, `resource` is `null`, so the read was denied and the
whole transaction failed **before** any write.

**Fix:** allow a signed-in read when the document does not exist:

```rules
allow read: if isAdmin()
  || (isSignedIn() && resource == null)
  || isSelf(resource.data.customerId);
```

**Impact if deployed unchanged:** every customer checkout would fail with
“blocked by the current Firestore rules”, while all unit tests still passed.
This is exactly the class of defect the emulator suite exists to catch.

### 3.2 Critical — checkout notifications could not see the order from the same transaction

Customer checkout writes the order, the customer acknowledgement, and the admin
alert in one transaction. The notification rule used `exists()/get()` on the
order. Firestore `get()` only sees **committed** state, not other writes staged in
the same transaction, so the notification writes were denied and the atomic
checkout rolled back.

**Fix:** added `orderBelongsToCustomerAfterWrite()` using
`existsAfter()`/`getAfter()` and used it for the three customer-created order
notification types.

```rules
function orderBelongsToCustomerAfterWrite(orderId, uid) {
  return existsAfter(/databases/$(database)/documents/orders/$(orderId))
    && getAfter(/databases/$(database)/documents/orders/$(orderId))
         .data.customerId == uid;
}
```

### 3.3 Hardening — missing `admin` claim no longer risks an evaluation error

`isAdmin()` now uses `request.auth.token.get('admin', false)` instead of direct
property access. This prevents a token without the claim from producing a rule
evaluation error (which denies the request) in edge cases. Admin and customer
tests both pass.

---

## 4. Verification

Command:

```powershell
powershell -ExecutionPolicy Bypass -File tools\rules-tests\run.ps1
```

Result (offline emulator, `demo-unleashed-rules`):

| Metric | Result |
| --- | --- |
| Tests | **46** |
| Passed | **46** |
| Failed | **0** |
| Runtime | ~10.5 s |
| Emulator host | `127.0.0.1:8085` only |
| Production connection | none |
| Rules deployed | none |

Coverage includes: public catalogue/announcements, inactive announcement denial,
profile ownership and self-promotion denial, request creation shape and protected
fields, **atomic checkout transaction**, email-verification policy on/off,
pending-only cancellation, reviewed-order immutability, cross-user read
isolation, admin confirmation/stock changes, counter and log protection, settings
visibility, notification creation/read rules, chat sender/role restrictions,
review eligibility, addresses, payment records, product images, and the catch-all.

The suite also proves the missing-document read allowance does **not** let a
signed-in customer issue an unfiltered order listing; only the filtered
`where('customerId', '==', uid)` query succeeds.

---

## 5. Residual risks and limitations

| # | Severity | Finding | Status / mitigation |
| --- | --- | --- | --- |
| 1 | High (by design) | The customer’s requested totals/prices are client-computed. Rules enforce internal consistency but cannot recompute them from `products`. | Admin confirmation re-verifies prices/stock; treat requested totals as unverified until then. Spark has no trusted backend. |
| 2 | High (operational) | Deployed rules are unknown and may be older/weaker. | Do not deploy until approved; after deployment run the probes in §6. Never deploy `unleashed-app-web/firestore.rules`. |
| 3 | Medium | No rate limiting or App Check. A customer can create many pending requests and admin notifications. | Bounded by per-request validation; enable App Check and monitor quotas. Spark cannot enforce per-user rate limits without Functions. |
| 4 | Medium | Customer-controlled `timeline`, `cancelReason`, `restockPending`, `fulfillmentStatus` during withdrawal. | Display-only spoofing. Admin restock requires `totalsVerified`/`customerTotalsApplied`, so it cannot create stock. |
| 5 | Medium | Reviews are not checked against the products inside the delivered order. | A customer can review any product after any delivered order. Acceptable for now; documented gap. |
| 6 | Medium | Customer-supplied admin notification `title`/`body` (length-capped) can contain misleading text in the admin feed. | Admin UI should treat as untrusted content; no links/HTML rendering. |
| 7 | Medium | `settings/security` and `settings/store` are public-readable. | Never store secrets there. Only the verification policy/contact data belong in these docs. |
| 8 | Medium | `requestedItems` maps are not schema-validated (price/quantity/productId), only list size. | Admin confirmation recomputes from real products; request totals remain unverified. |
| 9 | Low | Any signed-in user can probe whether an order id exists (missing-doc read). | No document content is exposed; ids are client-generated and unguessable. Needed for duplicate detection. |
| 10 | Low | Admin writes are trusted; rules do not prevent negative stock if the dashboard is bypassed. | Dashboard clamps/validates; admin claim compromise is out of the Spark trust model. |
| 11 | Low | Customer `customerNote`/`cancelReason` length is not bounded by rules (document limit only). | Add length checks if abuse appears. |
| 12 | Low | Logs cannot be edited/deleted by administrators. | Intentional append-only audit; cleanup requires Console/Admin SDK. |
| 13 | Informational | Rules use `get()/getAfter()`; the per-transaction document-access limit is 20. | The current checkout/cancel flows pass; adding more cross-document checks could hit the limit. |

---

## 6. Post-deployment verification probes (NOT executed)

Only after explicit approval and only with `unleashed-mcommerce/firestore.rules`:

1. Guest home screen shows active announcements; deactivating one removes it.
2. Customer places an order; confirm `pending_confirmation`, no stock change, no
   order number, and both notifications exist.
3. Customer withdraws the pending order; confirm cancellation and the admin alert.
4. Admin confirms a second request; verify stock deduction, order number,
   verified totals, inventory log, customer totals, and notification.
5. Customer B cannot read customer A’s order, cart, notifications, or chat.
6. Customer cannot write products, counters, inventory logs, or admin logs.
7. Confirm an order twice / out of stock; the second confirmation fails cleanly
   and stock never goes negative.
8. Deploy nothing else from this review.

---

## 7. Deployment prerequisites

- Owner approval for `firebase deploy --only firestore:rules`.
- Confirm the deployed ruleset is the canonical file (compare via Console).
- Do **not** deploy `unleashed-app-web/firestore.rules`.
- Keep `settings/security.emailVerificationRequired` absent or false until live
  verification-link testing passes.
- Re-run the emulator suite after any rules edit.
