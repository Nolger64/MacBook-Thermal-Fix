# MacBook Pro T2 (Linux) - Solución Definitiva de Throttling Térmico

Este repositorio contiene la automatización de la configuración térmica para MacBooks con chip T2 (especialmente la MacBook Pro 13" 2019) ejecutando Arch Linux o distribuciones similares, con soporte optimizado tanto para **GNOME** como para **KDE Plasma**.

## 📌 ¿Por qué existe esto? (El Problema)
En macOS, Apple permite que el procesador alcance los 95°C-99°C antes de reducir el rendimiento (throttling). En Linux, intervienen tres capas conflictivas:
1. **Hardware (Chip T2):** Detecta calor en el chasis y lanza la señal `PROCHOT`, bajando la CPU a 800 MHz.
2. **Kernel Linux:** Bloquea los registros de voltaje y energía (MSR) por seguridad.
3. **Demonios de Linux (`power-profiles-daemon`, `thermald`):** Sobrescriben las frecuencias constantemente, causando picos de 4.2GHz que duran solo 1 segundo y luego caen a 2.8GHz. En entornos como GNOME, `power-profiles-daemon` se reactiva por D-Bus automáticamente salvo que esté enmascarado.

## 🛠️ ¿Qué hace este script? (La Solución)
El script de instalación `install.sh` resuelve esta guerra de software automatizando todo el proceso:

1. **Destruye y enmascara los demonios conflictivos:** Detiene, deshabilita y enmascara (`mask`) `power-profiles-daemon`, `auto-cpufreq` y `thermald` para evitar que GNOME Shell o el sistema los revivan vía D-Bus.
2. **Desbloquea el Kernel:** Añade `msr.allow_writes=on` a tu gestor de arranque (systemd-boot o GRUB) para permitir modificaciones térmicas.
3. **Domestica al Chip T2:** Configura el demonio `throttled` para ignorar la señal de emergencia `BDPROCHOT` del chasis y eleva el umbral de estrangulamiento a **95°C**, replicando el comportamiento nativo de macOS.
4. **Crea 3 Perfiles Térmicos Especializados (GNOME y KDE):**
   - **❄️ Modo Cool (1.0 GHz):** Frecuencia limitada estrictamente a 1.0 GHz y ventilación suave constante para mantener el chasis de aluminio helado (ideal para ver vídeos, YouTube o tenerlo sobre las piernas sin calentarse).
   - **⚖️ Modo Normal (2.8 GHz):** Frecuencia base sin Turbo Boost, ventiladores silenciosos apagados hasta los 60°C. El modo equilibrado para el día a día.
   - **🚀 Modo Turbo (4.2+ GHz):** Potencia máxima sostenida con Intel Turbo Boost y ventiladores agresivos para tareas pesadas o IA (Ollama).
   - **🔄 Control Térmico MacBook (`boost_toggle`):** Lanzador unificado que cicla entre los 3 modos y ofrece menú contextual de clic derecho.
   - **Notificaciones Nativas:** Alertas emergentes en pantalla confirmando el cambio con icono correspondiente.
5. **Control Dinámico de Ventiladores:** Configura `t2fanrd` con curvas personalizadas: fría continua para Modo Cool, silenciosa para Modo Normal y agresiva para Modo Turbo.

---

## 🚀 Instrucciones de Instalación

1. Abre una terminal en esta carpeta.
2. Ejecuta el instalador:
   ```bash
   ./install.sh
   ```
3. **¡REINICIA TU MAC!** (Fundamental para cargar el permiso MSR del kernel).

---

## 🖥️ Cómo usar los Modos en GNOME

### Alternativa 1: Anclar a Favoritos en el Dash / Dock (Nativo)
1. Presiona la tecla `Super` (Command en Mac).
2. Busca **Control Térmico MacBook**, **Modo Cool**, **Modo Normal** o **Modo Turbo**.
3. Haz clic derecho y selecciona **"Añadir a favoritos"**.
4. Con el lanzador unificado **Control Térmico MacBook**:
   - **Clic izquierdo:** Cicla entre Modo Normal ➔ Turbo ➔ Cool.
   - **Clic derecho:** Acceso directo instantáneo a cualquiera de los 3 modos.

### Alternativa 2: Atajos de Teclado Globales (Recomendado para Mac)
Ejecuta el asistente incluido para registrar los atajos:
```bash
./setup-gnome-shortcuts.sh
```
Atajos configurados:
- **`Super + F1`** : ❄️ Modo Cool (1.0 GHz, chasis helado)
- **`Super + F2`** : ⚖️ Modo Normal (2.8 GHz, ventiladores silenciosos)
- **`Super + F3`** : 🚀 Modo Turbo (4.2+ GHz, máximo rendimiento)
- **`Super + B`**  : 🔄 Alternar cíclicamente entre los 3 modos

*(También puedes configurarlos manualmente en **Ajustes -> Teclado -> Atajos de teclado -> Atajos personalizados**).*

### Alternativa 3: Extensión "Dash to Panel" (Experiencia idéntica a KDE)
Si extrañas la barra de tareas clásica de KDE donde podías tener los botones anclados en el panel inferior/superior:
1. Instala la extensión **Dash to Panel** (mediante *Extension Manager* o `gnome-shell-extension-dash-to-panel`).
2. Haz clic derecho en **Modo Turbo** y **Modo Silencio** -> **"Añadir a favoritos"**.
3. Aparecerán como botones fijos con un solo clic directamente en la barra de tareas.

### Alternativa 4: Botón / Interruptor en la Barra Superior (Extensión "Custom Command Toggle")
Argos fue descontinuada y no es compatible con GNOME moderno (45-51). La alternativa actual y mantenida es **Custom Command Toggle**:
1. Disponible en *Extension Manager* o [extensions.gnome.org](https://extensions.gnome.org/extension/7012/custom-command-toggle/).
2. Añade un botón interactivo tanto a la **barra superior (Top Bar)** como al menú desplegable de **Ajustes Rápidos (Quick Settings)**.
3. Se enlaza directamente a:
   - **Comando ON:** `/usr/local/bin/boost_on`
   - **Comando OFF:** `/usr/local/bin/boost_off`
   - **Icono:** `power-profile-performance-symbolic`
   - **Sincronización:** Detecta automáticamente el estado cada 2 segundos leyendo `/sys/devices/system/cpu/intel_pstate/no_turbo`.
4. El icono en el panel se iluminará cuando el Turbo esté activo y se atenuará en Modo Silencio.

---

## 🐧 Cómo usar los Modos en KDE Plasma

1. Abre el menú de aplicaciones (Kickoff).
2. Busca **Modo Turbo** y **Modo Silencio**.
3. Haz clic derecho en ambos y selecciona **"Añadir al panel"** (o "Anclar al Gestor de Tareas").
4. Usa los botones con un clic:
   - **Modo Silencio:** Turbo apagado. 2.80 GHz máximo.
   - **Modo Turbo:** Turbo al 100%. Picos de 4.2+ GHz sostenidos.
5. Ignora el control de energía nativo de KDE.

---

## ⌨️ Comandos desde Terminal

Los comandos pueden ejecutarse directamente desde cualquier script, terminal o atajo:
- `boost_cool`   : ❄️ Modo Cool (1.0 GHz máximo, chasis helado para vídeos/tareas ligeras).
- `boost_normal` : ⚖️ Modo Normal (2.8 GHz base, silencioso para uso diario).
- `boost_on`     : 🚀 Modo Turbo (4.2+ GHz máximo rendimiento y ventiladores agresivos).
- `boost_toggle` : 🔄 Cicla inteligentemente entre los 3 modos (Normal ➔ Turbo ➔ Cool).

---

## ⚠️ Requisitos previos
* Kernel con soporte T2 (`linux-t2`).
* Paquete de ventiladores `t2fanrd`.
* Paquete `throttled` (disponible en AUR: `yay -S throttled`).
* Paquete `libnotify` para las notificaciones de escritorio.
