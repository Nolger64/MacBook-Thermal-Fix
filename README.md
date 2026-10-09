# MacBook Pro T2 (Linux) - Solución Definitiva de Throttling Térmico

Este repositorio contiene la automatización de la configuración térmica para MacBooks con chip T2 (especialmente la MacBook Pro 13" 2019) ejecutando Arch Linux o distribuciones similares.

## 📌 ¿Por qué existe esto? (El Problema)
En macOS, Apple permite que el procesador alcance los 95°C-99°C antes de reducir el rendimiento (throttling). En Linux, intervienen tres capas conflictivas:
1. **Hardware (Chip T2):** Detecta calor en el chasis y lanza la señal `PROCHOT`, bajando la CPU a 800 MHz.
2. **Kernel Linux:** Bloquea los registros de voltaje y energía (MSR) por seguridad.
3. **Demonios de Linux (`power-profiles-daemon`, `thermald`):** Sobrescriben las frecuencias constantemente, causando picos de 4.2GHz que duran solo 1 segundo y luego caen a 2.8GHz.

## 🛠️ ¿Qué hace este script? (La Solución)
El script de instalación `install.sh` resuelve esta guerra de software automatizando todo el proceso:

1. **Destruye a los demonios conflictivos:** Desactiva `auto-cpufreq`, `power-profiles-daemon` y `thermald`.
2. **Desbloquea el Kernel:** Añade `msr.allow_writes=on` a tu gestor de arranque (systemd-boot o GRUB) para permitir modificaciones térmicas.
3. **Domestica al Chip T2:** Configura el demonio `throttled` para ignorar la señal de emergencia `BDPROCHOT` del chasis y eleva el umbral de estrangulamiento a **95°C**, replicando el comportamiento nativo de macOS.
4. **Crea Perfiles de Rendimiento Visuales para KDE:** Instala dos "aplicaciones" (Modo Turbo y Modo Silencio) que no piden contraseña gracias a una regla de Polkit/sudoers.
5. **Control Dinámico de Ventiladores:** Configura `t2fanrd` para alternar entre una curva agresiva (para disipar rápido en Modo Turbo) y una curva silenciosa (para paz mental en Modo Silencio).

## 🚀 Instrucciones de Uso

### Instalación (Primera vez o tras formatear)
1. Abre una terminal en esta carpeta.
2. Ejecuta el instalador:
   ```bash
   ./install.sh
   ```
3. Lee los avisos en verde/rojo que soltará el instalador. Te avisará si te falta instalar alguna dependencia como `throttled`.
4. **¡REINICIA TU MAC!** (Fundamental para cargar el permiso MSR del kernel).

### Cómo usar los Modos (Día a Día)
Tras ejecutar el instalador, **no uses los perfiles de energía nativos de tu entorno de escritorio (ej. KDE)** ya que ahora estarán desconectados. En su lugar:

1. Abre el menú de aplicaciones (Menú Inicio).
2. Busca **Modo Turbo** y **Modo Silencio**.
3. Haz clic derecho en ambos y selecciona **"Anclar al Gestor de Tareas"** (Pin to Taskbar).
4. Usa esos botones con un solo clic:
   - **Modo Silencio (Batería):** Turbo apagado. 2.80GHz máximo. Ventiladores dormidos hasta los 60°C.
   - **Modo Turbo (Cohete):** Turbo al 100%. Picos de 4.2+ GHz sostenidos. Ventiladores agresivos desde los 45°C.

## ⚠️ Advertencias
* Asegúrate de tener instalado el kernel para T2 (`linux-t2`) y el paquete de ventiladores `t2fanrd`.
* El paquete principal que hace la magia es `throttled`. Puedes instalarlo desde el repositorio AUR en Arch Linux usando `yay -S throttled`.
