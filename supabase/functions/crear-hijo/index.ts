import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

interface CrearHijoRequest {
  nombre: string;
  apellidos?: string;
  cinturon?: string | null;
}

interface CrearHijoResponse {
  hijo_id: string;
  familia_id: string;
  error?: string;
}

export default async (req: Request): Promise<Response> => {
  // Solo POST
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // Crear cliente admin (con service_role, puede manipular auth.users)
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") || "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "",
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    );

    // Obtener el JWT del caller para saber quién es el padre
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "No authorization header" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const token = authHeader.replace("Bearer ", "");

    // Crear cliente con el token del caller (solo lectura/verificación)
    const supabaseUser = createClient(
      Deno.env.get("SUPABASE_URL") || "",
      Deno.env.get("SUPABASE_ANON_KEY") || "",
      {
        global: {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        },
      }
    );

    // Obtener perfil del padre/caller
    const { data: callerProfile, error: callerError } = await supabaseUser
      .from("profiles")
      .select("id, academia_id, rol")
      .single();

    if (callerError || !callerProfile) {
      return new Response(
        JSON.stringify({ error: "Caller profile not found" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    // Solo alumnos y padres pueden crear hijos (filosofía: cualquier perfil activo puede ser padre)
    if (!["alumno", "profesor", "dueño"].includes(callerProfile.rol)) {
      return new Response(
        JSON.stringify({
          error: `Role ${callerProfile.rol} cannot create children`,
        }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }

    const body = (await req.json()) as CrearHijoRequest;
    const { nombre, apellidos, cinturon } = body;

    if (!nombre || nombre.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "nombre is required and non-empty" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // 1. Crear usuario en auth sin contraseña (bloqueado)
    // Generar email temporal único para el menor
    const timestamp = Date.now();
    const randomId = Math.random().toString(36).substring(7);
    const tempEmail = `child-${timestamp}-${randomId}@local.reservas`;

    const { data: newAuthUser, error: authError } =
      await supabaseAdmin.auth.admin.createUser({
        email: tempEmail,
        password: undefined, // No password = cuenta bloqueada
        email_confirm: true,
        user_metadata: {
          parent_id: callerProfile.id,
          child_first_name: nombre,
        },
      });

    if (authError || !newAuthUser.user) {
      console.error("Auth creation error:", authError);
      return new Response(
        JSON.stringify({ error: "Failed to create auth user" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const childUserId = newAuthUser.user.id;

    // 2. Crear perfil del hijo llamando a la función SQL
    // (que también crea la relación familia)
    // Los menores no usan auth.users reales: solo profiles vincuados por relaciones_familia
    const { data: result, error: profileError } = await supabaseAdmin.rpc(
      "crear_perfil_hijo",
      {
        p_parent_id: callerProfile.id,
        p_academia_id: callerProfile.academia_id,
        p_nombre: nombre,
        p_apellidos: apellidos || null,
        p_cinturon: cinturon || null,
      }
    );

    if (profileError || !result) {
      // Limpiar auth.user si falla el perfil
      await supabaseAdmin.auth.admin.deleteUser(childUserId);
      console.error("Profile creation error:", profileError);
      return new Response(
        JSON.stringify({ error: "Failed to create profile" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // result es un array con un objeto {hijo_id, familia_id}
    const [{ hijo_id, familia_id }] = result;

    const response: CrearHijoResponse = {
      hijo_id,
      familia_id,
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error creating child:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
};
