# Tarea 1 - Reloj/cronometro booteable

## CE4303 Principios Operativos

Profesor: Luis Barboza Artavia

Estudiantes:

- Frederick Obando Solano (2023087683)
- Diego Salas Ovares (2023107645)

## Descripcion

El proyecto implementa un reloj con cronometro y alarma en ensamblador x86. Existen dos versiones funcionales e independientes:

- Legacy BIOS: aplicacion de 16 bits cargada desde sectores de una imagen de disquete.
- UEFI x86-64: bootloader PE/COFF que abre una segunda aplicacion EFI y la ejecuta mediante los servicios del firmware.

Ambas versiones muestran la misma interfaz y ofrecen los mismos controles, pero no son el mismo binario. Legacy utiliza interrupciones BIOS; UEFI utiliza protocolos y servicios UEFI con la ABI Microsoft x64.

## Flujo de arranque

Legacy:

```text
BIOS
  -> sector 0: boot.bin (0000:7C00)
  -> lee todos los sectores de app.bin
  -> app.bin (0000:7E00)
  -> reloj / cronometro / alarma
```

UEFI:

```text
Firmware UEFI x86-64
  -> EFI/BOOT/BOOTX64.EFI
  -> abre EFI/CLOCK/CLOCK.EFI desde el mismo volumen FAT32
  -> LoadImage()
  -> StartImage()
  -> reloj / cronometro / alarma
```

El cargador UEFI tambien desactiva el watchdog antes de iniciar el reloj, porque la aplicacion puede permanecer abierta por mas de cinco minutos.

## Estructura principal

```text
.
|-- Makefile
|-- src
|   |-- legacy
|   |   |-- boot/          # Bootloader BIOS de 512 bytes
|   |   |-- clock/         # Aplicacion Legacy de 16 bits
|   |   `-- utils/         # Lectura de disco y salida BIOS
|   `-- uefi
|       |-- boot/          # Primera etapa BOOTX64.EFI
|       `-- clock/         # Segunda etapa CLOCK.EFI
`-- build/                 # Artefactos generados; ignorados por Git
```

## Dependencias

En Ubuntu o Debian:

```bash
sudo apt update
sudo apt install make nasm qemu-system-x86 ovmf lld dosfstools mtools
```

Dependencias opcionales:

```bash
sudo apt install dosbox gdb parted
```

- `dosbox` solo se utiliza para la prueba temporal `.COM` de Legacy.
- `gdb` solo se requiere para los targets de depuracion.
- `parted` solo se requiere para preparar manualmente un USB UEFI con GPT/ESP.
- `lld-link`, instalado por el paquete `lld`, enlaza los ejecutables EFI. GCC y MinGW no son necesarios.

## Controles

Los controles son iguales en Legacy y UEFI:

| Tecla | Accion |
|---|---|
| `Enter` | Iniciar desde la pantalla de bienvenida |
| `M` | Alternar entre reloj y cronometro |
| `Espacio` | Iniciar, pausar o reanudar el cronometro; solo actua en ese modo |
| `R` | Reiniciar el cronometro, incluso si se muestra el reloj |
| `A` | Configurar la alarma; introducir cuatro digitos en formato `HHMM` |
| `Retroceso` | Corregir el ultimo digito durante la configuracion |
| `Esc` | Cancelar la configuracion de la alarma |
| `C` | Desactivar la alarma |
| `Q` | Finalizar |

Al pulsar `Q`, Legacy detiene el procesador y QEMU debe cerrarse manualmente. En UEFI, la aplicacion retorna al bootloader y este retorna al firmware.

## Uso de Legacy BIOS

### Compilar

Desde la raiz del repositorio:

```bash
make MODE=legacy clean all
```

Tambien se puede utilizar solamente `make`, porque `legacy` es el modo predeterminado.

Artefactos:

| Archivo | Funcion |
|---|---|
| `build/legacy/boot.bin` | Sector de arranque BIOS de 512 bytes con firma `55 AA` |
| `build/legacy/app.bin` | Aplicacion plana de 16 bits |
| `build/legacy/disk.img` | Imagen booteable de disquete de 1.44 MiB |

El Makefile calcula automaticamente cuantos sectores ocupa `app.bin` y entrega ese valor al bootloader. Si la aplicacion supera los 17 sectores disponibles en la primera pista, la compilacion falla en vez de crear una imagen truncada.

### Ejecutar en QEMU

```bash
make MODE=legacy run
```

QEMU presenta la imagen como disquete y arranca primero `boot.bin`. Cuando aparezca la bienvenida, presionar `Enter`.

### Prueba auxiliar en DOSBox

```bash
make MODE=legacy test
make MODE=legacy run-test
```

Esto genera y ejecuta `build/legacy/reloj.com`. Sirve para probar la aplicacion con rapidez, pero no prueba el bootloader ni la lectura de sectores; la validacion completa es `make MODE=legacy run`.

### Depuracion

```bash
make MODE=legacy debug
```

QEMU queda detenido antes de ejecutar la primera instruccion y abre el servidor GDB en `localhost:1234`. En otra terminal se puede conectar con `target remote :1234`.

## Uso de UEFI x86-64

### Compilar

```bash
make MODE=uefi clean all
```

Artefactos:

| Archivo | Funcion |
|---|---|
| `build/uefi/bootx64.efi` | Bootloader UEFI de primera etapa |
| `build/uefi/clock.efi` | Aplicacion de reloj de segunda etapa |
| `build/uefi/uefi.img` | Volumen FAT32 booteable de 64 MiB |
| `build/uefi/OVMF_VARS.fd` | Variables UEFI privadas para la ejecucion en QEMU |

La imagen FAT32 contiene:

```text
EFI/BOOT/BOOTX64.EFI
EFI/CLOCK/CLOCK.EFI
```

Se puede comprobar sin arrancarla:

```bash
mdir -i build/uefi/uefi.img ::/EFI/BOOT
mdir -i build/uefi/uefi.img ::/EFI/CLOCK
```

### Ejecutar en QEMU con OVMF

```bash
make MODE=uefi run
```

OVMF carga `BOOTX64.EFI`; el bootloader busca `CLOCK.EFI` en el mismo volumen, reserva memoria, lee el archivo, pide al firmware que cargue el PE/COFF y le transfiere el control. Despues aparece la bienvenida de la aplicacion y se debe presionar `Enter`.

Si OVMF esta instalado en una ruta diferente, se pueden sobreescribir las variables del Makefile:

```bash
make MODE=uefi run \
  OVMF_CODE=/ruta/OVMF_CODE.fd \
  OVMF_VARS_TEMPLATE=/ruta/OVMF_VARS.fd
```

### Depuracion

```bash
make MODE=uefi debug
```

Al igual que en Legacy, QEMU espera una conexion GDB en `localhost:1234`.

## Prueba en hardware real

La escritura de una imagen elimina la tabla de particiones y todos los archivos del dispositivo seleccionado. Hay que comprobar dos veces el nombre, tamano, modelo y que `TRAN` indique `usb`. Nunca se debe usar el disco del sistema.

Se recomienda probar UEFI en hardware real porque es el modo con mayor compatibilidad en equipos modernos. Legacy requiere que el firmware todavia ofrezca BIOS Compatibility Support Module (CSM).

### 1. Identificar el USB

Conectar solamente el USB que se va a utilizar y ejecutar:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,MOUNTPOINTS
```

En los ejemplos siguientes, `/dev/sdX` es un marcador. Debe sustituirse por el dispositivo completo confirmado, por ejemplo `/dev/sdb`; no por una particion como `/dev/sdb1`.

Antes de escribir, desmontar cada particion que aparezca montada:

```bash
sudo umount /dev/sdX1
```

Si hay mas particiones montadas, se desmontan individualmente.

### 2A. Grabar Legacy

Compilar y escribir la imagen:

```bash
make MODE=legacy clean all
sudo dd if=build/legacy/disk.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

Luego:

1. Reiniciar el equipo y abrir el menu de firmware/arranque.
2. Habilitar `Legacy Boot` o `CSM`.
3. Si el firmware lo requiere, desactivar Secure Boot para habilitar CSM.
4. Elegir la entrada del USB que no tenga el prefijo `UEFI`.
5. Presionar `Enter` en la bienvenida.

La imagen Legacy tiene formato de disquete/superfloppy. Algunos equipos modernos no ofrecen CSM o no emulan un USB como disquete; en ellos se debe usar otro equipo para la prueba Legacy o probar UEFI en hardware.

### 2B. Grabar UEFI directamente

```bash
make MODE=uefi clean all
sudo dd if=build/uefi/uefi.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

Luego:

1. Arrancar el equipo en modo UEFI x86-64.
2. Desactivar Secure Boot, ya que los dos ejecutables EFI no estan firmados.
3. Elegir `UEFI: <nombre del USB>`.
4. Verificar que aparece el mensaje del bootloader y despues la bienvenida del reloj.

`uefi.img` es un volumen FAT32 tipo superfloppy. OVMF lo reconoce, pero algunos firmwares fisicos exigen una tabla GPT y una EFI System Partition.

### 2C. USB UEFI con GPT/ESP para firmware exigente

Este procedimiento tambien destruye todo el contenido de `/dev/sdX`:

```bash
sudo parted /dev/sdX --script mklabel gpt
sudo parted /dev/sdX --script mkpart ESP fat32 1MiB 100%
sudo parted /dev/sdX --script set 1 esp on
sudo mkfs.fat -F 32 -n CLOCK_EFI /dev/sdX1
```

Montar la nueva particion y copiar ambas etapas:

```bash
sudo mkdir -p /mnt/clock-uefi
sudo mount /dev/sdX1 /mnt/clock-uefi
sudo mkdir -p /mnt/clock-uefi/EFI/BOOT
sudo mkdir -p /mnt/clock-uefi/EFI/CLOCK
sudo cp build/uefi/bootx64.efi /mnt/clock-uefi/EFI/BOOT/BOOTX64.EFI
sudo cp build/uefi/clock.efi /mnt/clock-uefi/EFI/CLOCK/CLOCK.EFI
sync
sudo umount /mnt/clock-uefi
```

No se debe omitir `CLOCK.EFI`: `BOOTX64.EFI` es el cargador y necesita encontrar la segunda etapa en `EFI/CLOCK/CLOCK.EFI`.

## Diferencias de implementacion

| Aspecto | Legacy | UEFI |
|---|---|---|
| Arquitectura | x86 real mode, 16 bits | x86-64 |
| Formato | Binario plano | PE/COFF EFI application |
| Entrada de teclado | BIOS `INT 16h` | `EFI_SIMPLE_TEXT_INPUT_PROTOCOL` |
| Salida de texto | BIOS `INT 10h` | `EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL` |
| Hora real | BIOS `INT 1Ah`, valores BCD | `EFI_RUNTIME_SERVICES.GetTime()`, valores binarios |
| Cronometro | Ticks BIOS | Eventos/timer de UEFI |
| Carga de la aplicacion | BIOS `INT 13h`, sectores CHS | Simple File System + `LoadImage()` + `StartImage()` |

La logica visible puede mantenerse equivalente, pero el mismo `app.bin` Legacy no se puede ejecutar bajo UEFI y `CLOCK.EFI` no se puede saltar desde real mode. Por eso el repositorio conserva implementaciones separadas bajo `src/legacy/clock` y `src/uefi/clock`.

## Limpieza

Cada modo limpia solo su propia carpeta de salida:

```bash
make MODE=legacy clean
make MODE=uefi clean
```
