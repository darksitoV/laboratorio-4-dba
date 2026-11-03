-- =============================================================================
-- LAB-04: Hardening y configuración segura de PostgreSQL
-- Script 01: Inspección inicial de superficie de ataque y configuración
-- Motor: PostgreSQL 16
-- Estudiante: Genaro Isaac Cárdenas Soto (@darksitoV)
-- Organización: Comercializadora Norte S.A. de C.V.
-- =============================================================================

-- 1. Versión del motor y parámetros de red y autenticación iniciales
SELECT version();

SHOW port;
SHOW listen_addresses;
SHOW ssl;
SHOW password_encryption;

-- 2. Conexiones activas actuales en el servidor
SELECT 
    pid, 
    usename, 
    datname, 
    client_addr, 
    client_port, 
    application_name 
FROM pg_stat_activity;

-- 3. Ubicación física de archivos de configuración y datos
SHOW config_file;
SHOW hba_file;
SHOW ident_file;
SHOW data_directory;
SHOW log_directory;

-- 4. Parámetros actuales de registro (logging)
SHOW log_connections;
SHOW log_disconnections;

-- 5. Reglas de autenticación basadas en host (pg_hba.conf)
SELECT 
    line_number,
    type, 
    database, 
    user_name, 
    address, 
    auth_method 
FROM pg_hba_file_rules
ORDER BY line_number;

-- 6. Extensiones actualmente instaladas en la base de datos
SELECT 
    extname, 
    extversion 
FROM pg_extension 
ORDER BY extname;

-- 7. Parámetros de gestión y límites de conexiones
SHOW max_connections;
SHOW superuser_reserved_connections;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;

-- 8. Verificación de parámetros TLS
SHOW ssl_min_protocol_version;
SELECT 
    pid, 
    ssl, 
    version, 
    cipher, 
    bits 
FROM pg_stat_ssl 
WHERE pid = pg_backend_pid();
