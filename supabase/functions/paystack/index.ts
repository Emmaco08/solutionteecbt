// Paystack payments for the direct APK and the website (milestone 4C, docs/plans/phase-4c.md, D-061).
// POST /functions/v1/paystack   Authorization: Bearer <access token>
//   {action:"start", plan, code?, source?: "app"|"web", method?, bank?}
//      → {free:true, expires_at} when a 100% code covers it, else the payment to open (below)
//   {action:"start_xp", xp, source?: "app"|"web", method?, bank?}   an XP pack (D-084); the price comes from xp_pack_start()
//   method (D-089): "card" (default) → {reference, url, access_code, public_key?, amount_kobo}: the app opens Paystack's own
//                   payment sheet inside the app with access_code (public_key is PAYSTACK_PUBLIC_KEY), or `url` in an in-app tab;
//                   "transfer" → {reference, amount_kobo, transfer:{account_number, account_name, bank, expires_at}} (Charge API);
//                   "ussd" + bank ("737"|"919"|"822"|"966") → {reference, amount_kobo, ussd:{code, bank}} (Charge API);
//                   "bank" + bank_code + account_number → {reference, amount_kobo, bank_charge:{status, text, url}} (Pay with Bank:
//                   any bank or app such as OPay, PocketApp, Zap; the next step is an OTP, birthday, phone, a bank page or approval in the app);
//                   "page" → like card, but Paystack's own screen shows every method Paystack offers (the backup).
//   {action:"pay_banks"} → {banks:[{name, code}]}   banks and apps that support Pay with Bank (D-092)
//   {action:"charge_submit", reference, step:"otp"|"birthday"|"phone", value} → {bank_charge:{…}}   the next Pay with Bank step
//      Each start makes a new reference; the webhook + verify grant it, exactly like a checkout payment.
//   {action:"check", reference}
//      → {status: "pending"|"success"|"failed"|"needs_review"|"refunded", expires_at?}
//   {action:"banks"} → {banks:[{name, code}]}   Nigerian banks for prize payouts (D-090)
//   {action:"resolve", account_number, bank_code} → {account_name}   checks an account before a winner sends it
//   {action:"payout_check", claim_id}   admins with 2-step: asks Paystack whose account it is → {verified_name}
//   {action:"payout_send", claim_id}    admins with 2-step: sends the prize by Paystack Transfer (needs transfer OTP off)
//   {action:"payout_verify", claim_id}  admins with 2-step: asks Paystack again how the transfer went
//   (payout_check / payout_send need the paystack_payouts flag on; GET ?health=1 says whether the keys are set, never the keys)
//   {action:"refund", reference}   admins with 2-step only
//      → {requested:true}; Premium is removed when Paystack's refund.processed webhook arrives.
// The app never sends an amount: the price comes from pay_start() on the server.
import { admin, asUser, cors, json, paystack, rpc, userFrom } from "../_shared/pay.ts";
import { trimPaystack } from "../_shared/paycrypto.ts";

const ERR: Record<string, [number, string]> = {
  banned: [403, "This account cannot make payments. Contact support."],
  too_many: [429, "Too many payment attempts. Please wait a few minutes and try again."],
  too_many_tries: [429, "Too many wrong codes. Please wait an hour and try again."],
  plan: [400, "This plan is not on sale any more. Pick another plan."],
  covered: [409, "Your Premium already covers this plan's end date."],
  pack: [400, "This XP pack is not on sale any more. Pick another one."],
  xp_off: [400, "XP is paused right now."],
};

const USSD_BANKS: Record<string, string> = { "737": "GTBank", "919": "UBA", "822": "Sterling Bank", "966": "Zenith Bank" };

/** Paystack's public key for the in-app sheet, only when it matches the secret key's mode (test with test, live with live). */
function publicKey(): string | null {
  const pk = Deno.env.get("PAYSTACK_PUBLIC_KEY") ?? "";
  const sk = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "";
  const mode = (k: string) => (k.includes("_live_") ? "live" : k.includes("_test_") ? "test" : "");
  return /^pk_(test|live)_[A-Za-z0-9]{20,80}$/.test(pk) && mode(pk) === mode(sk) ? pk : null;
}

/** Opens the payment with Paystack for a reference made by pay_start / xp_pack_start (the server's price). */
async function openPayment(r: Record<string, unknown>, method: string, bank: string, meta: Record<string, unknown>, label: string,
  bankAcct: { code: string; account_number: string } = { code: "", account_number: "" }) {
  const reference = String(r.reference), amount = Number(r.amount_kobo);
  const fail = async (status: number, body: Record<string, unknown> | undefined, kind: string) => {
    await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: kind, p_ok: false,
      p_note: `Paystack answered ${status}: ${String(body?.message ?? "").slice(0, 200)}` });
    await rpc("pay_paystack_result", { p_reference: reference, p_status: "failed", p_amount_kobo: null, p_currency: null,
      p_channel: null, p_data: {}, p_kind: kind, p_event_key: null });
  };
  const metadata = { ...meta, cancel_action: Deno.env.get("PAYSTACK_CALLBACK_URL") || undefined };

  if (method === "bank") {
    const ch = await paystack("/charge", { method: "POST", body: JSON.stringify({ email: r.email, amount, reference, metadata, bank: bankAcct }) });
    if (!ch.ok && !(ch.body?.data && (ch.body.data as Record<string, unknown>).status)) {
      await fail(ch.status, ch.body, "charge");
      return json({ error: `Your bank could not start this payment: ${String(ch.body?.message ?? "try again")}. Try another way.`, code: "paystack" }, 502);
    }
    await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: "charge", p_ok: true, p_note: `${label}: pay with bank ${bankAcct.code} started` });
    return json({ reference, amount_kobo: amount, bank_charge: nextStep((ch.body.data ?? {}) as Record<string, unknown>) });
  }

  if (method === "transfer" || method === "ussd") {
    const body: Record<string, unknown> = { email: r.email, amount, reference, metadata };
    if (method === "transfer") body.bank_transfer = { account_expires_at: new Date(Date.now() + 30 * 60_000).toISOString() };
    else body.ussd = { type: bank };
    const ch = await paystack("/charge", { method: "POST", body: JSON.stringify(body) });
    const d = (ch.body?.data ?? {}) as Record<string, unknown>;
    if (!ch.ok || !d) {
      await fail(ch.status, ch.body, "charge");
      return json({ error: method === "transfer" ? "Bank transfer is not available right now. Try card or USSD." : "USSD is not available right now. Try card or bank transfer.", code: "paystack" }, 502);
    }
    await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: "charge", p_ok: true, p_note: `${label}: ${method}${method === "ussd" ? " " + bank : ""} started` });
    if (method === "transfer") {
      const b = (d.bank ?? {}) as Record<string, unknown>;
      if (!d.account_number) { await fail(ch.status, { message: "no account number" }, "charge"); return json({ error: "Bank transfer is not available right now. Try card or USSD.", code: "paystack" }, 502); }
      return json({ reference, amount_kobo: amount, transfer: {
        account_number: String(d.account_number), account_name: String(d.account_name ?? ""), bank: String(b.name ?? ""),
        expires_at: d.account_expires_at ?? null,
      } });
    }
    const code = String(d.ussd_code ?? "");
    if (!code) { await fail(ch.status, { message: "no USSD code" }, "charge"); return json({ error: "USSD is not available right now. Try card or bank transfer.", code: "paystack" }, 502); }
    return json({ reference, amount_kobo: amount, ussd: { code, bank: USSD_BANKS[bank] ?? bank } });
  }

  const init = await paystack("/transaction/initialize", {
    method: "POST",
    body: JSON.stringify({
      email: r.email, amount, currency: "NGN", reference,
      // Card: Paystack's sheet opens straight on the card form. Page: every method Paystack offers (the backup).
      ...(method === "card" ? { channels: ["card"] } : {}),
      ...(Deno.env.get("PAYSTACK_CALLBACK_URL") ? { callback_url: Deno.env.get("PAYSTACK_CALLBACK_URL") } : {}),
      metadata,
    }),
  });
  if (!init.ok) {
    await fail(init.status, init.body, "initialize");
    return json({ error: "Paystack is not answering right now. Please try again in a moment.", code: "paystack" }, 502);
  }
  const d = init.body.data as Record<string, unknown>;
  await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: "initialize", p_ok: true, p_note: `Paystack checkout opened (${label})` });
  return json({ reference, url: d.authorization_url, access_code: d.access_code, public_key: publicKey(), amount_kobo: amount });
}

/** What the student must do next in a Pay with Bank charge (D-092). */
function nextStep(d: Record<string, unknown>) {
  return {
    status: String(d.status ?? "pending"), // send_otp | send_birthday | send_phone | open_url | pay_offline | pending | success | failed
    text: String(d.display_text ?? d.message ?? d.gateway_response ?? ""),
    // Paystack sends the bank's own page as `url` (open_url) or `redirect_url`.
    url: [d.url, d.redirect_url].find((u) => typeof u === "string" && u.startsWith("https://")) as string | undefined ?? null,
  };
}

let payBankCache: { at: number; banks: { name: string; code: string }[] } | null = null;
async function payBanks() {
  if (payBankCache && Date.now() - payBankCache.at < 6 * 3600_000) return payBankCache.banks;
  const r = await paystack("/bank?country=nigeria&pay_with_bank=true&perPage=200");
  if (!r.ok) throw new Error("pay banks: " + r.status);
  const list = ((r.body.data ?? []) as Record<string, unknown>[])
    .filter((b) => b.active !== false && b.is_deleted !== true && b.code)
    .map((b) => ({ name: String(b.name), code: String(b.code) }))
    .sort((a, b) => a.name.localeCompare(b.name));
  payBankCache = { at: Date.now(), banks: list };
  return list;
}

async function premiumUntil(uid: string): Promise<string | null> {
  const { data } = await admin.from("entitlements").select("expires_at").eq("user_id", uid).is("revoked_at", null)
    .gt("expires_at", new Date().toISOString()).order("expires_at", { ascending: false }).limit(1);
  return data?.[0]?.expires_at ?? null;
}

/** Asks Paystack about a reference and applies the answer (idempotent). */
async function verifyAndApply(reference: string, kind: "verify" | "admin_check") {
  const v = await paystack(`/transaction/verify/${encodeURIComponent(reference)}`);
  if (!v.ok) {
    // 400 "Transaction reference not found": the student has not opened or finished checkout yet.
    await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: kind, p_ok: false,
      p_note: `Verify answered ${v.status}: ${String(v.body?.message ?? "").slice(0, 200)}` });
    return { status: "pending" };
  }
  const d = (v.body.data ?? {}) as Record<string, unknown>;
  if (d.reference !== reference) return { status: "pending" };
  return await rpc<{ status: string }>("pay_paystack_result", {
    p_reference: reference, p_status: String(d.status ?? ""), p_amount_kobo: Number(d.amount ?? -1),
    p_currency: String(d.currency ?? ""), p_channel: (d.channel as string) ?? null, p_data: trimPaystack(d), p_kind: kind, p_event_key: null,
  });
}

// ---------------------------------------------------------------- prize payouts (D-090)
let bankCache: { at: number; banks: { name: string; code: string }[] } | null = null;
async function banks() {
  if (bankCache && Date.now() - bankCache.at < 6 * 3600_000) return bankCache.banks;
  const r = await paystack("/bank?country=nigeria&currency=NGN&perPage=200");
  if (!r.ok) throw new Error("banks: " + r.status);
  const list = ((r.body.data ?? []) as Record<string, unknown>[])
    .filter((b) => b.active !== false && b.is_deleted !== true && b.code)
    .map((b) => ({ name: String(b.name), code: String(b.code) }))
    .sort((a, b) => a.name.localeCompare(b.name));
  bankCache = { at: Date.now(), banks: list };
  return list;
}

const tries = new Map<string, number[]>();
/** At most [n] calls per user per 10 minutes for this kind of call (per server instance; Paystack also limits). */
function allowed(key: string, n: number) {
  const now = Date.now(), list = (tries.get(key) ?? []).filter((t) => now - t < 600_000);
  if (list.length >= n) return false;
  list.push(now);
  tries.set(key, list);
  return true;
}

async function resolveAccount(accountNumber: string, bankCode: string): Promise<string | null> {
  const r = await paystack(`/bank/resolve?account_number=${encodeURIComponent(accountNumber)}&bank_code=${encodeURIComponent(bankCode)}`);
  return r.ok ? String(((r.body.data ?? {}) as Record<string, unknown>).account_name ?? "") || null : null;
}

async function claimRow(id: string) {
  const { data } = await admin.from("prize_claims").select("*").eq("id", id).maybeSingle();
  return data as Record<string, unknown> | null;
}

/** Asks Paystack how a payout went and saves the answer. */
async function verifyPayout(ref: string) {
  const v = await paystack(`/transfer/verify/${encodeURIComponent(ref)}`);
  if (!v.ok) return { ok: false, status: "sending" };
  const d = (v.body.data ?? {}) as Record<string, unknown>;
  return await rpc("payout_result", { p_ref: ref, p_status: String(d.status ?? ""), p_transfer_code: (d.transfer_code as string) ?? null,
    p_note: (d.failures as string) ?? (d.reason as string) ?? null });
}

/** Is the Paystack payouts switch on (Admin → Flags & settings → paystack_payouts)? Off until the business is registered. */
async function payoutsOn(): Promise<boolean> {
  const { data } = await admin.from("feature_flags").select("enabled").eq("key", "paystack_payouts").maybeSingle();
  return data?.enabled === true;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  // Setup check for the owner (GET ?health=1): says only whether the keys are set and in the same mode, never the keys.
  if (req.method === "GET" && new URL(req.url).searchParams.get("health") === "1") {
    const sk = Deno.env.get("PAYSTACK_SECRET_KEY") ?? "", pk = Deno.env.get("PAYSTACK_PUBLIC_KEY") ?? "";
    const mode = (k: string) => (k.includes("_live_") ? "live" : k.includes("_test_") ? "test" : k ? "unknown" : "missing");
    // ?banks=1 also lists the public names of the banks and apps Paystack offers for Pay with Bank on this account.
    const list = new URL(req.url).searchParams.get("banks") === "1" ? (await payBanks().catch(() => [])).map((b) => b.name) : undefined;
    return json({ secret_key: mode(sk), public_key: mode(pk), public_key_usable: publicKey() !== null, payouts_on: await payoutsOn(), pay_with_bank: list });
  }
  if (req.method !== "POST") return json({ error: "POST only" }, 405);
  const user = await userFrom(req);
  if (!user) return json({ error: "Please log in again.", code: "auth" }, 401);
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Bad request" }, 400); }
  const action = String(body.action ?? "");
  const method = ["card", "transfer", "ussd", "bank", "page"].includes(String(body.method)) ? String(body.method) : "card";
  const bank = String(body.bank ?? "737");
  if (method === "ussd" && !USSD_BANKS[bank]) return json({ error: "Choose your bank for USSD." }, 400);
  const bankAcct = { code: String(body.bank_code ?? ""), account_number: String(body.account_number ?? "") };
  if (method === "bank" && (!/^[0-9A-Za-z]{2,12}$/.test(bankAcct.code) || !/^[0-9]{10,11}$/.test(bankAcct.account_number))) {
    return json({ error: "Choose your bank or app and enter your 10-digit account number." }, 400);
  }

  try {
    if (action === "start") {
      const plan = String(body.plan ?? "");
      const code = typeof body.code === "string" ? body.code.slice(0, 40) : null;
      const r = await rpc<Record<string, unknown>>("pay_start", { p_uid: user.id, p_plan: plan, p_code: code, p_source: body.source === "web" ? "web" : "app" });
      if (!r.ok) {
        const e = String(r.error ?? "");
        const [status, message] = ERR[e] ?? [400, "That code cannot be used."];
        return json({ error: message, code: e, plans: r.plans ?? null }, status);
      }
      if (r.free) return json({ free: true, reference: r.reference, expires_at: r.expires_at });
      return await openPayment(r, method, bank, { payment_id: r.payment_id, plan }, "plan", bankAcct);
    }

    if (action === "start_xp") {
      const xp = Number(body.xp ?? 0);
      if (!Number.isInteger(xp) || xp <= 0) return json({ error: "Choose an XP pack." }, 400);
      const r = await rpc<Record<string, unknown>>("xp_pack_start", { p_uid: user.id, p_xp: xp, p_source: body.source === "web" ? "web" : "app" });
      if (!r.ok) {
        const [status, message] = ERR[String(r.error ?? "")] ?? [400, "This XP pack cannot be bought right now."];
        return json({ error: message, code: r.error }, status);
      }
      return await openPayment(r, method, bank, { payment_id: r.payment_id, xp_pack: xp }, "XP pack", bankAcct);
    }

    if (action === "pay_banks") {
      return json({ banks: await payBanks() });
    }

    if (action === "charge_submit") {
      const reference = String(body.reference ?? ""), step = String(body.step ?? ""), value = String(body.value ?? "").trim();
      if (!/^st_[0-9a-f]{20}$/.test(reference)) return json({ error: "Bad reference" }, 400);
      const rule: Record<string, RegExp> = { otp: /^[0-9]{4,8}$/, birthday: /^(19|20)[0-9]{2}-[01][0-9]-[0-3][0-9]$/, phone: /^\+?[0-9]{10,14}$/ };
      if (!rule[step]) return json({ error: "Bad step" }, 400);
      if (!rule[step].test(value)) {
        return json({ error: step === "otp" ? "Enter the code your bank sent you." : step === "birthday" ? "Choose your date of birth." : "Enter your phone number." }, 400);
      }
      const { data: pay } = await admin.from("payments").select("user_id, status, provider").eq("reference", reference).maybeSingle();
      if (!pay || pay.provider !== "paystack" || pay.user_id !== user.id) return json({ error: "Payment not found" }, 404);
      if (pay.status !== "pending") return json({ bank_charge: { status: pay.status === "success" ? "success" : "failed", text: "", url: null } });
      if (!allowed("submit:" + user.id, 12)) return json({ error: "Too many tries. Please wait a few minutes.", code: "too_many" }, 429);
      const sub = await paystack(`/charge/submit_${step}`, { method: "POST", body: JSON.stringify({ [step]: value, reference }) });
      const d = (sub.body?.data ?? {}) as Record<string, unknown>;
      if (!sub.ok && !d.status) return json({ error: String(sub.body?.message ?? "Your bank did not accept that. Try again.") }, 400);
      const next = nextStep(d);
      if (next.status === "success" || next.status === "failed") await verifyAndApply(reference, "verify");
      return json({ bank_charge: next });
    }

    if (action === "banks") {
      return json({ banks: await banks() });
    }

    if (action === "resolve") {
      const acct = String(body.account_number ?? ""), code = String(body.bank_code ?? "");
      if (!/^[0-9]{10}$/.test(acct) || !/^[0-9A-Za-z]{2,12}$/.test(code)) return json({ error: "Enter the 10-digit account number and choose your bank." }, 400);
      if (!allowed("resolve:" + user.id, 10)) return json({ error: "Too many tries. Please wait a few minutes.", code: "too_many" }, 429);
      const name = await resolveAccount(acct, code);
      if (!name) return json({ error: "We could not find this account. Check the number and the bank.", code: "not_found" }, 404);
      return json({ account_name: name });
    }

    if (action === "payout_check" || action === "payout_send" || action === "payout_verify") {
      const isAdmin = (await asUser(user.token).rpc("am_money_admin")).data === true;
      if (!isAdmin) return json({ error: "Only admins with 2-step login can pay prizes." }, 403);
      const id = String(body.claim_id ?? "");
      if (!/^[0-9a-f-]{36}$/.test(id)) return json({ error: "Bad claim" }, 400);
      const c = await claimRow(id);
      if (!c) return json({ error: "Claim not found" }, 404);
      if (action !== "payout_verify" && !(await payoutsOn())) {
        return json({ error: "Paystack payouts are switched off (Flags & settings → paystack_payouts). Pay by hand, then tap “I paid it myself”." }, 409);
      }

      if (action === "payout_check") {
        if (!c.bank_code) return json({ error: "This winner sent the bank as text (older app). Pay by hand, or ask them to update the app and send it again." }, 409);
        const name = await resolveAccount(String(c.account_number), String(c.bank_code));
        if (!name) return json({ error: "Paystack could not find this account. Ask the winner to check it." }, 404);
        const r = await rpc<Record<string, unknown>>("payout_checked", { p_claim: id, p_admin: user.id, p_name: name });
        return r.ok ? json(r) : json({ error: r.error }, 409);
      }

      if (action === "payout_verify") {
        if (!c.payout_ref) return json({ error: "Nothing was sent yet." }, 409);
        return json(await verifyPayout(String(c.payout_ref)));
      }

      // payout_send
      const b = await rpc<Record<string, unknown>>("payout_begin", { p_claim: id, p_admin: user.id });
      if (!b.ok) return json({ error: b.error }, 409);
      const ref = String(b.ref);
      let recipient = (b.recipient_code as string) ?? "";
      if (!recipient) {
        const rc = await paystack("/transferrecipient", { method: "POST", body: JSON.stringify({
          type: "nuban", name: b.name, account_number: b.account_number, bank_code: b.bank_code, currency: "NGN",
        }) });
        if (!rc.ok) {
          await rpc("payout_result", { p_ref: ref, p_status: "failed", p_note: `Recipient: ${String(rc.body?.message ?? rc.status).slice(0, 200)}` });
          return json({ error: `Paystack refused the account: ${String(rc.body?.message ?? "")}` }, 502);
        }
        recipient = String(((rc.body.data ?? {}) as Record<string, unknown>).recipient_code ?? "");
        await rpc("payout_recipient", { p_claim: id, p_code: recipient });
      }
      const t = await paystack("/transfer", { method: "POST", body: JSON.stringify({
        source: "balance", amount: Number(b.amount) * 100, recipient, reference: ref, currency: "NGN", reason: "SolutionTee challenge prize",
      }) });
      const d = (t.body?.data ?? {}) as Record<string, unknown>;
      if (!t.ok) {
        const msg = String(t.body?.message ?? t.status);
        await rpc("payout_result", { p_ref: ref, p_status: "failed", p_note: msg.slice(0, 280) });
        return json({ error: /balance/i.test(msg) ? "Your Paystack balance is too low for this prize. Top it up, then try again."
          : /otp/i.test(msg) ? "Paystack wants an OTP for each transfer. Turn off transfer OTP in Paystack (SETUP §18), then try again."
          : `Paystack refused the transfer: ${msg}` }, 502);
      }
      if (d.status === "otp") {
        await rpc("payout_result", { p_ref: ref, p_status: "failed", p_note: "Transfer OTP is on in Paystack" });
        return json({ error: "Paystack wants an OTP for each transfer. Turn off transfer OTP in Paystack (SETUP §18), then try again." }, 409);
      }
      const r = await rpc<Record<string, unknown>>("payout_result", { p_ref: ref, p_status: String(d.status ?? "pending"), p_transfer_code: (d.transfer_code as string) ?? null });
      return json({ ok: true, status: r.status });
    }

    if (action === "check" || action === "refund") {
      const reference = String(body.reference ?? "");
      if (!/^st_[0-9a-f]{20}$/.test(reference)) return json({ error: "Bad reference" }, 400);
      const { data: pay } = await admin.from("payments").select("user_id, status, provider").eq("reference", reference).maybeSingle();
      if (!pay || pay.provider !== "paystack") return json({ error: "Payment not found" }, 404);
      const isAdmin = (await asUser(user.token).rpc("am_money_admin")).data === true;
      if (pay.user_id !== user.id && !isAdmin) return json({ error: "Payment not found" }, 404);

      if (action === "check") {
        const r = pay.status === "pending" || pay.status === "failed" ? await verifyAndApply(reference, isAdmin && pay.user_id !== user.id ? "admin_check" : "verify")
          : { status: pay.status };
        return json({ status: r.status, expires_at: r.status === "success" && pay.user_id ? await premiumUntil(pay.user_id) : null });
      }

      if (!isAdmin) return json({ error: "Only admins with 2-step login can refund." }, 403);
      if (pay.status !== "success") return json({ error: "Only successful payments can be refunded." }, 409);
      const ref = await paystack("/refund", { method: "POST", body: JSON.stringify({ transaction: reference }) });
      await rpc("pay_note", { p_reference: reference, p_provider: "paystack", p_kind: "refund_requested", p_ok: ref.ok,
        p_note: ref.ok ? "Refund asked for by an admin; Premium is removed when Paystack finishes it" : `Paystack refused: ${String(ref.body?.message ?? ref.status).slice(0, 200)}` });
      if (!ref.ok) return json({ error: String(ref.body?.message ?? "Paystack refused the refund.") }, 502);
      return json({ requested: true });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: "Something went wrong. Please try again.", code: "server" }, 500);
  }
});
