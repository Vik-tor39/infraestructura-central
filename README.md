# 🏗️ Infraestructura Central — Plataforma Integrada

Repositorio de infraestructura compartida para el proyecto de curso de **Desarrollo de Software Seguro (UDLA)**. Provee los servicios de identidad, autenticación y gestión de llaves criptográficas que consumen los subsistemas del ecosistema.

---

## 📐 Arquitectura General

```
┌────────────────────────── INFRAESTRUCTURA ──────────────────────────────┐
│   Keycloak (8080) ──federates── OpenLDAP (389)                         │
│   PostgreSQL (5432, interno) ←── Base de datos de Keycloak             │
│   Vault (8200) — Motor Transit, clave: clickloker-key                  │
└────────────────────────────────────────────────────────────────────────┘
          │ OIDC / JWKS                  │ KMS (cifrado/descifrado)
          ▼                              ▼
  ┌───────────────┐            ┌──────────────────┐
  │   Sistema A   │─payload───▶│    Sistema B     │
  │  Activity     │  cifrado   │   ClickLoker     │
  │  Monitor      │            │   (3000 / 5173)  │
  │  (3001/3002)  │            └──────────────────┘
  └───────────────┘
```

### Repositorios del ecosistema

| Directorio hermano | Sistema | Descripción |
|--------------------|---------|-------------|
| `infraestructura/` *(este repo)* | Central | Keycloak · OpenLDAP · Vault · PostgreSQL |
| `DesarolloDelSoftwareSeguroAppApuestas/` | Sistema B "ClickLoker" | Registro de eventos de clic — Node.js/Express + React + Supabase + Redis |
| `activity-monitor/` | Sistema A "Monitor de actividades" | Dashboard que consume datos del Sistema B — Node.js/Express + React |

---

## 🐳 Servicios Docker

| Servicio | Imagen | Puerto(s) | Función |
|----------|--------|-----------|---------|
| **OpenLDAP** | `osixia/openldap:1.5.0` | `389` / `636` | Directorio de usuarios (dominio: `plataforma.local`) |
| **phpLDAPadmin** | `osixia/phpldapadmin:0.9.0` | `8090` | Interfaz web para gestionar OpenLDAP |
| **Keycloak** | `quay.io/keycloak/keycloak:24.0.1` | `8080` | SSO / Broker OIDC (realm: `plataforma-integrada`) |
| **PostgreSQL** | `postgres:15` | `5432` *(interno)* | Base de datos de Keycloak |
| **Vault** | `hashicorp/vault:1.16` | `8200` | KMS — Motor Transit para cifrado entre sistemas |
| **Vault Init** | `hashicorp/vault:1.16` | — | Contenedor de un solo uso: habilita Transit y crea las claves al levantar el stack (ver sección 3) |

---

## ✅ Prerrequisitos

| Herramienta | Versión mínima | Verificar con |
|-------------|---------------|---------------|
| [Docker](https://docs.docker.com/get-docker/) | 24+ | `docker --version` |
| [Docker Compose](https://docs.docker.com/compose/) | v2+ | `docker compose version` |
| Git | cualquiera | `git --version` |
| bash / Git Bash | — | Requerido solo para el fallback manual `init-vault.sh` en Windows |

> **Windows**: se recomienda usar **Git Bash** o **WSL2** para ejecutar el script `.sh`.

---

## 🚀 Clonación y Levantamiento

### 1. Clonar el repositorio

```bash
git clone <URL-DEL-REPO> infraestructura
cd infraestructura
```

### 2. Levantar todos los servicios

```bash
docker compose up --build
```

> Para ejecutarlo en segundo plano (modo *detached*):
> ```bash
> docker compose up -d
> ```

Docker descargará las imágenes necesarias en el primer arranque. El proceso puede tardar unos minutos.

### 3. Inicialización de Vault (automática)

Vault corre en **modo dev** — su estado es en memoria y se pierde al reiniciar el contenedor. Para no depender de un paso manual, el `docker-compose.yml` incluye:

- Un **healthcheck** en el servicio `vault` (`vault status`) que marca el contenedor como `healthy` recién cuando la API responde.
- Un servicio **`vault-init`** (contenedor de un solo uso, `hashicorp/vault:1.16`) que espera a que `vault` esté `healthy` y ejecuta `vault-auto-init.sh`, el cual habilita el **motor Transit** y crea las claves `clickloker-key` y `plataforma-key`. Es idempotente: si ya existen, no falla ni las rota.

Al correr `docker compose up` (o `up -d`), esto pasa solo — no hace falta ningún paso adicional. Puedes confirmarlo con:

```bash
docker compose ps -a
# vault      → Up (healthy)
# vault-init → Exited (0)   ← es el estado esperado, no un error

docker logs vault-init
```

> **Fallback manual**: `vault-init` solo se dispara cuando Compose levanta el stack. Si el contenedor `vault` se reinicia por su cuenta (crash, `docker restart vault`, etc.) sin volver a correr `docker compose up`, las claves se pierden igual y no se recrean solas. En ese caso, ejecuta manualmente:
> ```bash
> bash init-vault.sh
> ```

### 4. Verificar que todo está en pie

```bash
docker compose ps
```

Todos los servicios deben aparecer en estado `running` / `Up`.

---

## 🌐 Acceso a las Interfaces

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Keycloak Admin | <http://localhost:8080> | `admin` / `admin_keycloak` |
| phpLDAPadmin | <http://localhost:8090> | Login DN: `cn=admin,dc=plataforma,dc=local` / `admin_ldap` |
| Vault UI | <http://localhost:8200/ui> | Token: `vault_root_token` |

---

## 🔑 Credenciales por Defecto *(solo entorno de desarrollo)*

> ⚠️ Estas credenciales son exclusivamente para desarrollo/pruebas locales. **No usar en producción.**

| Servicio | Usuario / DN | Contraseña / Token |
|----------|--------------|--------------------|
| OpenLDAP | `cn=admin,dc=plataforma,dc=local` | `admin_ldap` |
| Keycloak | `admin` | `admin_keycloak` |
| PostgreSQL | `keycloak` | `keycloak_pass` |
| Vault | — | `vault_root_token` |

---

## ⚙️ Variables de Entorno para Subsistemas

Los subsistemas (`Sistema A` y `Sistema B`) deben configurar las siguientes variables de entorno para conectarse a esta infraestructura:

```dotenv
# ── Keycloak ──────────────────────────────────────
KEYCLOAK_URL=http://<IP-CENTRAL>:8080
KEYCLOAK_REALM=plataforma-integrada
KEYCLOAK_CLIENT_ID=sistema-a        # o sistema-b según corresponda

# ── Vault ─────────────────────────────────────────
VAULT_ADDR=http://<IP-CENTRAL>:8200
VAULT_TOKEN=vault_root_token
VAULT_TRANSIT_KEY=clickloker-key
```

> Reemplaza `<IP-CENTRAL>` con la IP del host donde corre este `docker compose`.  
> Dentro de una red Docker compartida, se puede usar el nombre del servicio directamente.

---

## 🔄 Flujos de Seguridad

### Flujo de Autenticación (OIDC)

```
Usuario ──→ Sistema A o B ──→ Keycloak (login)
                                    │
                                    │ Emite JWT
                                    ▼
                            Sistema valida JWT
                            usando endpoint JWKS:
                            /realms/plataforma-integrada
                              /protocol/openid-connect/certs
```

### Flujo de Cifrado (KMS con Vault)

```
Sistema A                          Sistema B
   │                                   │
   │ 1. Cifra payload con              │
   │    Vault Transit (clickloker-key) │
   │                                   │
   │ 2. POST /api/integration/receive  │
   │──────────────────────────────────▶│
   │                                   │
   │                3. Descifra payload│
   │                   con Vault       │
   │                   Transit         │
```

---

## 🛑 Detener los Servicios

```bash
# Detener y eliminar contenedores (conserva volúmenes)
docker compose down

# Detener, eliminar contenedores y también los volúmenes (reseteo completo)
docker compose down -v
```

---

## 📝 Notas de Diseño

| Componente | Modo | Implicación |
|------------|------|-------------|
| **Vault** | `dev` | Estado en memoria — se pierde al reiniciar el contenedor. `docker compose up` lo re-inicializa solo vía el servicio `vault-init` (healthcheck + auto-init); si `vault` se reinicia por fuera de Compose, ejecutar `init-vault.sh` a mano. |
| **Keycloak** | `start-dev` | Sin TLS en este capa — solo para uso local/LAN. |
| **OpenLDAP** | Federación opcional | Los usuarios también pueden gestionarse directamente en la UI de Keycloak. |
| **PostgreSQL** | Solo accesible internamente | No expone puerto al host — solo accesible desde `infra-net`. |

---

## 📁 Estructura del Repositorio

```
infraestructura/
├── docker-compose.yml     # Definición de todos los servicios (incluye vault-init)
├── vault-auto-init.sh     # Ejecutado por el servicio "vault-init" en cada `docker compose up`
├── init-vault.sh          # Fallback manual si Vault se reinicia fuera de Compose
└── README.md              # Este archivo
```

---

## 🤝 Contribución

Este repositorio forma parte del proyecto de curso y es mantenido por el equipo de infraestructura. Para cambios, abrir un _Pull Request_ con una descripción clara de la modificación y su justificación de seguridad.
