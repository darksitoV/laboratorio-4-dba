-- =============================================================================
-- LAB-04: Hardening y configuración segura de PostgreSQL
-- Script 03: Aplicación de parámetros de configuración segura (Hardening)
-- Motor: PostgreSQL 16
-- Estudiante: Genaro Isaac Cárdenas Soto (@darksitoV)
-- Organización: Comercializadora Norte S.A. de C.V.
-- =============================================================================

-- 1. Establecimiento de tiempos límite de ejecución (mitigación de DoS y consultas descontroladas)
ALTER SYSTEM SET statement_timeout = '30s';

-- 2. Límite para transacciones inactivas (evita agotamiento de conexiones y bloqueos residuales)
ALTER SYSTEM SET idle_in_transaction_session_timeout = '60s';

-- 3. Habilitación de registro de auditoría de conexiones y desconexiones
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';

-- 4. Forzar el método robusto SCRAM-SHA-256 para almacenamiento de credenciales
ALTER SYSTEM SET password_encryption = 'scram-sha-256';

-- 5. Recarga de configuración en caliente sin detener el servicio
SELECT pg_reload_conf();

-- 6. Verificación de los parámetros modificados en memoria
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;
SHOW log_connections;
SHOW log_disconnections;
SHOW password_encryption;
