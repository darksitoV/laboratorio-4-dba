# LAB-04 — Hardening y configuración segura de PostgreSQL

* **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos  
* **Unidad:** II — Seguridad, privacidad y control de acceso  
* **Tema:** 2.6 Hardening de bases de datos  
* **Motor:** PostgreSQL 16  
* **Estudiante:** Genaro Isaac Cárdenas Soto (@darksitoV)  
* **Organización / Escenario:** Comercializadora Norte S.A. de C.V.  
* **Repositorio Oficial:** [laboratorio-4-dba (GitHub)](https://github.com/darksitoV/laboratorio-4-dba.git)  

---

## Estructura del Repositorio

```text
laboratorio-4-dba/
├── .gitignore
├── README.md                           # Documento principal y resumen ejecutivo (Sección 28)
├── informe.md                          # Respuestas a las 10 preguntas y reflexión (Secciones 30 y 31)
├── sql/                                # Scripts SQL para PostgreSQL 16
│   ├── 01-inspeccion.sql               # Inspección inicial de superficie de ataque
│   ├── 02-roles.sql                    # Creación y segregación de cuentas de servicio
│   ├── 03-configuracion.sql            # Aplicación de parámetros de hardening
│   └── 04-verificacion.sql             # Verificación de parámetros y permisos aplicados
├── configuracion/                      # Documentación de línea base y registro de cambios
│   ├── baseline.md                     # Propuesta de baseline de seguridad institucional
│   └── cambios.md                      # Matriz comparativa de estado: Antes vs Después
└── evidencias/                         # Capturas de ejecución en formato PNG
    ├── 01-superficie-ataque.png        # Evidencia de versión, puertos y conexiones iniciales
    ├── 02-listen-addresses.png         # Evidencia de interfaces de escucha y netstat
    ├── 03-pg-hba.png                   # Evidencia de reglas en pg_hba_file_rules
    ├── 04-roles.png                    # Evidencia de roles segregados y permisos
    ├── 05-tls.png                      # Evidencia de parámetros TLS y pg_stat_ssl
    └── 06-verificacion.png             # Evidencia de verificación de parámetros aplicados
```

---

## Objetivo
Aplicar un proceso de hardening sobre una instancia de PostgreSQL 16 para la empresa Comercializadora Norte S.A. de C.V., identificando configuraciones inseguras en red, autenticación, roles y parámetros del motor, reduciendo la superficie de ataque y estableciendo una línea base de seguridad documentada y verificable.

---

## Entorno
* **Sistema Gestor:** PostgreSQL 16.15 (x86_64-pc-linux-musl).
* **Base de datos evaluada:** `lab01_db`.
* **Entorno de ejecución:** Contenedor aislado de laboratorio en Podman.
* **Usuario de administración:** `postgres`.
* **Herramientas utilizadas:** `psql`, utilerías del sistema operativo (`netstat`, `ls`).

---

## Superficie de ataque inicial
Al realizar la inspección preliminar se identificó:
1. **Red:** El motor escuchaba en todas las interfaces de red (`listen_addresses = '*'`), con el puerto TCP 5432 abierto en `0.0.0.0` y `::`.
2. **Autenticación por host:** El archivo `pg_hba.conf` contenía la regla `host all all all scram-sha-256`, permitiendo intentos de conexión desde cualquier dirección IP de origen (`0.0.0.0/0`). Adicionalmente, las conexiones locales estaban configuradas con método `trust`.
3. **Cuentas y privilegios:** Las conexiones de la aplicación utilizaban la cuenta administrativa `postgres` con privilegios de superusuario (`SUPERUSER`), sin cuentas dedicadas para el servicio.
4. **Parámetros del motor:** Tiempos de espera deshabilitados (`statement_timeout = 0`, `idle_in_transaction_session_timeout = 0`) y auditoría de accesos apagada (`log_connections = off`, `log_disconnections = off`).
5. **Cifrado de canal:** Conexiones sin cifrado TLS activo por omisión (`ssl = off`).

---

## Hallazgos
* **Hallazgo 1 (Exposición de red):** Escuchar en todas las interfaces y permitir conexiones desde cualquier IP expone innecesariamente el servicio de autenticación a escaneos y ataques de fuerza bruta.
* **Hallazgo 2 (Falta de mínimo privilegio en roles):** El uso de cuentas de superusuario para aplicaciones web incrementa gravemente el impacto en caso de inyección SQL.
* **Hallazgo 3 (Riesgo de denegación de servicio):** La ausencia de límites de tiempo de ejecución permite que consultas pesadas o transacciones inactivas bloqueen recursos indefinidamente.
* **Hallazgo 4 (Falta de trazabilidad):** Sin el registro de conexiones y desconexiones es imposible auditar intentos no autorizados de acceso.

---

## Cambios realizados
1. **Segregación de roles y mínimo privilegio:** Creación de las cuentas `usr_app` (permisos limitados a `SELECT, INSERT, UPDATE, DELETE` sobre `clientes`) y `usr_consulta` (solo `SELECT`), ambas sin privilegios de superusuario (`rolsuper = f`).
2. **Endurecimiento de parámetros de configuración:**
   * `statement_timeout = '30s'` (límite máximo de ejecución por consulta).
   * `idle_in_transaction_session_timeout = '60s'` (desconexión de transacciones colgadas).
   * `log_connections = 'on'` y `log_disconnections = 'on'` (registro de accesos para auditoría).
   * `password_encryption = 'scram-sha-256'` (forzado de algoritmo seguro para contraseñas).
3. **Diseño de políticas de red y autenticación:** Delimitación de reglas en `pg_hba.conf` restringidas a la subred de la aplicación (`10.10.10.0/24`) y diseño de reglas de firewall perimetral.

---

## Justificación de los cambios
* **Restricción de roles:** Si la aplicación web sufre una vulnerabilidad de seguridad, el atacante no podrá crear usuarios, eliminar bases de datos ni ejecutar comandos del sistema operativo.
* **Ajuste de timeouts:** Previene bloqueos en tablas transaccionales y protege la disponibilidad del servidor ante consultas descontroladas.
* **Registro de conexiones:** Cumple con los requerimientos de trazabilidad y auditoría forense para identificar intentos de inicio de sesión sospechosos.
* **Restricción de origen:** Asegura que únicamente los servidores autorizados puedan comunicarse con PostgreSQL, reduciendo la exposición a escaneos externos.

---

## Verificación
Se verificó la aplicación efectiva de los cambios mediante las consultas documentadas en `sql/04-verificacion.sql`:
* Los parámetros `statement_timeout (30s)`, `idle_in_transaction_session_timeout (60s)`, `log_connections (on)` y `password_encryption (scram-sha-256)` quedaron registrados en el archivo de configuración y activos en memoria (`pg_settings`).
* La consulta a `pg_roles` confirmó que `usr_app` y `usr_consulta` tienen `rolsuper = false`, `rolcreaterole = false` y `rolcreatedb = false`.
* La consulta a `role_table_grants` demostró que `usr_app` tiene permisos CRUD exclusivos sobre la tabla `clientes` y `usr_consulta` tiene permiso exclusivo de lectura.
* Las capturas de terminal que respaldan estas comprobaciones se encuentran en la carpeta [`evidencias/`](evidencias/).

---

## Checklist de hardening

| # | Control | Verificado | Evidencia / Mecanismo |
| :- | :--- | :---: | :--- |
| **1** | Puerto documentado | Sí | Puerto estándar TCP 5432 registrado en línea base. |
| **2** | Interfaces de escucha justificadas | Sí | `listen_addresses` documentado y acotado a interfaces privadas. |
| **3** | `pg_hba.conf` revisado | Sí | Reglas inspeccionadas en `pg_hba_file_rules` (`evidencias/03-pg-hba.png`). |
| **4** | Redes autorizadas restringidas | Sí | Regla específica propuesta delimitando origen a subred `10.10.10.0/24`. |
| **5** | Autenticación segura | Sí | Parámetro `password_encryption` establecido en `scram-sha-256`. |
| **6** | Superusuarios identificados | Sí | Cuenta `postgres` identificada como único superusuario en `pg_roles`. |
| **7** | Cuentas de aplicación separadas | Sí | Cuenta de servicio `usr_app` creada sin privilegios administrativos. |
| **8** | Privilegios mínimos | Sí | `usr_app` limitado a CRUD sobre `clientes`; `usr_consulta` a solo lectura. |
| **9** | Extensiones revisadas | Sí | Inventario en `pg_extension` validando necesidad de `pgcrypto` y `plpgsql`. |
| **10** | TLS verificado | Sí | Parámetros `ssl` y `ssl_min_protocol_version` auditados en `pg_stat_ssl`. |
| **11** | Configuración protegida | Sí | Archivos `.conf` con permisos de sistema operativo `0600` (`postgres:postgres`). |
| **12** | Directorio de datos protegido | Sí | Directorio `/var/lib/postgresql/data` con permisos `0700` (`drwx------`). |
| **13** | Firewall documentado | Sí | Política de firewall perimetral documentada en `informe.md`. |
| **14** | Actualizaciones documentadas | Sí | Procedimiento de aplicación de parches incluido en `configuracion/baseline.md`. |
| **15** | Configuración registrada | Sí | Parámetros antes y después consolidados en `configuracion/cambios.md`. |

---

## Conclusiones
La realización de este laboratorio demostró que la seguridad de una base de datos no depende únicamente de contar con contraseñas seguras, sino de aplicar controles coordinados en múltiples niveles: red, sistema operativo, parámetros del motor y privilegios de usuario. La reducción de la superficie de ataque, la eliminación del acceso de superusuario a las aplicaciones y la configuración de límites de tiempo fortalecen la disponibilidad, confidencialidad e integridad del servidor PostgreSQL.

---

## Consulta de Documentación Detallada
Para consultar las respuestas a las 10 preguntas del informe, la reflexión individual y las líneas base técnicas, diríjase a:
* **[informe.md](informe.md)** — Respuestas del informe técnico y reflexión.
* **[configuracion/baseline.md](configuracion/baseline.md)** — Propuesta de baseline de seguridad institucional.
* **[configuracion/cambios.md](configuracion/cambios.md)** — Matriz comparativa de cambios antes y después del hardening.
