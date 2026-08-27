# Tarea 1 - Aplicacion reloj/cronometro booteable
## CE4303 Principios Operativos

**Prof. Luis Barboza Artavia**

Estudiantes:
- Diego Salas Ovares [2023xxxxxx]
- Frederick Obando Solano [2023087683] 

---

## Descripcion breve

Crear un programa de reloj (con funcionalidades de hora, alarama y cronometro) booteable mediante un bootloader; ambos escritos en ensamblador x86. Se implementan dos versiones del ensamblador/codigo fuente para sistemas Legacy (BIOS) y UEFI. Se hacen pruebas de los programas mediante simulaciones de un entorno bare-metal con QEMU y pruebas en hardware fisico de procesadores AMD e Intel x86.

## Estructura del repositorio

```
|-- 
|
|
```

## Requerimientos

- OS: Linux (Ubuntu)
- QEMU + GDB: `sudo apt install qemu-system-x86`
- NASM: `sudo apt install nasm`
- GCC: `sudo apt install gcc`
- Make: `sudo apt install make`

## Compilacion

Los procesos de compilacion y simulacion se automatizan mediante comandos de make.

