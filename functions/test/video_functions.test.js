const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const { test } = require("node:test");
const vm = require("node:vm");
const { RevenueCatUnavailableError } = require("../lib/video_access");

// Exercise the actual callable handlers without Firebase credentials or S3.
function handlers({ premium = true, unavailable = false, active = true } = {}) {
  const calls = { premium: [], firestore: 0, signed: [] };
  class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  const data = { isActive: active, videoObjectKey: "A1/personal/greeting/001.mp4" };
  const config = {
    minio: { endPoint: "media.kyrgyztest.kg", accessKey: "dummy", secretKey: "dummy", bucket: "videos" },
    revenueCat: { apiKey: "dummy", entitlementId: "KyrgyzTest Pro" },
  };
  const modules = {
    "firebase-functions/v2": { setGlobalOptions() {} },
    "firebase-functions/v2/https": { HttpsError, onCall: (_, callback) => callback },
    "firebase-functions/params": { defineJsonSecret: () => ({ value: () => config }) },
    "firebase-functions/logger": { info() {}, warn() {}, error() {} },
    "firebase-admin/app": { initializeApp() {} },
    "firebase-admin/firestore": { getFirestore: () => ({ collection(name) {
      calls.firestore++;
      assert.equal(name, "videos", "no client Premium flag is queried");
      return { doc: () => ({ get: async () => ({ exists: true, data: () => data }) }) };
    } }) },
    "@aws-sdk/client-s3": {
      S3Client: class {}, GetObjectCommand: class { constructor(input) { this.input = input; } },
    },
    "@aws-sdk/s3-request-presigner": { getSignedUrl: async (_, command, options) => {
      calls.signed.push({ input: command.input, options });
      return "https://media.kyrgyztest.kg/videos/A1/personal/greeting/001.mp4?signature=dummy";
    } },
    "./lib/video_access": { RevenueCatUnavailableError, hasRevenueCatEntitlement: async (uid) => {
      calls.premium.push(uid);
      if (unavailable) throw new RevenueCatUnavailableError(503);
      return premium;
    } },
  };
  const context = { exports: {}, require: (name) => {
    assert.ok(modules[name], `unexpected module ${name}`);
    return modules[name];
  } };
  vm.runInNewContext(readFileSync(join(__dirname, "../index.js"), "utf8"), context);
  return { ...context.exports, calls };
}

test("anonymous playback never checks billing, reads metadata, or signs a URL", async () => {
  const app = handlers();
  await assert.rejects(app.getVideoPlaybackUrl({ data: { videoId: "lesson-1" } }), { code: "unauthenticated" });
  assert.equal(app.calls.premium.length, 0);
  assert.equal(app.calls.firestore, 0);
  assert.equal(app.calls.signed.length, 0);
});

test("a forged client Premium flag and UID never grant playback", async () => {
  const app = handlers({ premium: false });
  await assert.rejects(app.getVideoPlaybackUrl({ auth: { uid: "actual-user" },
    data: { videoId: "lesson-1", uid: "paid-user", isPremium: true, videoObjectKey: "another.mp4" },
  }), { code: "permission-denied" });
  assert.deepEqual(app.calls.premium, ["actual-user"]);
  assert.equal(app.calls.firestore, 0);
  assert.equal(app.calls.signed.length, 0);
});

test("RevenueCat outages never fall back to signing a playback URL", async () => {
  const app = handlers({ unavailable: true });
  await assert.rejects(app.getVideoPlaybackUrl({ auth: { uid: "user" }, data: { videoId: "lesson-1" } }), { code: "unavailable" });
  assert.equal(app.calls.firestore, 0);
  assert.equal(app.calls.signed.length, 0);
});

test("inactive lessons are unavailable even to a paid user", async () => {
  const app = handlers({ active: false });
  await assert.rejects(app.getVideoPlaybackUrl({ auth: { uid: "user" }, data: { videoId: "lesson-1" } }), { code: "not-found" });
  assert.equal(app.calls.signed.length, 0);
});

test("playback uses the authenticated UID and server metadata with a 15 minute TTL", async () => {
  const app = handlers();
  const result = await app.getVideoPlaybackUrl({ auth: { uid: "paid-user" },
    data: { videoId: "lesson-1", videoObjectKey: "forged.mp4" },
  });
  assert.equal(result.expiresIn, 900);
  assert.deepEqual(app.calls.premium, ["paid-user"]);
  assert.equal(app.calls.signed[0].input.Key, "A1/personal/greeting/001.mp4");
  assert.equal(app.calls.signed[0].input.Bucket, "videos");
  assert.equal(app.calls.signed[0].options.expiresIn, 900);
});

test("non-Premium users cannot receive even thumbnail URLs", async () => {
  const app = handlers({ premium: false });
  await assert.rejects(app.getVideoLessons({ auth: { uid: "user" },
    data: { level: "A1", sphere: "personal" },
  }), { code: "permission-denied" });
  assert.equal(app.calls.firestore, 0);
  assert.equal(app.calls.signed.length, 0);
});

test("AI writing rejects a forged Premium flag before reading topics or charging usage", async () => {
  const app = handlers({ premium: false });
  await assert.rejects(app.checkEssay({ auth: { uid: "actual-user" }, data: {
    essay: "A test essay", levelId: "level_b2", taskId: "task-1",
    uid: "paid-user", isPremium: true,
  } }), { code: "permission-denied", message: "PREMIUM_REQUIRED" });
  assert.deepEqual(app.calls.premium, ["actual-user"]);
  assert.equal(app.calls.firestore, 0);
});

test("AI writing fails closed when RevenueCat cannot verify a subscription", async () => {
  const app = handlers({ unavailable: true });
  await assert.rejects(app.checkEssay({ auth: { uid: "user" }, data: {
    essay: "A test essay", levelId: "level_c1", taskId: "task-1",
  } }), { code: "unavailable" });
  assert.equal(app.calls.firestore, 0);
});
