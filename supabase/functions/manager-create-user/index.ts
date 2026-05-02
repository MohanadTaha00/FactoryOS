import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Body = {
  full_name?: string;
  email?: string;
  password?: string;
  role?: string;
};

/** Non-empty trimmed env value, or undefined */
function trimEnv(name: string): string | undefined {
  const v = Deno.env.get(name)?.trim();
  return v && v.length > 0 ? v : undefined;
}

function parseJsonDefault(raw: string | undefined): string | undefined {
  if (!raw) return undefined;
  try {
    const d = JSON.parse(raw) as Record<string, string>;
    const v = d.default ?? Object.values(d)[0];
    return typeof v === "string" && v.trim().length > 0 ? v.trim() : undefined;
  } catch {
    return undefined;
  }
}

/** JWT payload.role — Supabase API keys are JWTs with role anon | service_role */
function jwtRole(token: string): string | undefined {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return undefined;
    let b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const pad = b64.length % 4;
    if (pad) b64 += "=".repeat(4 - pad);
    const payload = JSON.parse(atob(b64)) as { role?: string };
    return typeof payload.role === "string" ? payload.role : undefined;
  } catch {
    return undefined;
  }
}

function pickKey(
  role: "anon" | "service_role",
  ...candidates: (string | undefined)[]
): string | undefined {
  for (const c of candidates) {
    if (!c) continue;
    if (jwtRole(c) === role) return c;
  }
  return undefined;
}

function resolveSupabaseConfig():
  | { ok: true; url: string; anonKey: string; serviceRole: string }
  | { ok: false; message: string } {
  const url =
    trimEnv("FACTORYOS_SUPABASE_URL") ?? trimEnv("SUPABASE_URL");
  const publishableRaw = trimEnv("SUPABASE_PUBLISHABLE_KEYS");
  const secretRaw = trimEnv("SUPABASE_SECRET_KEYS");

  const anonKey = pickKey(
    "anon",
    trimEnv("FACTORYOS_SUPABASE_ANON_KEY"),
    trimEnv("SUPABASE_ANON_KEY"),
    parseJsonDefault(publishableRaw),
  );

  const serviceRole = pickKey(
    "service_role",
    trimEnv("FACTORYOS_SUPABASE_SERVICE_ROLE_KEY"),
    trimEnv("SUPABASE_SERVICE_ROLE_KEY"),
    parseJsonDefault(secretRaw),
  );

  if (!url) {
    return {
      ok: false,
      message:
        "Missing Supabase URL (FACTORYOS_SUPABASE_URL or SUPABASE_URL).",
    };
  }
  if (!anonKey) {
    return {
      ok: false,
      message:
        "Missing anon API key (FACTORYOS_SUPABASE_ANON_KEY, SUPABASE_ANON_KEY, or SUPABASE_PUBLISHABLE_KEYS).",
    };
  }
  if (!serviceRole) {
    return {
      ok: false,
      message:
        "No valid service_role JWT found. Paste the service_role key from Project Settings → API into FACTORYOS_SUPABASE_SERVICE_ROLE_KEY, or remove a wrong FACTORYOS_SUPABASE_SERVICE_ROLE_KEY so hosted SUPABASE_SERVICE_ROLE_KEY / SUPABASE_SECRET_KEYS is used.",
    };
  }

  return { ok: true, url, anonKey, serviceRole };
}

function corsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get("Origin");
  return {
    "Access-Control-Allow-Origin": origin ?? "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, x-region",
    "Access-Control-Max-Age": "86400",
  };
}

function json(req: Request, body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders(req) },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }

  if (req.method !== "POST") {
    return json(req, { error: "Method not allowed" }, 405);
  }

  try {
    const cfg = resolveSupabaseConfig();
    if (!cfg.ok) {
      console.error("manager-create-user config:", cfg.message);
      return json(req, { error: "Server misconfiguration (Supabase keys)." }, 500);
    }

    const { url: supabaseUrl, anonKey, serviceRole } = cfg;

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json(req, { error: "Missing Authorization header" }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();

    if (userErr || !user) {
      return json(req, { error: "Unauthorized" }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRole);

    const { data: actorProfile, error: actorErr } = await adminClient
      .from("user_profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();

    if (actorErr || !actorProfile) {
      return json(req, { error: "Cannot resolve actor profile" }, 403);
    }

    if (actorProfile.role !== "manager" && actorProfile.role !== "admin") {
      return json(req, { error: "Forbidden" }, 403);
    }

    let body: Body;
    try {
      body = (await req.json()) as Body;
    } catch {
      return json(req, { error: "Invalid JSON body" }, 400);
    }

    const fullName = body.full_name?.trim();
    const email = body.email?.trim().toLowerCase();
    const password = body.password;
    const role = body.role;

    if (!fullName || !email || !password || !role) {
      return json(req, { error: "Missing required fields" }, 400);
    }

    if (role !== "worker" && role !== "qa") {
      return json(req, { error: "Role must be worker or qa" }, 400);
    }

    const { data, error } = await adminClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        role,
      },
    });

    if (error) {
      return json(req, { error: error.message }, 400);
    }

    return json(
      req,
      {
        user_id: data.user?.id,
        email,
        role,
      },
      200,
    );
  } catch (e) {
    console.error("manager-create-user:", e);
    return json(req, { error: "Internal error" }, 500);
  }
});
