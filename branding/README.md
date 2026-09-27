# Branding

Fuente original: `assets/Transteiner.png` — 1774x887 px (2:1), fondo negro **opaco** `#000000`.

Android recorta los iconos con máscara circular, así que el logo original no
se puede usar directamente: al ser 2:1 pierde los extremos izquierdo y derecho.
Los archivos de esta carpeta son versiones cuadradas con el logo centrado
dentro de la zona segura de cada superficie.

| Archivo | Lienzo | Ancho del logo | Uso |
| --- | --- | --- | --- |
| `logo_icon.png` | 1024x1024 | 560 px (54%) | `flutter_launcher_icons` → `image_path` y `adaptive_icon_foreground`. La zona segura del icono adaptativo es el círculo central de 66/108 dp; con 54% de ancho la diagonal del logo queda justo dentro. |
| `logo_splash_a12.png` | 1152x1152 | 680 px (59%) | `flutter_native_splash` → `android_12.image`. Android 12+ enmascara el icono del splash a un círculo de 240 dp sobre un lienzo de 288 dp. |

El splash de Android 11 y anteriores usa `assets/Transteiner.png` directamente:
ahí la imagen se centra sin recortar, así que el logo ancho se ve completo.

El color de fondo es `#000000` en los dos generadores para que coincida con el
fondo propio del PNG; con `#101010` se notaba el recuadro del logo.

## Regenerar

Tras cambiar el logo o estos archivos:

```sh
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Ojo: `flutter_launcher_icons` reescribe
`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`. Si vuelve a
aparecer un `<inset>` alrededor del `foreground`, quítalo — estos PNG ya traen
el padding incorporado y el inset extra deja el logo demasiado pequeño.

## Regenerar los PNG cuadrados

```powershell
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile((Resolve-Path "assets\Transteiner.png"))
foreach ($cfg in @(@{c=1024;w=560;out="branding\logo_icon.png"}, @{c=1152;w=680;out="branding\logo_splash_a12.png"})) {
  $h = [int][Math]::Round($cfg.w * $src.Height / $src.Width)
  $bmp = New-Object System.Drawing.Bitmap $cfg.c, $cfg.c
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Black)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($src, [int](($cfg.c - $cfg.w)/2), [int](($cfg.c - $h)/2), $cfg.w, $h)
  $g.Dispose(); $bmp.Save((Join-Path $PWD $cfg.out), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
$src.Dispose()
```
