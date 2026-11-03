# REGISTRO DE CAMBIOS Y COMPARACIÓN DE CONFIGURACIÓN (LÍNEA BASE)

* **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos  
* **Unidad:** II — Seguridad, privacidad y control de acceso  
* **Tema:** 2.6 Hardening de bases de datos  
* **Organización:** Comercializadora Norte S.A. de C.V.  
* **Estudiante:** Genaro Isaac Cárdenas Soto (@darksitoV)  

---

## 1. Tabla Comparativa de Estado: Antes y Después del Hardening

| Control | Estado Antes del Hardening | Estado Después del Hardening | Justificación Técnica del Cambio |
| :--- | :--- | :--- | :--- |
| **`listen_addresses`** | Configurado en `*` (escuchando en todas las interfaces de red físicas y virtuales disponibles en el host). | Restringido a interfaces privadas específicas (`10.10.10.20, localhost`). | Evita que el servicio responda peticiones en interfaces públicas o no deseadas, reduciendo la exposición de red. |
| **`pg_hba.conf`** | Reglas genéricas (`host all all all scram-sha-256`) y reglas locales con método `trust`. | Reglas específicas acotadas: base de datos, usuario específico, subred privada (`10.10.10.0/24`) y método `scram-sha-256`. | Impide que clientes fuera del segmento de aplicación intenten autenticarse y elimina el acceso confiado sin contraseña. |
| **Método de autenticación** | Coexistencia de `trust` en conexiones locales y posibilidad de métodos heredados. | Estandarizado en `scram-sha-256` para toda conexión remota y contraseña de usuario. | Protege el intercambio de credenciales contra ataques de repetición y fuerza bruta mediante sal criptográfica robusta. |
| **Usuarios administrativos** | Uso de la cuenta `postgres` para tareas generales y pruebas de conexión de servicios. | Uso exclusivo de `postgres` para tareas de mantenimiento del DBA. Bloqueo de uso en aplicaciones externas. | Reduce el impacto de un posible compromiso de credenciales de una aplicación web, evitando acceso total al motor. |
| **Cuentas de aplicación** | Ausencia de segregación formal; la aplicación operaba con cuentas de privilegios elevados. | Creación de cuentas dedicadas (`usr_app` con CRUD sobre `clientes` y `usr_consulta` con solo `SELECT`), sin `SUPERUSER`. | Cumple con el principio de mínimo privilegio: si la aplicación es vulnerada, el atacante no puede alterar otras tablas ni el motor. |
| **Puerto (`port`)** | Puerto estándar `5432` expuesto hacia redes amplias. | Puerto `5432` documentado y filtrado mediante reglas de firewall en el perímetro. | Se mantiene el puerto estándar bajo control formal, comprendiendo que el filtrado de red es la medida de protección efectiva. |
| **TLS (`ssl`)** | Deshabilitado por omisión (`ssl = off`). | Habilitado (`ssl = on`), requiriendo TLS 1.2 o superior (`ssl_min_protocol_version = TLSv1.2`). | Cifra el canal de comunicación en tránsito, garantizando confidencialidad e integridad frente a intercepciones en la red. |
| **Permisos SO** | Permisos del directorio y archivos de configuración sin auditar formalmente. | Verificados y documentados en `0700` para `data_directory` y `0600` para archivos `.conf`, con propietario `postgres:postgres`. | Impide que otros usuarios locales del servidor puedan leer archivos de configuración, certificados o tablas en disco. |
| **Extensiones** | Extensiones instaladas sin inventario de necesidad operativa. | Inventario auditado; se mantiene únicamente `pgcrypto` por requerimientos de cifrado y `plpgsql` nativa. | Evita mantener código externo o funcionalidades adicionales que no aporten valor a la operación y amplíen la superficie de riesgo. |
| **Conexiones y Límites** | `statement_timeout = 0` (sin límite), `idle_in_transaction_session_timeout = 0`, logs de conexión apagados. | `statement_timeout = 30s`, `idle_in_transaction_session_timeout = 60s`, `log_connections = on`, `log_disconnections = on`. | Protege contra denegación de servicio (DoS) por consultas descontroladas, transacciones colgadas y proporciona trazabilidad en logs. |

---

## 2. Resumen del Impacto Técnico

La aplicación de estos cambios permitió transformar una instalación predeterminada de PostgreSQL en una instancia con **superficie de ataque reducida y controlada**:
1. **En la capa de red:** Se eliminó la exposición indiscriminada mediante interfaces específicas y reglas de firewall.
2. **En la capa de autenticación y acceso:** Se establecieron métodos criptográficos modernos (`scram-sha-256`) y se erradicó el método `trust`.
3. **En la capa de roles:** Se implementó la separación entre el DBA y las aplicaciones, limitando los permisos a lo estrictamente indispensable.
4. **En la capa de configuración:** Se establecieron límites de tiempo que previenen bloqueos y se habilitó la auditoría de conexiones.
