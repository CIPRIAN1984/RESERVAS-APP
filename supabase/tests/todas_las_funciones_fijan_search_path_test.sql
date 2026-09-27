-- Toda función propia del esquema public fija su search_path. Sin él, una
-- función resuelve los nombres de tabla según el search_path de quien la
-- llama, y en una security definer eso permite suplantar tablas. Ver
-- 20260927090000_auditoria_bd.sql. Las funciones de extensiones (pgTAP,
-- pgcrypto…) no son nuestras y se excluyen.
begin;
select plan(1);

select is(
  array(
    select p.proname::text
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and not exists (
         select 1 from pg_depend d
          where d.objid = p.oid and d.deptype = 'e'
       )
       and not exists (
         select 1 from unnest(coalesce(p.proconfig, '{}')) c
          where c like 'search_path=%'
       )
     order by 1
  ),
  array[]::text[],
  'Ninguna función de public se queda sin search_path fijo'
);

select * from finish();
rollback;
