# INFORME TÉCNICO: LABORATORIO 04 — HARDENING Y CONFIGURACIÓN SEGURA DE POSTGRESQL

* **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos  
* **Unidad:** II — Seguridad, privacidad y control de acceso  
* **Tema:** 2.6 Hardening de bases de datos  
* **Motor:** PostgreSQL 16 (Entorno en contenedores)  
* **Estudiante:** Genaro Isaac Cárdenas Soto (@darksitoV)  
* **Organización / Escenario:** Comercializadora Norte S.A. de C.V.  

---

## 1. Introducción y Contexto

El proceso de hardening consiste en reducir la superficie de ataque de un sistema y establecer una configuración segura de operación. En los laboratorios previos se implementaron controles a nivel de datos (clasificación, enmascaramiento, cifrado y políticas de privacidad); sin embargo, una base de datos puede tener permisos bien definidos y seguir estando vulnerable si el servidor escucha en interfaces innecesarias, utiliza métodos de autenticación débiles o permite conexiones desde cualquier origen.

En esta práctica se analizó y fortaleció la configuración de PostgreSQL 16 para la empresa ficticia Comercializadora Norte S.A. de C.V., evaluando la superficie de ataque inicial, aplicando reglas de acceso mínimas, separando cuentas de aplicación y configurando parámetros de protección contra denegación de servicio.

---

## 2. Desarrollo de las Actividades de Hardening

### 2.1 Superficie de Ataque y Archivos de Configuración (Actividades 1 y 2)
Se identificaron los parámetros principales del motor:
* **Versión:** PostgreSQL 16.15 sobre arquitectura x86_64.
* **Puerto:** TCP 5432.
* **Interfaces (`listen_addresses`):** Configurado inicialmente en `*` (todas las interfaces).
* **Archivos clave:**
  * Configuración general: `/var/lib/postgresql/data/postgresql.conf`
  * Control de acceso por host: `/var/lib/postgresql/data/pg_hba.conf`
  * Mapeo de identidades: `/var/lib/postgresql/data/pg_ident.conf`
  * Directorio de datos: `/var/lib/postgresql/data`

*Pregunta Actividad 1:* **¿Por qué conocer la superficie de ataque debe preceder al hardening?**  
Porque no es posible proteger lo que no se conoce. Identificar primero los puertos abiertos, interfaces activas, cuentas existentes y reglas de red permite enfocar los esfuerzos en las vulnerabilidades reales del servidor, evitando aplicar cambios a ciegas que puedan interrumpir la operación o dejar brechas sin atender.

*Pregunta Actividad 2:* **¿Por qué es importante conocer la ubicación física de estos archivos?**  
Para gestionar adecuadamente los permisos del sistema operativo, configurar tareas de respaldo de configuración y asegurar que usuarios no autorizados no puedan modificarlos directamente en disco.

---

### 2.2 Interfaces de Escucha y Red (Actividades 3, 13 y 14)
Al revisar la configuración de red se comprobó que el servidor escuchaba en `0.0.0.0:5432` y `:::5432`.  
* **Análisis de Arquitectura:** En una arquitectura donde el servidor PostgreSQL se ubica directamente expuesto a internet tras un firewall básico, cualquier regla mal configurada expone el puerto a ataques directos. En contraste, colocar el servidor dentro de una red privada (aislado de internet) a la cual solo acceden los servidores de aplicación reduce la superficie de exposición, pues un atacante externo tendría que comprometer primero la capa de aplicación antes de alcanzar la base de datos.

*Tabla de Política de Firewall Conceptual (Actividad 14):*

| Origen | Destino | Puerto | Acción | Justificación |
| :--- | :--- | :--- | :--- | :--- |
| `10.10.10.0/24` (Subred App) | Servidor PostgreSQL (`10.10.10.20`) | 5432 | **Permitir** | Comunicación necesaria para el funcionamiento de los servicios. |
| `10.10.20.0/24` (Red Admin DBA) | Servidor PostgreSQL (`10.10.10.20`) | 5432 | **Permitir** | Conexiones de mantenimiento y administración mediante canales seguros. |
| Cualquier otro origen | Servidor PostgreSQL (`10.10.10.20`) | 5432 | **Denegar** | Bloqueo preventivo de cualquier tráfico no autorizado. |

---

### 2.3 Reglas de Autenticación en `pg_hba.conf` (Actividades 4, 5 y 6)
Al consultar `pg_hba_file_rules`, se detectó la regla:
```text
host    all    all    all    scram-sha-256
```
Esta regla permite que cualquier usuario intente autenticarse a cualquier base de datos desde cualquier dirección IP. Aunque use SCRAM-SHA-256, representa un riesgo innecesario al exponer el proceso de autenticación a intentos de fuerza bruta desde cualquier origen.

*Regla Propuesta con Mínimo Privilegio:*
```text
host    lab01_db    usr_app    10.10.10.0/24    scram-sha-256
```
Esta regla delimita la base de datos específica (`lab01_db`), el usuario autorizado (`usr_app`), la subred de origen (`10.10.10.0/24`) y el método criptográfico más robusto.

---

### 2.4 Cuentas, Roles y Separación de Privilegios (Actividades 8 y 9)
Se identificó que el uso de la cuenta `postgres` como credencial de aplicaciones web representaba un riesgo crítico. Se diseñó la estructura de cuentas segregadas (`sql/02-roles.sql`):

| Cuenta | Propósito | LOGIN | Privilegios Asignados |
| :--- | :--- | :---: | :--- |
| **`postgres`** | Administración del DBA | Sí | SUPERUSER, CREATEROLE, CREATEDB (uso exclusivo del DBA). |
| **`usr_app`** | Conexión de la aplicación | Sí | Sin SUPERUSER. Permisos `SELECT, INSERT, UPDATE, DELETE` solo sobre `clientes`. |
| **`usr_consulta`** | Reportería y consulta | Sí | Sin SUPERUSER. Permiso exclusivo `SELECT` sobre `clientes`. |

---

### 2.5 Parámetros de Control y Protección del Motor (Actividades 10 y 11)
Se ajustaron los parámetros de tiempo límite y registro mediante `ALTER SYSTEM` (`sql/03-configuracion.sql`):
* `statement_timeout = '30s'`: Cancela consultas individuales que superen los 30 segundos, mitigando bloqueos y ataques de saturación de recursos.
* `idle_in_transaction_session_timeout = '60s'`: Desconecta sesiones que dejen transacciones abiertas sin actividad por más de un minuto.
* `log_connections = on` y `log_disconnections = on`: Registra el historial de accesos para auditoría forense.
* `password_encryption = 'scram-sha-256'`: Garantiza que toda nueva contraseña se almacene con cifrado robusto.

---

### 2.6 Permisos del Sistema Operativo (Actividad 12)
Se verificaron los permisos de los archivos en el servidor:
* Directorio de datos (`/var/lib/postgresql/data`): `drwx------` (permisos octales `0700`), propietario `postgres:postgres`.
* Archivos de configuración (`postgresql.conf`, `pg_hba.conf`): `-rw-------` (`0600`), propietario `postgres:postgres`.

*Pregunta Actividad 12:* **¿Por qué no es suficiente proteger PostgreSQL mediante GRANT y REVOKE si cualquier usuario del sistema operativo puede leer archivos sensibles?**  
Porque los controles de PostgreSQL (`GRANT`/`REVOKE`) operan dentro del motor. Si un usuario local tiene permisos de lectura sobre el sistema de archivos, puede leer directamente los archivos `.conf`, extraer certificados TLS o copiar los bloques de datos brutos del directorio `base/`, evadiendo por completo las restricciones lógicas del gestor.

---

## 3. Respuestas a las Preguntas del Informe (Sección 30)

### 1. ¿Cuál era la principal superficie de ataque?
La combinación de escuchar en todas las interfaces de red (`listen_addresses = '*'`), el puerto 5432 accesible sin restricciones de firewall, y la regla en `pg_hba.conf` que permitía conexiones remotas desde cualquier origen (`all / 0.0.0.0/0`).

### 2. ¿Qué configuración representaba el mayor riesgo?
El uso de una cuenta con privilegios administrativos (`SUPERUSER`) para conexiones de la aplicación junto con la regla permisiva `0.0.0.0/0`. Si la aplicación llegara a sufrir una vulnerabilidad como inyección SQL, el atacante obtendría control total sobre la base de datos y la capacidad de ejecutar comandos en el servidor.

### 3. ¿Qué cambio produjo la mayor reducción de exposición?
La restricción combinada de `listen_addresses` y las reglas de `pg_hba.conf`, limitando el acceso exclusivamente a la subred de la aplicación (`10.10.10.0/24`) y creando el usuario `usr_app` con permisos mínimos, eliminando el acceso de superusuario a la aplicación.

### 4. ¿Qué diferencia existe entre firewall y pg_hba.conf?
El **firewall** opera a nivel de red y sistema operativo (capas 3 y 4 del modelo OSI): descarta o permite paquetes TCP basándose en IPs de origen, destino y puertos, antes de que lleguen a PostgreSQL.  
El archivo **`pg_hba.conf`** es un control interno de PostgreSQL (capa de aplicación): se evalúa una vez que la conexión TCP ya fue aceptada por el servidor, verificando la base de datos solicitada, el nombre del usuario y el método de autenticación. Ambos controles son complementarios y deben coexistir.

### 5. ¿Qué diferencia existe entre autenticación y autorización?
* **Autenticación:** Es el proceso de verificar la identidad de quien se conecta (¿quién eres?, verificado mediante contraseña con SCRAM-SHA-256 o certificados).
* **Autorización:** Es el proceso de verificar qué acciones tiene permitidas una identidad ya autenticada (¿qué puedes hacer?, controlado mediante roles y permisos `GRANT`/`REVOKE` sobre tablas o vistas).

### 6. ¿Por qué una cuenta de aplicación no debe ser SUPERUSER?
Porque si la aplicación presenta una falla de seguridad (como SQL Injection) o si sus credenciales son sustraídas de un archivo `.env`, el atacante heredará privilegios de superusuario, pudiendo crear otros usuarios, borrar bases de datos completas, deshabilitar logs o ejecutar comandos del sistema operativo (`COPY ... FROM PROGRAM`).

### 7. ¿Por qué cambiar el puerto de PostgreSQL no constituye hardening suficiente?
Cambiar el puerto (por ejemplo de 5432 a 5433) es únicamente una medida de ofuscación ("seguridad por oscuridad"). Reduce el ruido de escaneos automáticos simples en internet, pero cualquier escaneo de puertos básico (`nmap`) detecta el servicio en segundos. Si no se restringen las redes, la autenticación y los permisos, el servidor sigue siendo igual de vulnerable.

### 8. ¿Por qué listen_addresses='*' puede ser innecesario?
Porque en la mayoría de los casos un servidor de base de datos solo necesita comunicarse con una red interna o privada donde se encuentran los servidores web o de aplicación. Escuchar en `*` expone el servicio a interfaces públicas, de mantenimiento o virtuales que no tienen justificación operativa de acceso a la base de datos.

### 9. ¿Qué papel tiene el sistema operativo en la seguridad de PostgreSQL?
El sistema operativo es la base donde se ejecuta el motor. Si el sistema operativo está mal configurado (permisos permisivos en `/var/lib/postgresql/data`, usuarios locales con acceso a los archivos o falta de parches en el kernel), la seguridad de PostgreSQL queda anulada, ya que un atacante local puede leer los datos directamente del disco sin interactuar con el gestor.

### 10. ¿Qué controles deberían revisarse periódicamente?
1. Las reglas activas en `pg_hba.conf` para corroborar que no existan accesos temporales olvidados.
2. La lista de roles en `pg_roles` para dar de baja cuentas inactivas y validar que no se hayan creado superusuarios no autorizados.
3. Los permisos asignados en tablas críticas (`role_table_grants`).
4. Los registros de conexión y desconexión en los logs del servidor para identificar intentos fallidos de autenticación.
5. La vigencia y configuración de certificados TLS.
6. La aplicación de actualizaciones menores de seguridad de PostgreSQL.

---

## 4. Reflexión Individual (Sección 31)

### Pregunta: ¿Qué cambiarías primero si recibieras la responsabilidad de asegurar un servidor PostgreSQL que ya se encuentra funcionando en producción?

**Respuesta y justificación técnica:**

Si recibiera un servidor PostgreSQL en producción con múltiples deficiencias de seguridad, la primera acción que implementaría sería **restringir el acceso de red en el perímetro (firewall) y auditar las reglas de `pg_hba.conf`**.

**Justificación basada en los criterios analizados:**
1. **Exposición y Riesgo:** El mayor peligro para una base de datos en producción proviene de conexiones no autorizadas originadas fuera del segmento de servidores de aplicación. Si el puerto está abierto a internet o a redes amplias (`0.0.0.0/0`), cualquier atacante puede intentar ataques de fuerza bruta o explotar vulnerabilidades de autenticación.
2. **Impacto y Disponibilidad:** Cambiar inmediatamente la estructura de usuarios (por ejemplo, quitarle privilegios a la cuenta que usa la aplicación web) podría romper la conexión y causar una caída del servicio en producción (*downtime*). En cambio, asegurar que solo las IPs legítimas de los servidores de aplicación puedan alcanzar el puerto 5432 reduce de inmediato la exposición sin alterar el funcionamiento del software.
3. **Continuidad operativa:** Restringir el origen de red a los servidores conocidos garantiza que la aplicación siga operando normalmente mientras se planifica una ventana de mantenimiento para realizar cambios más profundos, como la segregación de roles, la rotación de credenciales y la migración a contraseñas SCRAM-SHA-256.

Una vez contenida la exposición perimetral, la secuencia de atención sería:
* *Fase 1 (Inmediata):* Firewall y `pg_hba.conf` acotados a las IPs del backend.
* *Fase 2 (Corto plazo):* Configuración de timeouts (`statement_timeout`, `idle_in_transaction_session_timeout`) y habilitación de logs de conexión.
* *Fase 3 (Planificada con desarrollo):* Creación de cuenta de servicio específica para la aplicación con privilegios mínimos, eliminando el uso de `SUPERUSER` en la cadena de conexión.

---

## 5. Conclusiones Generales

El desarrollo de este laboratorio permitió comprobar que la seguridad de un servidor de bases de datos requiere un enfoque estructurado en múltiples capas (defensa en profundidad). El hardening no es una acción aislada, sino un conjunto de decisiones técnicas que abarcan la red, el sistema operativo, los parámetros de configuración de PostgreSQL y el control de acceso lógico. Aplicar el principio de mínimo privilegio en cada una de estas capas permite contar con una base de datos estable, protegida y con una superficie de exposición acotada a las necesidades reales del negocio.
