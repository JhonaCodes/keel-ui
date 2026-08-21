# F0 — Fundación multi-ventana

## Qué es

Infraestructura para que la app abra ventanas OS adicionales (engines Flutter
separados) sin duplicar estado pesado, y para que la ventana principal pueda
EMPUJAR method calls hacia una sub-ventana.

## Problema que corrige

`main()` corría `LocalDatabase.ensureInitialized`, la migración legacy,
`seedKeelAi` y el arranque de los DOS servidores MCP locales ANTES del switch
por `businessId`: cada sub-ventana (otro engine) duplicaba el handle LMDB, el
seed y dos servidores HTTP respaldados por ViewModels vacíos.

## Cambios

- `lib/main.dart` — la init pesada vive DENTRO del caso `idMain`. Las
  sub-ventanas solo inicializan bindings + window_manager.
- `lib/src/core/services/app_window_service.dart`:
  - `openAppWindow` ahora RETORNA el `WindowController` y lo registra por
    `businessId` (antes lo descartaba — era el único vehículo de push
    main→sub).
  - `openOrFocusAppWindow(args)` — garantiza una sola ventana viva por
    `businessId` (si existe, `show()`).
  - `liveWindowController(businessId)` — valida contra
    `WindowController.getAll()` (0.3.0 no tiene callback de cierre) y
    RE-ADOPTA ventanas vivas tras un hot-restart de main escaneando sus
    launch arguments.
  - `invokeOnWindow(businessId, method, args)` — push tolerante a ventana
    muerta (limpia el registro y devuelve false, nunca lanza).

## Límites conocidos

- El canal por ventana es FIFO pero sin garantía de entrega: quien pushea
  debe tratar `false` como "nadie escucha", no como error.
