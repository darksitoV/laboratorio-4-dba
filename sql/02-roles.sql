-- =============================================================================
-- LAB-04: Hardening y configuración segura de PostgreSQL
-- Script 02: Separación de cuentas, roles y principio de mínimo privilegio
-- Motor: PostgreSQL 16
-- Estudiante: Genaro Isaac Cárdenas Soto (@darksitoV)
-- Organización: Comercializadora Norte S.A. de C.V.
-- =============================================================================

-- 1. Inspección de roles existentes y atributos de privilegios
SELECT 
    rolname, 
    rolsuper, 
    rolinherit, 
    rolcreaterole, 
    rolcreatedb, 
    rolcanlogin 
FROM pg_roles 
ORDER BY rolname;

-- 2. Creación de cuenta de servicio de aplicación (APP) con privilegios acotados
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'usr_app') THEN
        CREATE ROLE usr_app WITH LOGIN PASSWORD 'AppPassword_2026_Secure!';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'usr_consulta') THEN
        CREATE ROLE usr_consulta WITH LOGIN PASSWORD 'ConsultaPass_2026_ReadOnly!';
    END IF;
END $$;

-- 3. Asignación de privilegios mínimos sobre la base de datos y esquema
GRANT CONNECT ON DATABASE lab01_db TO usr_app, usr_consulta;
GRANT USAGE ON SCHEMA public TO usr_app, usr_consulta;

-- 4. Permisos CRUD específicos para la aplicación (sin SUPERUSER ni DDL)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE clientes TO usr_app;

-- 5. Permisos de solo lectura para cuenta de consulta/reportería
GRANT SELECT ON TABLE clientes TO usr_consulta;

-- 6. Verificación de privilegios de tablas asignados
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type 
FROM information_schema.role_table_grants 
WHERE grantee IN ('usr_app', 'usr_consulta', 'postgres')
ORDER BY grantee, privilege_type;

-- 7. Comprobación de que las cuentas de servicio NO poseen atributos de superusuario
SELECT 
    rolname, 
    rolsuper, 
    rolcreaterole, 
    rolcreatedb, 
    rolcanlogin
FROM pg_roles
WHERE rolname IN ('postgres', 'usr_app', 'usr_consulta', 'analista', 'soporte')
ORDER BY rolname;
