import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Body = {
  full_name?: string;
  email?: string;
  password?: string;
  role?: string;
};

// Names must NOT start with SUPABASE_ — Supabase CLI rejects those secret keys.
const supabaseUrl = Deno.env.get("FACTORYOS_SUPABASE_URL")!;
const anonKey = Deno.env.get("FACTORYOS_SUPABASE_ANON_KEY")!;
const serviceRole = Deno.env.get("FACTORYOS_SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: userErr,
  } = await userClient.auth.getUser();

  if (userErr || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const adminClient = createClient(supabaseUrl, serviceRole);

  const { data: actorProfile, error: actorErr } = await adminClient
    .from("user_profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  if (actorErr || !actorProfile) {
    return new Response(JSON.stringify({ error: "Cannot resolve actor profile" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (actorProfile.role !== "manager" && actorProfile.role !== "admin") {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  const body = (await req.json()) as Body;
  const fullName = body.full_name?.trim();
  const email = body.email?.trim().toLowerCase();
  const password = body.password;
  const role = body.role;

  if (!fullName || !email || !password || !role) {
    return new Response(JSON.stringify({ error: "Missing required fields" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (role !== "worker" && role !== "qa") {
    return new Response(JSON.stringify({ error: "Role must be worker or qa" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
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
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      user_id: data.user?.id,
      email,
      role,
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    },
  );
});
