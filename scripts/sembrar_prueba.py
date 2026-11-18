#!/usr/bin/env python3
"""Datos FICTICIOS para probar la app en un Supabase que NO es producción.

Uso:
    SUPABASE_URL=... SERVICE_ROLE_KEY=... DB_URL=... CLAVE_PRUEBA=... \
        python3 scripts/sembrar_prueba.py

- Se niega a ejecutarse contra el proyecto de producción.
- Crea la academia ITACA de prueba, las cuentas de dueño, profesor y alumnos,
  tarifas y dos semanas de clases. Todas las cuentas usan CLAVE_PRUEBA, que
  no se guarda en el repositorio.
- Se puede repetir: no duplica nada.
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

PRODUCCION = "dpcdpcvjcutcqyqcacti"
ACADEMIA = "11111111-1111-4111-8111-111111111111"

url = os.environ["SUPABASE_URL"].rstrip("/")
clave_servicio = os.environ["SERVICE_ROLE_KEY"]
db_url = os.environ["DB_URL"]
clave = os.environ["CLAVE_PRUEBA"]

if PRODUCCION in url or PRODUCCION in db_url:
    sys.exit("Esto es producción. Los datos de prueba no se siembran ahí.")

CUENTAS = [
    # correo, nombre, apellidos, rol, estado
    ("dueno@prueba.itaca.test", "Diana", "Dueña", "dueño", "activo"),
    ("profe@prueba.itaca.test", "Pablo", "Profesor", "profesor", "activo"),
    ("alumno1@prueba.itaca.test", "Ana", "Alumna", "alumno", "activo"),
    ("alumno2@prueba.itaca.test", "Bruno", "Bono", "alumno", "activo"),
    ("tutor@prueba.itaca.test", "Teresa", "Tutora", "alumno", "activo"),
]


def sql(texto):
    r = subprocess.run(
        ["psql", db_url, "-v", "ON_ERROR_STOP=1", "-At", "-c", texto],
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        sys.exit(r.stderr)
    return r.stdout.strip()


def admin(metodo, ruta, cuerpo=None):
    req = urllib.request.Request(
        f"{url}/auth/v1/admin/{ruta}",
        method=metodo,
        data=json.dumps(cuerpo).encode() if cuerpo is not None else None,
        headers={
            "apikey": clave_servicio,
            "Authorization": f"Bearer {clave_servicio}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        return {"error": e.read().decode()}


sql(
    f"""
    insert into public.academias (id, nombre, direccion, estado, zona_horaria,
                                  lista_espera_activa, cancelacion_limite_minutos)
    values ('{ACADEMIA}', 'ITACA JIU JITSU (PRUEBA)', 'Logroño', 'approved',
            'Europe/Madrid', false, 60)
    on conflict (id) do update set lista_espera_activa = false;
    """
)

for correo, nombre, apellidos, rol, estado in CUENTAS:
    existente = sql(f"select id from auth.users where email = '{correo}'")
    if existente:
        uid = existente
        admin("PUT", f"users/{uid}", {"password": clave})
    else:
        # Sin `nombre` en los metadatos: el disparador de alta no crea perfil
        # y lo ponemos aquí con su rol.
        r = admin(
            "POST",
            "users",
            {"email": correo, "password": clave, "email_confirm": True},
        )
        if "id" not in r:
            sys.exit(f"No se pudo crear {correo}: {r}")
        uid = r["id"]
    sql(
        f"""
        insert into public.profiles (id, academia_id, rol, nombre, apellidos, estado, cinturon)
        values ('{uid}', '{ACADEMIA}', '{rol}', '{nombre}', '{apellidos}', '{estado}', 'blanco')
        on conflict (id) do update set rol = excluded.rol, estado = excluded.estado;
        """
    )

dueno = sql("select id from auth.users where email = 'dueno@prueba.itaca.test'")
profe = sql("select id from auth.users where email = 'profe@prueba.itaca.test'")
tutor = sql("select id from auth.users where email = 'tutor@prueba.itaca.test'")

# Un menor sin cuenta, hijo de la tutora.
sql(
    f"""
    insert into public.profiles (id, academia_id, rol, nombre, apellidos, estado,
                                 cinturon, tiene_cuenta)
    values ('22222222-2222-4222-8222-222222222222', '{ACADEMIA}', 'alumno',
            'Hugo', 'Hijo', 'activo', 'gris', false)
    on conflict (id) do nothing;
    insert into public.relaciones_familia (parent_id, child_id, tipo_relacion)
    select '{tutor}', '22222222-2222-4222-8222-222222222222', 'padre'
     where not exists (select 1 from public.relaciones_familia
                        where child_id = '22222222-2222-4222-8222-222222222222');
    """
)

sql(
    f"""
    insert into public.tarifas (id, academia_id, nombre, descripcion, precio, periodicidad, clases_incluidas)
    values
      ('33333333-3333-4333-8333-333333333301', '{ACADEMIA}', 'Ilimitada', 'Todas las clases', 80, 'mensual', null),
      ('33333333-3333-4333-8333-333333333302', '{ACADEMIA}', '2 días por semana', '8 clases al mes', 50, 'mensual', 8),
      ('33333333-3333-4333-8333-333333333303', '{ACADEMIA}', 'Bono 10 sesiones', '10 clases en 3 meses', 80, 'trimestral', 10),
      ('33333333-3333-4333-8333-333333333304', '{ACADEMIA}', 'Día suelto', 'Una clase', 10, 'suelta', 1)
    on conflict (id) do nothing;
    """
)

# Dos semanas de clases a hora de pared de Madrid, más dos para los casos de
# recepción: una que ya ha empezado y otra que empieza en 20 minutos.
sql(
    f"""
    insert into public.clases (academia_id, profesor_id, titulo, descripcion,
                               fecha_hora_inicio, fecha_hora_fin, aforo_maximo)
    select '{ACADEMIA}', '{profe}', t.titulo, 'Clase ficticia de prueba',
           ((d::date + t.hora) at time zone 'Europe/Madrid'),
           ((d::date + t.hora + interval '1 hour') at time zone 'Europe/Madrid'),
           t.aforo
      from generate_series(current_date, current_date + 13, interval '1 day') d
      cross join (values ('Fundamentos', time '10:00', 20),
                         ('Avanzados', time '19:00', 20),
                         ('Grupo reducido', time '20:15', 2)) as t(titulo, hora, aforo)
     where not exists (
       select 1 from public.clases c
        where c.academia_id = '{ACADEMIA}' and c.titulo = t.titulo
          and c.fecha_hora_inicio = ((d::date + t.hora) at time zone 'Europe/Madrid'));

    insert into public.clases (academia_id, profesor_id, titulo, descripcion,
                               fecha_hora_inicio, fecha_hora_fin, aforo_maximo)
    select '{ACADEMIA}', '{profe}', x.titulo, 'Clase ficticia de prueba', x.inicio,
           x.inicio + interval '1 hour', 20
      from (values ('Ya empezada', now() - interval '10 minutes'),
                   ('Empieza enseguida', now() + interval '20 minutes')) as x(titulo, inicio)
     where not exists (select 1 from public.clases c
                        where c.academia_id = '{ACADEMIA}' and c.titulo = x.titulo
                          and c.fecha_hora_inicio > now() - interval '1 hour');
    """
)

print("Academia:", ACADEMIA)
print("Cuentas:", ", ".join(c[0] for c in CUENTAS))
print("Clases futuras:", sql(f"select count(*) from public.clases where academia_id = '{ACADEMIA}' and fecha_hora_inicio > now()"))
