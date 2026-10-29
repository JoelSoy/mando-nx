# Instalación

Todo lo que hace falta para jugar con el teléfono como mando, desde cero. Se hace una sola vez por Mac (los pasos 1–4) y una vez por juego (el paso 5).

- [1. Herramientas del Mac](#1-herramientas-del-mac)
- [2. Este repositorio](#2-este-repositorio)
- [3. nxnative con el parche](#3-nxnative-con-el-parche)
- [4. Las herramientas de nxnative](#4-las-herramientas-de-nxnative)
- [5. Empacar tu juego](#5-empacar-tu-juego)
- [6. Compilar el host Wi‑Fi](#6-compilar-el-host-wifi)
- [7. Instalar la app en el iPhone](#7-instalar-la-app-en-el-iphone)
- [8. Android](#8-android)
- [9. Comprobar que todo funciona](#9-comprobar-que-todo-funciona)
- [Qué hace cada script](#qué-hace-cada-script)

## 1. Herramientas del Mac

- Un Mac con **Apple silicon** (M1 o posterior), **macOS 26.6** o posterior.
- **Xcode 27.1** (nxnative prueba sus shaders con ese compilador), abierto una vez para aceptar la licencia.
- [Homebrew](https://brew.sh) y **Python 3.12** o posterior.
- **Flutter 3.47** o posterior: `brew install --cask flutter`. Comprueba con `flutter doctor` que la parte de iOS (Xcode) está en verde.

## 2. Este repositorio

```bash
cd ~/Dev
git clone https://github.com/JoelSoy/mando-nx.git
cd mando-nx
```

## 3. nxnative con el parche

```bash
scripts/setup_nxnative.sh                 # nxnative en ../nxnative (al lado de este repositorio)
scripts/setup_nxnative.sh --dir ~/otro/nxnative   # o en otra carpeta
```

El script:

1. clona [nxnative](https://github.com/seedds/nxnative) si la carpeta no existe y crea la rama `mando-nx` en el commit probado (`host/NXNATIVE_COMMIT`);
2. aplica `host/nxnative.patch`, o te avisa si ya estaba aplicado;
3. enlaza la app como `dm/remote_pad` dentro de nxnative, que es donde la buscan sus documentos y tests;
4. guarda la carpeta en `~/Library/Application Support/mando-nx/config` para los demás scripts.

Nunca reinicia un nxnative que ya tengas. Si está en otro commit y el parche no aplica, se detiene y te dice qué hacer.

## 4. Las herramientas de nxnative

Esto se hace una vez por Mac (es el paso 1 del README de nxnative):

```bash
xcodebuild -downloadComponent MetalToolchain
brew install xcodegen zstd glslang
brew install --cask dotnet-sdk
python3 -m pip install lz4 capstone fonttools "backports.zstd; python_version < '3.14'"
```

## 5. Empacar tu juego

Pon en una carpeta **tus** archivos del juego: el NSP base y, si los tienes, la actualización y los DLC. Luego ejecuta el script de nxnative con tu `prod.keys`:

```bash
python3 ../nxnative/scripts/build_ipa_from_nsp.py ~/Games/MarioKart -k ~/keys/prod.keys
```

La primera vez tarda entre 30 y 60 minutos. Junto a los NSP queda la carpeta **`<title ID>_build/`** (Mario Kart 8 Deluxe: `0100152000022000_build/`). Contiene el código del juego ya reescrito, la RomFS, los shaders para Metal y las fuentes, y es lo que usa el host del Mac. Los archivos del juego se quedan en esa carpeta: **nunca los pongas en este repositorio ni en nxnative**.

## 6. Compilar el host Wi‑Fi

```bash
scripts/build_host.sh --build ~/Games/MarioKart/0100152000022000_build --test
```

- Compila el host de nxnative con el parche para ese juego y lo deja en `<build>/tools/dmhost-wifi`. El `tools/dmhost` original no se toca, y el `dmhost-wifi` anterior queda como `dmhost-wifi.prev`.
- `--test` corre además los tests del host: el protocolo, las sesiones, el teclado, y UDP real por loopback.
- Guarda la carpeta del juego, así `play_wifi.command` la encuentra solo.
- No hace nada si el juego está abierto, porque reemplazar un programa en marcha puede cerrarlo de golpe.

**El juego no se recompila.** Cuando cambia el host (este parche o un nxnative nuevo), basta con volver a correr este paso.

## 7. Instalar la app en el iPhone

1. Inicia sesión con tu Apple ID en **Xcode → Settings → Accounts**. Sirve una cuenta gratuita.
2. Conecta el iPhone por cable, desbloquéalo y toca **Confiar**. Activa **Ajustes → Privacidad y seguridad → Modo de desarrollador** (el iPhone se reinicia).
3. Ejecuta:

```bash
scripts/install_ios.sh                       # usa el equipo de tu certificado "Apple Development"
scripts/install_ios.sh --team ABCDE12345     # o di cuál
scripts/install_ios.sh --bundle-id com.tunombre.mandonx   # si org.nxnative.remotePad ya está tomado
```

El script hace lo siguiente:
- Guarda tu equipo (y el bundle ID, si lo das) en `app/ios/Flutter/Signing.xcconfig`, que git ignora: tu Team ID nunca se sube.
- Compila la app en release, la instala en el iPhone conectado y la abre.

Ten en cuenta:
- Si iOS no la abre, ve a **Ajustes → General → VPN y gestión de dispositivos** y confía en tu cuenta de desarrollador.
- **Con una cuenta gratuita, la app funciona 7 días.** Después se vuelve a correr el mismo comando, sin perder los ajustes de la app.
- La primera vez que conectes, iOS pide permiso de **Red local**: hay que aceptarlo. La cámara solo se pide para escanear el QR.

También se puede instalar desde Xcode. Abre `app/ios/Runner.xcworkspace` y elige tu equipo en **Signing & Capabilities**. Mejor ponlo en `Signing.xcconfig` (copia `Signing.xcconfig.example`), así no queda escrito en el proyecto.

## 8. Android

Sin probar en un teléfono real:

```bash
cd app && flutter build apk --debug && flutter install    # o: adb install build/app/outputs/flutter-apk/app-debug.apk
```

La primera compilación descarga Gradle y paquetes de Android.

## 9. Comprobar que todo funciona

```bash
scripts/check.sh          # app: analyze + tests; host: tests y que el parche aplica al commit fijado
scripts/smoke_host.sh     # el juego real, sin ventana, con 3 teléfonos simulados (cierra el juego antes)
```

Después, a jugar: [jugar.md](jugar.md).

## Qué hace cada script

| Script | Qué hace |
|---|---|
| `scripts/setup_nxnative.sh` | Clona nxnative en el commit probado, aplica el parche, enlaza la app, guarda la carpeta |
| `scripts/build_host.sh` | Compila el host Wi‑Fi para un juego y lo deja en `<build>/tools/dmhost-wifi` (`--test`: tests del host) |
| `scripts/play_wifi.command` | Lanza el juego con los mandos Wi‑Fi y la ventana del QR (doble clic en Finder) |
| `scripts/install_ios.sh` | Firma con tu equipo, compila, instala y abre la app en el iPhone conectado |
| `scripts/check.sh` | Las comprobaciones antes de un commit |
| `scripts/smoke_host.sh` | Prueba el host con el juego real y teléfonos simulados |
| `scripts/export_patch.sh` | Para desarrollo: regenera `host/nxnative.patch` desde tu nxnative modificado |

Los scripts guardan sus ajustes en `~/Library/Application Support/mando-nx/config`. El código de emparejamiento está en `~/Library/Application Support/nxnative/wifi_pair_code` y las teclas del teclado en `~/Library/Application Support/nxnative/keyboard.txt`.
