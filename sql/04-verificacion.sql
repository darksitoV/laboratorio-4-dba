-- =============================================================================
-- LAB-04: Hardening y configuración segura de PostgreSQL
-- Script 04: Verificación integral de la línea base de seguridad
-- Motor: PostgreSQL 16
-- Estudiante: Genaro Isaac Cárdenas Soto (@darksitoV)
-- Organización: Comercializadora Norte S.A. de C.V.
-- =============================================================================

-- 1. Verificación de parámetros de configuración endurecidos
SELECT 
    name, 
    setting, 
    unit, 
    source 
FROM pg_settings 
WHERE name IN (
    'statement_timeout', 
    'idle_in_transaction_session_timeout', 
    'log_connections', 
    'log_disconnections', 
    'password_encryption', 
    'ssl', 
    'max_connections'
)
ORDER BY name;

-- 2. Verificación de cuentas no administrativas y sus permisos específicos
SELECT 
    grantee, 
    table_schema, 
    table_name, 
    privilege_type 
FROM information_schema.role_table_grants 
WHERE grantee IN ('usr_app', 'usr_consulta')
ORDER BY grantee, privilege_type;

-- 3. Confirmación de que las cuentas creadas no poseen SUPERUSER ni atributos elevados
SELECT 
    rolname, 
    rolsuper, 
    rolcreaterole, 
    rolcreatedb, 
    rolcanlogin 
FROM pg_roles 
WHERE rolname IN ('postgres', 'usr_app', 'usr_consulta')
ORDER BY rolname;

-- 4. Comprobación de estado de cifrado de canal (TLS) en conexiones activas
SELECT 
    pid, 
    ssl, 
    version, 
    cipher, 
    bits 
FROM pg_stat_ssl 
WHERE pid = pg_backend_pid();

-- 5. Consulta de conexiones activas para auditoría
SELECT 
    pid, 
    usename, 
    datname, 
    client_addr, 
    state 
FROM pg_stat_activity 
WHERE datname = 'lab01_db';
