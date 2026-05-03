// Supabase Edge Function: send_family_invite_email
// Creates a single-use invite for a given email and optionally sends it via Resend.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS_HEADERS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-max-age": "86400",
};

function json(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      ...CORS_HEADERS,
      "content-type": "application/json; charset=utf-8",
      ...(init.headers ?? {}),
    },
  });
}

function randomCode(length = 10) {
  const alphabet = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  let out = "";
  for (let i = 0; i < length; i++) out += alphabet[bytes[i] % alphabet.length];
  return out;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, { status: 405 });

  try {
    const authHeader = req.headers.get("authorization") ?? "";

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Use the caller's JWT to enforce RLS (only family owner can create invites).
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const payload = await req.json().catch(() => ({}));
    const familyId = String(payload.family_id ?? "").trim();
    const email = String(payload.email ?? "").trim().toLowerCase();

    if (!familyId) return json({ error: "missing_family_id" }, { status: 400 });
    if (!email || !email.includes("@")) return json({ error: "invalid_email" }, { status: 400 });

    // Create invite (single-use, 7 day expiry)
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

    // Retry in case of ultra-rare code collision.
    let invite: any | null = null;
    for (let i = 0; i < 5; i++) {
      const code = randomCode(10);
      const { data, error } = await supabase
        .from("family_invites")
        .insert({ family_id: familyId, code, email, max_uses: 1, expires_at: expiresAt })
        .select("id, code")
        .single();
      if (!error) {
        invite = data;
        break;
      }
    }

    if (!invite) return json({ error: "invite_create_failed" }, { status: 500 });

    const baseUrl = (Deno.env.get("APP_BASE_URL") ?? "").trim();
    const inviteLink = baseUrl
      ? `${baseUrl.replace(/\/$/, "")}/#/join?code=${encodeURIComponent(invite.code)}`
      : `join?code=${invite.code}`;

    const resendKey = (Deno.env.get("RESEND_API_KEY") ?? "").trim();
    const fromEmail = (Deno.env.get("RESEND_FROM") ?? "Family Map <onboarding@resend.dev>").trim();

    let emailSent = false;
    if (resendKey) {
      const subject = "You're invited to join a family";
      const html = `
        <div style="font-family:ui-sans-serif, system-ui; line-height:1.5">
          <h2>You're invited</h2>
          <p>Use this invite code:</p>
          <p style="font-size:20px; font-weight:700; letter-spacing:1px">${invite.code}</p>
          <p>Or open this link:</p>
          <p><a href="${inviteLink}">${inviteLink}</a></p>
          <p style="color:#666">This invite expires in 7 days.</p>
        </div>
      `;

      const resp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ from: fromEmail, to: [email], subject, html }),
      });

      emailSent = resp.ok;
    }

    return json({ invite_link: inviteLink, code: invite.code, email_sent: emailSent });
  } catch (e) {
    return json({ error: "unexpected", details: String(e) }, { status: 500 });
  }
});
