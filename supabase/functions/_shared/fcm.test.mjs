// Unit tests for fcm.ts. Run: node --test supabase/functions/_shared/fcm.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { condition, fcmMessage, topicName } from "./fcm.ts";

const row = { id: "n1", topic: "announcements", title: "Hello", body: "World", link: { type: "news", target: "abc" }, audience: "all" };

test("broadcasts go to the topic, narrowed by plan when asked", () => {
  assert.equal(topicName("new_questions"), "t_new_questions");
  assert.equal(condition(row), "'t_announcements' in topics");
  assert.equal(condition({ ...row, audience: "free" }), "'t_announcements' in topics && 'tier_free' in topics");
  assert.equal(condition({ ...row, audience: "premium" }), "'t_announcements' in topics && 'tier_premium' in topics");
});

test("a broadcast message has the condition, the text and the link as data", () => {
  const m = fcmMessage(row, null);
  assert.equal(m.condition, "'t_announcements' in topics");
  assert.equal(m.token, undefined);
  assert.deepEqual(m.notification, { title: "Hello", body: "World" });
  assert.deepEqual(m.data, { id: "n1", topic: "announcements", link_type: "news", link_target: "abc" });
  assert.equal(m.android.priority, "high");
});

test("a personal message goes to one token, and data values are always strings", () => {
  const m = fcmMessage({ ...row, audience: "user", topic: "streak", link: null }, "tok-123");
  assert.equal(m.token, "tok-123");
  assert.equal(m.condition, undefined);
  assert.equal(m.data.link_type, "");
  for (const v of Object.values(m.data)) assert.equal(typeof v, "string");
  assert.equal(m.android.ttl, "14400s");
});
