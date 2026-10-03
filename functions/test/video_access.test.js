const assert = require("node:assert/strict");
const { test } = require("node:test");
const { hasRevenueCatEntitlement, isEntitlementActive, RevenueCatUnavailableError } = require("../lib/video_access");

const now = Date.parse("2026-10-03T12:00:00Z");
const past = "2026-10-02T12:00:00Z";
const future = "2026-11-03T12:00:00Z";
const entitlementId = "KyrgyzTest Pro";
const config = { apiKey: "dummy-server-key", entitlementId };
function customer(entitlement = {}, subscription = {}) {
  return { subscriber: {
    entitlements: { [entitlementId]: { product_identifier: "monthly", expires_date: future, ...entitlement } },
    subscriptions: { monthly: { is_sandbox: false, ...subscription } },
  } };
}
function response(data, status = 200) {
  return { ok: status >= 200 && status < 300, status, json: async () => data };
}

test("only the exact configured entitlement grants access", () => {
  assert.equal(isEntitlementActive(customer(), "other", { now }), false);
  assert.equal(isEntitlementActive({ subscriber: { entitlements: {} } }, entitlementId, { now }), false);
  assert.equal(isEntitlementActive(customer(), entitlementId, { now }), true);
});

test("an expired or exactly expiring entitlement is denied", () => {
  for (const date of [past, new Date(now).toISOString()]) {
    assert.equal(isEntitlementActive(customer({ expires_date: date }), entitlementId, { now }), false);
  }
});

test("an active store grace period retains access", () => {
  assert.equal(isEntitlementActive(customer({ expires_date: past, grace_period_expires_date: future }), entitlementId, { now }), true);
  assert.equal(isEntitlementActive(customer({ expires_date: past, grace_period_expires_date: past }), entitlementId, { now }), false);
});

test("cancelling renewal does not remove prepaid access", () => {
  assert.equal(isEntitlementActive(customer({}, { unsubscribe_detected_at: past }), entitlementId, { now }), true);
});

test("only explicit null grants lifetime access", () => {
  assert.equal(isEntitlementActive(customer({ expires_date: null }), entitlementId, { now }), true);
  for (const value of [undefined, "invalid", "", 0]) {
    assert.equal(isEntitlementActive(customer({ expires_date: value }), entitlementId, { now }), false);
  }
});

test("sandbox subscriptions are denied for normal users", () => {
  const data = customer({}, { is_sandbox: true });
  assert.equal(isEntitlementActive(data, entitlementId, { now }), false);
  assert.equal(isEntitlementActive(data, entitlementId, { now, allowSandbox: true }), true);
});

test("sandbox lifetime purchases cannot bypass the subscription guard", () => {
  const data = customer({ expires_date: null });
  data.subscriber.subscriptions = {};
  data.subscriber.non_subscriptions = { monthly: [{ is_sandbox: true }] };
  assert.equal(isEntitlementActive(data, entitlementId, { now }), false);
});

test("UIDs are encoded and the HTTP lookup has an abort signal", async () => {
  let requested;
  const active = await hasRevenueCatEntitlement("uid/with spaces", config, {
    now, fetchImpl: async (url, options) => {
      requested = url;
      assert.equal(options.headers.Authorization, "Bearer dummy-server-key");
      assert.ok(options.signal instanceof AbortSignal);
      return response(customer());
    },
  });
  assert.equal(active, true);
  assert.equal(requested, "https://api.revenuecat.com/v1/subscribers/uid%2Fwith%20spaces");
});

test("sandbox allowlist applies only to the authenticated test UID", async () => {
  const testConfig = { ...config, sandboxUserIds: ["test-user"] };
  const fetchImpl = async () => response(customer({}, { is_sandbox: true }));
  assert.equal(await hasRevenueCatEntitlement("test-user", testConfig, { now, fetchImpl }), true);
  assert.equal(await hasRevenueCatEntitlement("normal-user", testConfig, { now, fetchImpl }), false);
});

test("a missing customer is not Premium", async () => {
  assert.equal(await hasRevenueCatEntitlement("user", config, { fetchImpl: async () => response({}, 404) }), false);
});

for (const status of [401, 403, 429, 500]) {
  test(`HTTP ${status} cannot grant Premium`, async () => {
    await assert.rejects(hasRevenueCatEntitlement("user", config, {
      fetchImpl: async () => response({}, status),
    }), RevenueCatUnavailableError);
  });
}

test("timeouts, network failures, and malformed responses fail closed", async () => {
  const fetches = [
    async () => { throw new DOMException("timeout", "TimeoutError"); },
    async () => { throw new Error("network"); },
    async () => ({ ok: true, status: 200, json: async () => { throw new SyntaxError(); } }),
    async () => response({}),
    async () => response({ subscriber: { entitlements: null } }),
  ];
  for (const fetchImpl of fetches) {
    await assert.rejects(hasRevenueCatEntitlement("user", config, { fetchImpl }), RevenueCatUnavailableError);
  }
});
