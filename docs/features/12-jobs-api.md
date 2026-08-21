# F12 — API local de trabajos programados

## Qué es

Un endpoint HTTP en loopback para que schedulers EXTERNOS (cron, keel,
scripts) abran tareas en una estación. El scheduling vive fuera de la app —
esto es el enchufe.

## Contrato

- Base: `http://127.0.0.1:<puerto>` (puerto preferido fijo 47821; si está
  tomado, uno efímero — el actual se ve en Configuración).
- Auth: `Authorization: Bearer <token>` — token persistido, visible y
  regenerable en Configuración → API de trabajos programados.
- `POST /stations/<nombre>/tasks` con `{"prompt": "..."}` → crea una tarea
  NUEVA en esa estación, manda el prompt (el workflow activo arranca) y
  responde 202 con `{taskId}`. 409 si la estación no tiene carpeta de
  trabajo; 404 si no existe.
- `GET /tasks/<id>` → `{status, isRunning, costUsd, messages}`.

## Ejemplo cron

```
0 9 * * 1 curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Generá el reporte semanal"}' \
  http://127.0.0.1:47821/stations/reportes/tasks
```

## Límites

- Solo loopback (nunca expuesto a la red).
- Crear la tarea la vuelve la tarea ACTIVA de esa estación en la UI.
