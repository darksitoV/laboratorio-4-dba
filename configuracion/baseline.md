# LÍNEA BASE DE SEGURIDAD (SECURITY BASELINE) — POSTGRESQL 16

* **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos  
* **Unidad:** II — Seguridad, privacidad y control de acceso  
* **Tema:** 2.6 Hardening de bases de datos  
* **Organización:** Comercializadora Norte S.A. de C.V.  
* **Estudiante:** Genaro Isaac Cárdenas Soto (@darksitoV)  

---

## 1. Red y Control de Conexiones

| Parámetro / Componente | Configuración Estándar | Justificación Técnica |
| :--- | :--- | :--- |
| **Interfaces de escucha (`listen_addresses`)** | `10.10.10.20, localhost` (o interfaz privada asignada). Evitar `*`. | Limita la exposición del motor a la red interna donde residen las aplicaciones autorizadas, evitando responder en interfaces no deseadas. |
| **Puerto del servicio (`port`)** | `5432` (o puerto no estándar si la política interna lo especifica). | Mantener el puerto documentado y protegido principalmente por capas de red y firewall, sin asumir que cambiarlo constituye seguridad real. |
| **Segmentación y Firewall de Red** | Permitir tráfico TCP únicamente desde el segmento de aplicación (`10.10.10.0/24`) y red administrativa del DBA (`10.10.20.0/24`). Denegar cualquier otro origen. | Bloquea escaneos e intentos de conexión no autorizados antes de que alcancen el proceso de PostgreSQL en el sistema operativo. |
| **Redes en `pg_hba.conf`** | Declarar subredes específicas (ej. `10.10.10.0/24`). Prohibir el uso de `0.0.0.0/0` y `::/0` en entornos con conectividad externa. | Asegura que el motor solo acepte peticiones de autenticación de hosts que pertenezcan a la arquitectura del sistema. |

---

## 2. Autenticación

| Parámetro / Control | Configuración Estándar | Justificación Técnica |
| :--- | :--- | :--- |
| **Método de autenticación (`auth_method`)** | `scram-sha-256` para todas las conexiones remotas por red (`host`). Evitar `trust` y `md5`. | SCRAM-SHA-256 previene ataques de repetición (*replay attacks*) y protege el secreto mediante sal aleatoria y derivación criptográfica no reversible. |
| **Almacenamiento de contraseñas (`password_encryption`)** | `scram-sha-256` | Garantiza que cualquier nueva contraseña establecida en el catálogo `pg_authid` se guarde con el algoritmo más robusto soportado por PostgreSQL 16. |
| **Políticas de contraseñas** | Complejidad mínima: al menos 14 caracteres, combinación de mayúsculas, minúsculas, números y símbolos. Rotación controlada. | Dificulta ataques de diccionario o fuerza bruta en cuentas con acceso a la red. |
| **Cuentas administrativas** | Cuenta `postgres` reservada exclusivamente para tareas de administración, mantenimiento y soporte del DBA. | Queda prohibido asociar la cuenta de superusuario en cadenas de conexión de software o frameworks web. |

---

## 3. Autorización y Gestión de Privilegios

| Parámetro / Control | Configuración Estándar | Justificación Técnica |
| :--- | :--- | :--- |
| **Segregación de roles** | Estructurar al menos tres categorías funcionales: DBA (administración), APP (servicio transaccional) y CONSULTA (reportes de solo lectura). | Aplica el principio de mínimo privilegio impidiendo que una cuenta acumule capacidades innecesarias para su labor. |
| **Permisos de cuenta de aplicación (`usr_app`)** | Permisos limitados a `SELECT`, `INSERT`, `UPDATE`, `DELETE` sobre las tablas operativas de su esquema. Sin `SUPERUSER`, `CREATEROLE`, ni `CREATEDB`. | Si la aplicación sufre una inyección SQL o vulnerabilidad en su código, el atacante no podrá ejecutar comandos de sistema operativo ni alterar la estructura de la base. |
| **Permisos de cuenta de consulta (`usr_consulta`)** | Permisos limitados a `SELECT` en tablas o vistas autorizadas. Sin permisos de modificación de datos ni DDL. | Permite generar reportería o auditorías sin riesgo de alteración o borrado accidental de registros transaccionales. |
| **Permisos sobre esquema `public`** | Revocar permisos predeterminados de creación de objetos (`CREATE`) a roles no administrativos sobre el esquema `public`. | Evita que usuarios normales creen objetos que puedan colisionar o ser utilizados para escalamiento de privilegios. |

---

## 4. Configuración de Parámetros del Motor

| Parámetro | Valor Recomendado | Justificación Técnica |
| :--- | :--- | :--- |
| `max_connections` | Ajustado a la necesidad real del pool de conexiones (ej. `100` a `200`). | Evita la degradación del servidor por sobrecarga de memoria compartida (*shared buffers*) ante picos de concurrencia. |
| `superuser_reserved_connections` | `3` (valor por defecto) | Reserva conexiones para que el administrador pueda ingresar y diagnosticar el motor aun cuando la aplicación sature las conexiones disponibles. |
| `statement_timeout` | `30s` (ajustable por carga analítica). | Cancela automáticamente consultas lentas o bucles que saturen CPU o retengan bloqueos en tablas críticas. |
| `idle_in_transaction_session_timeout` | `60s` | Finaliza sesiones que abren transacciones con `BEGIN` y quedan inactivas, liberando bloqueos y recursos de memoria. |
| `log_connections` | `on` | Registra en la bitácora cada intento exitoso de conexión para efectos de auditoría y trazabilidad. |
| `log_disconnections` | `on` | Registra la desconexión y duración de cada sesión activa en el motor. |
| **Extensiones (`pg_extension`)** | Mantener instaladas únicamente las requeridas por la aplicación (ej. `pgcrypto` para funciones criptográficas). | Reduce la superficie de ataque y simplifica la gestión del catálogo del sistema. |

---

## 5. Permisos y Seguridad a Nivel de Sistema Operativo

| Componente | Configuración Estándar | Justificación Técnica |
| :--- | :--- | :--- |
| **Propietario y Grupo** | `postgres:postgres` en todos los archivos de datos y configuración. | Ningún usuario del sistema operativo fuera de la cuenta de servicio de PostgreSQL debe ser dueño de los archivos. |
| **Directorio de datos (`data_directory`)** | Permisos `0700` (`drwx------`). | Bloquea la lectura y ejecución a cualquier otro usuario local no autorizado dentro del servidor. |
| **Archivos de configuración (`postgresql.conf`, `pg_hba.conf`)** | Permisos `0600` (`-rw-------`). | Impide que usuarios sin privilegios lean parámetros internos, certificados o la topología de autenticación. |

---

## 6. Cifrado

| Control | Configuración Estándar | Justificación Técnica |
| :--- | :--- | :--- |
| **Cifrado en tránsito (TLS)** | Habilitar `ssl = on` con `ssl_min_protocol_version = 'TLSv1.2'` (o `TLSv1.3`). Requerir certificados válidos en clientes mediante `sslmode=verify-full`. | Protege contra la interceptación de tráfico en la red (sniffing) y ataques de hombre en el medio (MitM). |
| **Cifrado en reposo (Columna)** | Uso de extensiones como `pgcrypto` (`pgp_sym_encrypt`) para columnas con datos personales o fiscales (RFC, datos bancarios). | Resguarda la confidencialidad de la información en caso de volcados lógicos o lecturas no autorizadas directas al almacenamiento. |

---

## 7. Mantenimiento y Procedimientos Periódicos

1. **Gestión de Actualizaciones:** Aplicar oportunamente los paquetes de actualización menor de PostgreSQL 16 (ej. 16.1, 16.2...) que resuelven vulnerabilidades de seguridad (*CVEs*).
2. **Revisión Periódica de Cuentas:** Auditar trimestralmente la vista `pg_roles` para revocar cuentas inactivas de exempleados o desarrolladores.
3. **Auditoría de `pg_hba.conf`:** Comprobar que no existan reglas temporales de prueba que hayan quedado abiertas tras ventanas de mantenimiento.
4. **Respaldo de Configuraciones:** Mantener copias de respaldo versionadas de los archivos `postgresql.conf` y `pg_hba.conf` fuera del servidor de base de datos.
