# Tarea 1 - Aplicacion reloj/cronometro booteable
## CE4303 Principios Operativos

**Prof. Luis Barboza Artavia**

Estudiantes:
- Frederick Obando Solano [2023087683]
- Diego Salas Ovares [2023107645]


---

## Descripcion breve

Crear un programa de reloj (con funcionalidades de hora, alarma y cronometro) booteable mediante un bootloader; ambos escritos en ensamblador x86. La estructura contempla versiones para sistemas Legacy (BIOS) y UEFI; actualmente la integracion funcional corresponde a Legacy. Las pruebas se realizan mediante simulaciones de un entorno bare-metal con QEMU y en hardware fisico de procesadores AMD e Intel x86.

## Estructura del repositorio

```
.
|-- Makefile
|-- src
|   |-- legacy
|   |   |-- boot/          # Bootloader BIOS
|   |   |-- clock/         # Reloj, cronometro y alarma
|   |   |   `-- include/   # Constantes de la aplicacion
|   |   `-- utils/         # Lectura de disco y salida basica
|   `-- uefi
|       |-- boot/
|       `-- clock/
`-- build/                 # Binarios generados (ignorado por Git)
```

## Requerimientos

- OS: Linux (Ubuntu)
- QEMU + GDB: `sudo apt install qemu-system-x86`
- NASM: `sudo apt install nasm`
- GCC: `sudo apt install gcc`
- Make: `sudo apt install make`

## Compilacion

Los procesos de compilacion y simulacion se automatizan mediante comandos de make.

- `make`: ensambla la aplicacion Legacy, el bootloader y `build/legacy/disk.img`.
- `make run`: inicia la imagen booteable en QEMU.
- `make test`: genera `build/legacy/reloj.com` para pruebas en DOSBox.
- `make run-test`: ejecuta la version `.COM` en DOSBox.
- `make clean`: elimina los artefactos generados para Legacy.
