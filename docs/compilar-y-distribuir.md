# Compilar y distribuir Keel

No es un feature: es cómo se produce lo que la gente descarga. Está acá porque
las tres plataformas tienen restricciones distintas y ninguna es obvia, y
porque la mitad de las decisiones de abajo se tomaron después de que algo
fallara.

## Dónde estamos

| Plataforma | Estado | Dónde se compila |
|---|---|---|
| macOS (arm64 + x86_64) | ✅ funciona | la Mac, nativo |
| Linux x86_64 | ✅ funciona | `hp-server`, en contenedor |
| Linux arm64 | ❌ imposible hoy | — |
| Windows x64 | ❌ no compila | — |

Los dos ❌ tienen la **misma** causa, y no es la falta de una máquina.

## La causa: `flutter_local_db` no cubre las tres

El paquete distribuye binarios nativos ya compilados, uno por plataforma. Lo
que trae la versión 1.5.1:

```
macos/    liboffline_first_core_arm64.dylib     ✅
          liboffline_first_core_x86_64.dylib    ✅
linux/    liboffline_first_core.so   → x86-64 y nada más
windows/  la carpeta no existe
```

De ahí salen las dos consecuencias:

- **Linux arm64** compila y después revienta al abrir la base, porque el `.so`
  que se empaqueta es x86-64. Raspberry, servidores ARM, Asahi, las VM ARM
  baratas de cloud: todo eso queda afuera.
- **Windows ni siquiera compila.** El `pubspec.yaml` del paquete **declara**
  `windows:` como plataforma soportada pero no trae la carpeta. Flutter genera
  el registrante de plugins, hace `add_subdirectory` sobre un directorio que
  no existe y CMake muere ahí. Ninguna PC arregla eso.

1.5.1 es la última versión publicada; no hay actualización que lo resuelva.

## macOS

Nativo en la Mac. Universal: un solo binario con las dos arquitecturas.

La vía normal es el script de release, desde la raíz del repo:

```sh
scripts/build_macos_release.sh
```

Antes de tocar nada se puede inspeccionar qué versión produciría:

```sh
scripts/build_macos_release.sh --dry-run
```

El script hace el flujo completo: incrementa versión y build, compila, firma,
verifica la firma y las dos arquitecturas, crea y verifica el DMG, reemplaza
`Keel-latest-macos-universal.dmg` y publica en la carpeta `compiled`:

- `Keel-MAJOR.MINOR.PATCH-macos-universal.dmg`;
- `Keel-latest-macos-universal.dmg`;
- `latest.json`, con versión, build, URL, fecha y SHA-256.

La carpeta se puede cambiar con `--output-dir` o `KEEL_COMPILED_DIR`. La URL
base del manifiesto se cambia con `KEEL_DOWNLOAD_BASE_URL`; por defecto es
`https://jhonacode.com/keel`.

### Regla de versión

`pubspec.yaml` es la fuente única. Cada release automática incrementa el
último número y el build:

```text
1.4.18+41  →  1.4.19+42
1.4.19+41  →  1.5.0+42
```

El patch usa `0..19`; al tocar 20 vuelve a cero e incrementa minor. El major
jamás se incrementa en el script: se modifica manualmente en `pubspec.yaml`.
Si falla la compilación, firma, empaquetado o manifiesto, el script restaura la
versión anterior y no reemplaza los artefactos publicados.
El manifiesto `latest.json` debe publicarse junto al DMG en el canal oficial;
sin ese archivo la app conserva visible su versión, pero no inventa que hay
una actualización.

El comando que sigue queda como referencia para diagnosticar el build sin el
empaquetado automatizado:

```sh
flutter build macos --release --dart-define-from-file=keel_secrets.json
```

**Sin `--obfuscate`, a propósito.** Se probó y se descartó: rompió algo
visible en la UI antes de aportar nada, y el costo real no era el símbolo
renombrado sino que cada stack que llega al canal de errores necesitaba un
`flutter symbolize` manual contra un mapa de 6 MB que había que archivar por
release. Una release compilada AOT ya es código máquina nativo —no hay Dart
que recuperar—, que es bastante más de lo que protege el promedio.

Lo que sí queda expuesto, con o sin obfuscación: **los strings**. La
obfuscación renombra símbolos, nunca literales, porque tocarlos rompería cada
`toString()`. El webhook del canal sale con `strings` en cinco segundos.

**Después de compilar hay que re-firmar.** No es opcional y cuesta caro
descubrirlo: si se corre `flutter build` dos veces seguidas, el segundo
reemplaza el binario de Dart dentro de `App.framework` sin re-firmar el bundle
exterior, y la app queda con la firma rota. Gatekeeper la rechaza aunque el
usuario haga clic derecho → Abrir.

```sh
codesign --force --deep --sign - build/macos/Build/Products/Release/Keel.app
```

Y se verifica mirando el **código de salida**, no la última línea de texto:

```sh
if codesign --verify --deep --strict <app>; then echo OK; else echo ROTA; fi
```

Un `codesign ... | tail -1` devuelve el estado de `tail`, que siempre es 0.
Así se nos pasó una firma inválida una vez.

El `.dmg` se arma con `hdiutil` sobre una carpeta que lleva `Keel.app`, un
enlace a `/Applications`, el `LICENSE.txt` y el `LEEME.txt`.

**Firma ad-hoc, sin notarizar.** `spctl` la rechaza, y es esperable: la
primera apertura tiene que ser clic derecho → Abrir. Notarizar exige una
cuenta de Apple Developer paga. Vale la pena cuando se distribuya en serio:
no impide la ingeniería inversa, pero sí impide que alguien modifique la app
y la reparta firmada como si fuera la original — que es justo lo que dice la
cláusula 4 de los términos.

## Linux

### Por qué no se compila en la Mac

Docker Desktop en Apple Silicon levanta contenedores **arm64**. El `.so` de la
base es **x86-64**. Compilar ahí exige emular amd64 con qemu: funciona, pero
es lento y no hay razón para pagarlo teniendo `hp-server`, que es x86_64
nativo.

### Por qué en un contenedor y no sobre el host

`hp-server` corre Ubuntu 24.04 con **glibc 2.39**. Un binario compilado ahí
exige glibc ≥ 2.39, y eso deja afuera Ubuntu 22.04, Debian 12 y Mint — o sea,
la mayoría de las máquinas reales. Compilando dentro de un contenedor Ubuntu
22.04 el binario pide **glibc 2.34**, que cubre desde Ubuntu 21.10 y RHEL 9
en adelante.

Sigue siendo x86_64 nativo: el contenedor no emula nada, solo fija contra qué
librerías se enlaza.

### Cómo se hace

La imagen (`ubuntu:22.04` + toolchain de Flutter + `libgtk-3-dev`) se
construye una vez y queda cacheada en el server. Después, por cada release:

```sh
rsync -az <fuente> hp-server:~/keel-build/src
ssh hp-server 'docker run --rm \
  -v ~/keel-build/src:/src -v ~/keel-build/out:/out \
  keel-linux-builder:<flutter> bash /build-linux.sh'
```

El script produce `.deb` y `.tar.gz` portable, release plano igual que macOS.

**El runner de `linux/` vive en el repo.** El script NO lo genera: valida que
esté y falla si no. Si lo generara, lo que se publica no sería lo que está
versionado, y el nombre del binario o el app id podrían salir distintos sin
que nadie lo note.

### Lo que hay que verificar del `.deb`

Que compile no alcanza. Cada vez:

```sh
docker run --rm -v ~/keel-build/out:/out ubuntu:22.04 bash -c '
  apt-get update -qq && apt-get install -y /out/keel_*.deb
  ldd /opt/keel/keel | grep "not found"       # tiene que salir vacío
  ls /opt/keel/lib/liboffline_first_core.so'  # la base tiene que viajar
```

Y que `Depends:` diga la glibc que el binario **realmente** pide:

```sh
objdump -T <binario> | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1
```

Declarar de más no es conservador, es un paquete que se niega a instalar
donde habría funcionado. Nos pasó: decía 2.35 cuando pedía 2.34.

## Windows

### Por qué no se puede cross-compilar

No es una limitación que se pueda configurar. Del propio SDK:

```
build_windows.dart:97   'Unable to find suitable Visual Studio toolchain. '
build_windows.dart:199  '-G', generator,     ← generador de Visual Studio
```

Flutter busca MSVC y aborta. Y los contenedores no ayudan: **los contenedores
Windows necesitan un host Windows**, porque comparten kernel con el host.
Docker en macOS o en Linux solo corre contenedores Linux. Ni la Mac ni
`hp-server` pueden producir un `.exe`, con o sin Docker.

### Las dos rutas reales

**GitHub Actions con `windows-latest`** — la recomendada. Runner Windows real
con Visual Studio 2022 preinstalado, sin comprar ni configurar hardware. Un
build tarda ~10 min y el plan gratis da 2000 min/mes en repos privados. El
`.exe` sale como artifact.

**Una VM de Windows en `hp-server`** — también viable: tiene `/dev/kvm`, 8
hilos con virtualización, 15 GB de RAM y 755 GB libres. Se le dan 8 GB y
100 GB a un Windows 11, se instala Visual Studio y se compila ahí. Más setup,
pero no depende de nadie.

Cualquiera de las dos sirve. **Ninguna sirve todavía**, porque el bloqueo es
la base de datos, no la máquina. Un CI que falla en CMake es ruido, no
información.

## El plan para destrabar arm64 y Windows

Hay dos caminos y son excluyentes.

**A. Migrar a sqlite.** `sqlite3` + `sqlite3_flutter_libs` compilan el
amalgamation con CMake en cada plataforma, así que no hay binarios
precompilados que puedan faltar: cualquier arquitectura, incluida Windows y
Linux arm64.

El alcance está contenido a propósito: `local_database.dart` es el único
archivo que importa `flutter_local_db`, y su API estática no cambia, así que
ningún repositorio ni ViewModel se entera. Se borra `key_index.dart` completo
—existe solo para tapar que el paquete no tiene consulta por prefijo— y hace
falta una migración de datos de una sola vez.

De regalo se van tres problemas que ya existen hoy en macOS: la base entera
residente en RAM, el `GetAll` que serializa todo por FFI en cada arranque, y
`replaceAllWithPrefix` sin transacción.

**B. Completar `flutter_local_db`.** El paquete es propio, así que se le puede
agregar lo que falta: el core de Rust compilado para
`x86_64-pc-windows-msvc` (se puede desde Linux con `cargo-xwin`), un shim C++
con su `CMakeLists` en `windows/`, el `.so` de `aarch64` para Linux ARM y, ya
que estamos, consulta por prefijo.

Es más trabajo que A, y después hay que mantener un motor de storage.

Mientras ninguno de los dos esté hecho: macOS y Linux x86_64 funcionan bien y
no hay urgencia. La decisión se toma cuando Windows deje de ser hipotético.

## Secretos y símbolos

**`keel_secrets.json` no está en el repo** (está en `.gitignore`). Lleva el
webhook del canal de errores. Sin ese archivo la app compila igual, solo que
no reporta nada.

Ojo con lo que eso *no* protege: un `--dart-define` termina como **string
plano** dentro del binario y se extrae con `strings` en cinco segundos. La
obfuscación no lo tapa —renombra símbolos, nunca literales, porque tocarlos
rompería cada `toString()`—. Un webhook embebido en un cliente distribuido es
público por definición; lo único que lo arregla de verdad es que el secreto
viva en un servidor.

**No hay símbolos que archivar** mientras no se use `--obfuscate`. Los stacks
que llegan al canal de errores se leen tal cual, sin traducir nada.

## Un bug abierto: los iconos de las sub-ventanas

En una compilación **release**, la ventana principal dibuja todos sus iconos
bien y la sub-ventana del Asistente los dibuja **todos** como el recuadro de
glifo faltante.

Lo que ya se descartó:

- **No es el tree-shaking de iconos.** `MaterialIcons-Regular.otf` pesa
  exactamente 17.852 bytes tanto en una build normal como en una obfuscada:
  byte por byte el mismo archivo. La fuente que usa la ventana que funciona es
  la misma que usa la que falla.
- **No es la obfuscación.** El síntoma aparece igual sin ella.

Lo que el patrón sí señala: cada sub-ventana de `desktop_multi_window` es
**otro engine de Flutter**, y el problema es de ese engine resolviendo el
bundle de assets en release —donde los assets viven dentro de
`App.framework/Resources`— y no del empaquetado.

Es el próximo hilo del que tirar. No está diagnosticado.
