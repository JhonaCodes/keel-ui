# F12 — API local de trabajos programados

## Qué es

Un endpoint HTTP en loopback para que schedulers EXTERNOS (cron, keel,
scripts) abran sesiones en un proyecto. El scheduling vive fuera de la app —
esto es el enchufe.

## Contrato

- Base: `http://127.0.0.1:<puerto>` (puerto preferido fijo 47821; si está
  tomado, uno efímero — el actual se ve en Configuración).
- Auth: `Authorization: Bearer <token>` — token persistido, visible y
  regenerable en Configuración → API de trabajos programados.
- `POST /projects/<nombre>/sessions` con `{"prompt": "..."}` → crea una sesión
  NUEVA en ese proyecto, manda el prompt (arranca el workflow por defecto del
  proyecto: un trabajo programado no tiene a nadie que elija otro) y
  responde 202 con `{sessionId}`. 409 si el proyecto no tiene carpeta de
  trabajo; 404 si no existe.
- `GET /sessions/<id>` → `{status, isRunning, costUsd, messages}`.

## Ejemplo cron

```
0 9 * * 1 curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Generá el reporte semanal"}' \
  http://127.0.0.1:47821/projects/reportes/sessions
```

## Las rutas viejas siguen contestando

Cuando una estación pasó a llamarse proyecto y su tarea, sesión, las rutas
acompañaron. Pero esta es la única superficie HTTP de la app: afuera puede
haber un cron escrito hace meses que no tiene por qué enterarse de que acá
adentro cambiamos las palabras.

`POST /stations/<nombre>/tasks` y `GET /tasks/<id>` siguen funcionando, sin
aviso y sin diferencia. Quedan como obsoletas: lo que se documenta y lo que
se escribe nuevo es `/projects` y `/sessions`.

## Límites

- Solo loopback (nunca expuesto a la red).
- Crear la sesión la vuelve la sesión ACTIVA de ese proyecto en la UI.
