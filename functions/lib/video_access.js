const REVENUECAT_TIMEOUT_MS = 8000;

class RevenueCatUnavailableError extends Error {
  constructor(status) {
    super("Premium status is unavailable");
    this.name = "RevenueCatUnavailableError";
    this.status = status;
  }
}

function isFutureDate(value, now) {
  return typeof value === "string" && Date.parse(value) > now;
}

function isEntitlementActive(customer, entitlementId, {
  now = Date.now(), allowSandbox = false,
} = {}) {
  const subscriber = customer?.subscriber;
  const entitlement = subscriber?.entitlements?.[entitlementId];
  if (!entitlement || typeof entitlement !== "object") return false;

  // Sandbox access is allowed only for the server-configured test Firebase UIDs.
  const product = entitlement.product_identifier;
  const subscription = subscriber.subscriptions?.[product];
  const purchases = subscriber.non_subscriptions?.[product];
  if (!allowSandbox && (subscription?.is_sandbox === true ||
      (Array.isArray(purchases) && purchases.length > 0 &&
       purchases.every((purchase) => purchase.is_sandbox === true)))) {
    return false;
  }

  // Only an explicit null means a lifetime entitlement. An omitted or invalid
  // expiration never grants access. Cancellation retains access until expiry.
  return entitlement.expires_date === null ||
    isFutureDate(entitlement.expires_date, now) ||
    isFutureDate(entitlement.grace_period_expires_date, now);
}

async function hasRevenueCatEntitlement(uid, config, {
  fetchImpl = fetch, now = Date.now(),
} = {}) {
  try {
    const response = await fetchImpl(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      {
        headers: { Authorization: `Bearer ${config.apiKey}`, Accept: "application/json" },
        signal: AbortSignal.timeout(REVENUECAT_TIMEOUT_MS),
      }
    );
    if (response.status === 404) return false;
    if (!response.ok) throw new RevenueCatUnavailableError(response.status);
    const customer = await response.json();
    if (!customer?.subscriber || typeof customer.subscriber.entitlements !== "object" ||
        customer.subscriber.entitlements === null) {
      throw new RevenueCatUnavailableError();
    }
    return isEntitlementActive(customer, config.entitlementId, {
      now,
      allowSandbox: Array.isArray(config.sandboxUserIds) && config.sandboxUserIds.includes(uid),
    });
  } catch (error) {
    if (error instanceof RevenueCatUnavailableError) throw error;
    // Avoid logging credentials, signed URLs, or customer payloads.
    throw new RevenueCatUnavailableError();
  }
}

module.exports = { hasRevenueCatEntitlement, isEntitlementActive, RevenueCatUnavailableError };
