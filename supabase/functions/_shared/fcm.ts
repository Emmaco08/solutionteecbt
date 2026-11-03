// FCM HTTP v1 message building (milestone 4D, D-063). Pure: unit-tested with Node (fcm.test.mjs).

export type PushRow = {
  id: string;
  topic: string;
  title: string;
  body: string;
  link: { type?: string; target?: string } | null;
  audience: "all" | "free" | "premium" | "user" | "staff";
  tokens?: string[] | null;
};

/** FCM topic names the app subscribes to. */
export const topicName = (topic: string) => `t_${topic}`;

/** Who a broadcast reaches: the topic, narrowed to Free or Premium phones when asked. */
export function condition(row: Pick<PushRow, "topic" | "audience">): string {
  const t = `'${topicName(row.topic)}' in topics`;
  if (row.audience === "free") return `${t} && 'tier_free' in topics`;
  if (row.audience === "premium") return `${t} && 'tier_premium' in topics`;
  return t;
}

/** One FCM message: to a token (personal and staff messages) or to the topic condition (broadcasts). */
export function fcmMessage(row: PushRow, token: string | null): Record<string, unknown> {
  const data: Record<string, string> = {
    id: row.id,
    topic: row.topic,
    link_type: String(row.link?.type ?? ""),
    link_target: String(row.link?.target ?? ""),
  };
  return {
    ...(token ? { token } : { condition: condition(row) }),
    notification: { title: row.title, body: row.body },
    data,
    android: {
      priority: "high",
      ttl: row.topic === "streak" ? "14400s" : "172800s",
      notification: { channel_id: "general", tag: row.topic === "streak" ? "streak" : undefined },
    },
  };
}
