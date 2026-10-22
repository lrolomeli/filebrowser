# Netfiles

Gestor de archivos autoalojado basado en
[FileBrowser Quantum](https://filebrowserquantum.com/). Permite navegar,
subir, descargar, crear carpetas, mover, renombrar y eliminar archivos de una
carpeta del host o NAS, además de crear enlaces públicos de solo lectura.

El template anterior de Express/React se eliminó. Sigue disponible en el
historial de git.

## Stack

- **FileBrowser Quantum** `stable-slim` (Go, SQLite, imagen ligera sin FFmpeg).
- **Docker Compose** con un único contenedor.
- Autenticación por usuario/contraseña, un solo administrador y sin registro.
- Subidas grandes por chunks con reanudación.
- Búsqueda indexada.

No incluye papelera, WebDAV ni previews pesadas. El borrado es permanente.

## Estructura

```text
netfiles/
├── deploy.sh
├── README.md
├── .gitignore
└── filebrowser/
    ├── docker-compose.yml
    ├── config.yaml
    ├── .env.example
    ├── .env              # real, no se versiona
    └── data/             # SQLite, índice y caché, no se versiona
```

## Requisitos

- Docker Engine y Docker Compose.
- Una carpeta del host/NAS dedicada a los archivos.
- El UID/GID del contenedor debe poder leer y escribir esa carpeta.

## Configuración

Copia el ejemplo y ajusta los valores:

```bash
cp filebrowser/.env.example filebrowser/.env
```

Edita `filebrowser/.env`:

```env
FILES_HOST_PATH=/mnt/nas/netfiles
ADMIN_PASSWORD=una_contraseña_larga_y_aleatoria
PUID=1000
PGID=1000
```

- `FILES_HOST_PATH`: ruta absoluta de la carpeta de archivos. No uses `/` ni
  `/var`.
- `ADMIN_PASSWORD`: contraseña inicial del usuario `admin`.
- `PUID`/`PGID`: propietario efectivo dentro del contenedor. Deben coincidir
  con el propietario de `FILES_HOST_PATH` y de `filebrowser/data`.

Puedes ajustar el nombre de la instancia, el tamaño mínimo de contraseña y
otras opciones en `filebrowser/config.yaml`. Los cambios de configuración
requieren reiniciar el contenedor.

## Arranque

```bash
./deploy.sh
```

O manualmente:

```bash
docker compose -f filebrowser/docker-compose.yml --env-file filebrowser/.env up -d
```

Accede en:

```text
http://IP_DEL_HOST:8085
```

El usuario es `admin` y la contraseña es la definida en `ADMIN_PASSWORD`.

## Uso

- **Subir:** selecciona o arrastra archivos a la carpeta actual. Los archivos
  grandes se suben por chunks y pueden reanudarse si se interrumpe la
  conexión.
- **Carpetas:** crea, renombra, mueve y elimina desde la interfaz.
- **Descargar:** descarga individual; no se genera ZIP de carpetas.
- **Buscar:** búsqueda indexada por nombre en todo el source.
- **Compartir:** crea enlaces públicos de archivos o carpetas desde la
  interfaz. Para que el enlace sea solo por token, deja vacíos la expiración y
  la contraseña. Los enlaces se pueden revocar.
- **Eliminar:** el borrado es permanente. No hay papelera.

## Enlaces públicos

Los enlaces usan las rutas `/public/` de FileBrowser Quantum y no requieren
sesión. Cualquiera que tenga el enlace puede ver y descargar el recurso
compartido; trátalo como un secreto y revócalo si se filtra.

Si algún día pones la app detrás de un proxy con autenticación, asegúrate de
dejar pasar `/public/` sin autenticación o los enlaces dejarán de funcionar.

## Acceso desde Internet

La configuración incluida es para **LAN o VPN**. No expongas el puerto `8085`
directamente a Internet.

Si necesitas acceso público, añade un reverse proxy con TLS (Caddy, Traefik o
nginx) y:

- Activa `http.trustProxyHeaders: true` en `config.yaml`.
- Define `http.externalUrl` con la URL pública.
- Envía `Host`, `X-Forwarded-For` y `X-Forwarded-Proto`.
- Desactiva el buffering del proxy para subidas/descargas:
  `proxy_buffering off;`.
- Permite cuerpos grandes: `client_max_body_size 0;` o un valor superior al
  tamaño máximo de tus archivos.
- No uses el proxy de Cloudflare para archivos grandes; su límite puede
  rechazar subidas de más de 100 MB según el plan. Usa un túnel directo o un
  proxy sin ese límite.

## Backups

Copia de forma consistente:

- `FILES_HOST_PATH`: los archivos.
- `filebrowser/data`: base de datos, usuarios, enlaces compartidos, índice y
  caché.

El índice se puede reconstruir, pero la base de datos contiene usuarios y
enlaces. Si el NAS tiene snapshots, úsalos junto con un backup de
`filebrowser/data`.

## Actualizaciones

La imagen usa la etiqueta móvil `stable-slim`. Para producción conviene fijar
un digest concreto:

```bash
docker pull ghcr.io/gtsteffaniak/filebrowser:stable-slim
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/gtsteffaniak/filebrowser:stable-slim
```

Sustituye la imagen del compose por `ghcr.io/gtsteffaniak/filebrowser@sha256:...`.

Para actualizar:

```bash
./deploy.sh
```

Revisa las notas de la versión antes de actualizar y haz backup de
`filebrowser/data` y de los archivos.

## Indexación

Quantum indexa el source con SQLite para búsqueda, tamaños de carpeta y
metadatos. La primera indexación de un NAS grande puede tardar minutos y
consumir CPU/IO. Después usa escaneos rápidos y ajusta la frecuencia según la
actividad.

## Problemas comunes

- **No aparecen archivos:** revisa que `FILES_HOST_PATH` exista en el host y
  que el contenedor vea `/files`.
- **Permiso denegado al subir/crear:** ajusta `PUID`/`PGID` y los permisos de
  la carpeta del NAS.
- **Error 413 al subir:** hay un proxy delante con un límite de cuerpo
  demasiado bajo. Ajusta `client_max_body_size`.
- **Enlaces públicos no abren:** el proxy está bloqueando `/public/` o falta
  `http.externalUrl`/`trustProxyHeaders`.
- **Sesión o login raro detrás de proxy:** envía correctamente `Host`,
  `X-Forwarded-Proto` y `X-Forwarded-For`, y activa `trustProxyHeaders`.
- **Logs:**

```bash
docker compose -f filebrowser/docker-compose.yml --env-file filebrowser/.env logs -f
```
