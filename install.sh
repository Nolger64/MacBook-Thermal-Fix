#!/usr/bin/env bash
# Script de Instalación y Configuración Térmica para MacBook Pro (T2) en Linux (GNOME / KDE / Arch)
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Iniciando configuración térmica para MacBook Pro T2...${NC}"

# 1. Comprobar dependencias
echo -e "\n${YELLOW}[1/6] Verificando dependencias...${NC}"
DEPENDENCIES=("python" "sed")
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null && ! pacman -Qs "$dep" &> /dev/null; then
        echo -e "${RED}Error: Falta la dependencia '$dep'. Por favor instálala primero.${NC}"
        exit 1
    fi
done

# libnotify para notificaciones en el escritorio (GNOME / KDE)
if ! command -v notify-send &> /dev/null; then
    echo -e "${YELLOW}Aviso: notify-send no está instalado. Intentando instalar libnotify vía pacman...${NC}"
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed --noconfirm libnotify || true
    fi
fi

if [ ! -f "/usr/lib/throttled/throttled.py" ]; then
    echo -e "${YELLOW}Aviso: throttled no está instalado. Intentando instalarlo vía pacman...${NC}"
    if command -v pacman &> /dev/null; then
        sudo pacman -S --needed throttled || {
            echo -e "${RED}Error: No se pudo instalar throttled. Instálalo manualmente con 'sudo pacman -S throttled' o 'paru -S throttled'.${NC}"
            exit 1
        }
    else
        echo -e "${RED}Error: throttled no está instalado. Por favor instálalo primero.${NC}"
        exit 1
    fi
fi

# 2. Deshabilitar y enmascarar demonios conflictivos
# En GNOME, power-profiles-daemon y tuned-ppd se reactivan por D-Bus salvo que se enmascaren (mask)
echo -e "\n${YELLOW}[2/6] Deshabilitando y enmascarando servicios de energía conflictivos...${NC}"
for svc in power-profiles-daemon thermald auto-cpufreq tuned tuned-ppd; do
    if systemctl list-unit-files "$svc.service" &>/dev/null || systemctl is-active --quiet "$svc" || systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        sudo systemctl stop "$svc" 2>/dev/null || true
        sudo systemctl disable "$svc" 2>/dev/null || true
        sudo systemctl mask "$svc" 2>/dev/null || true
        echo "Desactivado y enmascarado (masked): $svc"
    fi
done

# 3. Configurar Kernel MSR
echo -e "\n${YELLOW}[3/6] Configurando permisos MSR en el Bootloader...${NC}"
BOOT_CONF=""
if [ -f /boot/efi/loader/entries/arch.conf ]; then
    BOOT_CONF="/boot/efi/loader/entries/arch.conf"
elif [ -f /boot/loader/entries/arch.conf ]; then
    BOOT_CONF="/boot/loader/entries/arch.conf"
elif compgen -G "/boot/efi/loader/entries/*.conf" > /dev/null; then
    BOOT_CONF=$(ls /boot/efi/loader/entries/*.conf | head -n 1)
elif compgen -G "/boot/loader/entries/*.conf" > /dev/null; then
    BOOT_CONF=$(ls /boot/loader/entries/*.conf | head -n 1)
fi

if [ -n "$BOOT_CONF" ]; then
    if ! grep -q "msr.allow_writes=on" "$BOOT_CONF"; then
        sudo sed -i 's/^options.*/& msr.allow_writes=on/' "$BOOT_CONF"
        echo "Añadido msr.allow_writes=on a systemd-boot ($BOOT_CONF)"
    else
        echo "systemd-boot ($BOOT_CONF) ya tiene msr.allow_writes=on configurado."
    fi
elif [ -f /etc/default/grub ]; then
    if ! grep -q "msr.allow_writes=on" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="msr.allow_writes=on /' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || sudo grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg
        echo "Añadido msr.allow_writes=on a GRUB."
    else
        echo "GRUB ya tiene msr.allow_writes=on configurado."
    fi
else
    echo -e "${RED}No se detectó GRUB ni systemd-boot automáticamente. Añade msr.allow_writes=on manualmente a tu kernel.${NC}"
fi

# 4. Configurar Throttled y Perfiles de Ventilador
echo -e "\n${YELLOW}[4/6] Configurando throttled y perfiles t2fanrd...${NC}"
# Reparar y configurar throttled para MacBook T2
sudo sed -i 's/^k\[GENERAL\]/[GENERAL]/g' /etc/throttled.conf 2>/dev/null || true
sudo sed -i 's/^Sysfs_Power_Path:.*/Sysfs_Power_Path: \/sys\/class\/power_supply\/ADP*\/online/g' /etc/throttled.conf 2>/dev/null || true
sudo sed -i 's/^Trip_Temp_C:.*/Trip_Temp_C: 95/g' /etc/throttled.conf
# Deshabilitar cTDP porque MSR_CONFIG_TDP_CONTROL está bloqueado por Apple en T2 y provoca la caída del demonio
sudo sed -i 's/^cTDP:/# cTDP:/g' /etc/throttled.conf
sudo sed -i 's/^Disable_BDPROCHOT:.*/Disable_BDPROCHOT: True/g' /etc/throttled.conf
sudo ln -sf /usr/lib/throttled/throttled.py /usr/local/bin/throttled 2>/dev/null || true

# Perfil Silencioso (Normal: 2.8 GHz)
cat << 'EOF_CONF' | sudo tee /etc/t2fand.conf.normal > /dev/null
[Fan1]
low_temp=60
high_temp=90
speed_curve=linear
always_full_speed=false

[Fan2]
low_temp=60
high_temp=90
speed_curve=linear
always_full_speed=false
EOF_CONF
sudo ln -sf /etc/t2fand.conf.normal /etc/t2fand.conf.quiet

# Perfil Cool (1.0 GHz: ventilación moderada continua para chasis helado)
cat << 'EOF_CONF' | sudo tee /etc/t2fand.conf.cool > /dev/null
[Fan1]
low_temp=38
high_temp=75
speed_curve=linear
always_full_speed=false

[Fan2]
low_temp=38
high_temp=75
speed_curve=linear
always_full_speed=false
EOF_CONF

# Perfil Agresivo (Turbo: 4.2+ GHz)
cat << 'EOF_CONF' | sudo tee /etc/t2fand.conf.aggressive > /dev/null
[Fan1]
low_temp=45
high_temp=80
speed_curve=linear
always_full_speed=false

[Fan2]
low_temp=45
high_temp=80
speed_curve=linear
always_full_speed=false
EOF_CONF

# 5. Creando scripts de los 3 modos (Cool, Normal, Turbo) y conmutador
echo -e "\n${YELLOW}[5/6] Creando comandos de gestión térmica y permisos sudo...${NC}"

# Modo Cool: 1.0 GHz máximo, ventiladores óptimos para mantener el Mac frío
cat << 'EOF_SCRIPT' | sudo tee /usr/local/bin/boost_cool > /dev/null
#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]; then
    sudo "$0" "$@"
    RET=$?
    if [ $RET -eq 0 ] && command -v notify-send &>/dev/null; then
        notify-send -i weather-snow-symbolic -a "MacBook Thermal" "Modo Cool" "❄️ Procesador a 1.0 GHz (Máx) y Ventiladores Óptimos Fríos"
    fi
    exit $RET
fi

echo 1 | tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
echo 1000000 | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq > /dev/null
echo "powersave" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -f "$f" ] && echo "power" | tee "$f" > /dev/null || true
done
python3 -c '
import struct, os, glob
for cpu in glob.glob("/dev/cpu/[0-9]*/msr"):
    try:
        f = os.open(cpu, os.O_RDWR)
        val = struct.unpack("Q", os.pread(f, 8, 0x1FC))[0]
        if val & 1:
            os.pwrite(f, struct.pack("Q", val & ~1), 0x1FC)
        os.close(f)
    except Exception:
        pass
' 2>/dev/null || true
cp /etc/t2fand.conf.cool /etc/t2fand.conf 2>/dev/null || true
systemctl restart t2fanrd.service 2>/dev/null || true
echo "cool" > /etc/macbook_thermal_mode 2>/dev/null || true
echo "❄️ Modo Cool ACTIVADO (1.0 GHz máximo, ventiladores constantes para frío total)"
EOF_SCRIPT

# Modo Normal: 2.8 GHz base, ventiladores silenciosos
cat << 'EOF_SCRIPT' | sudo tee /usr/local/bin/boost_normal > /dev/null
#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]; then
    sudo "$0" "$@"
    RET=$?
    if [ $RET -eq 0 ] && command -v notify-send &>/dev/null; then
        notify-send -i power-profile-power-saver-symbolic -a "MacBook Thermal" "Modo Normal" "⚖️ Procesador a 2.8 GHz y Ventiladores Silenciosos"
    fi
    exit $RET
fi

echo 1 | tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
echo 2800000 | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq > /dev/null
echo "powersave" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -f "$f" ] && echo "balance_power" | tee "$f" > /dev/null || true
done
python3 -c '
import struct, os, glob
for cpu in glob.glob("/dev/cpu/[0-9]*/msr"):
    try:
        f = os.open(cpu, os.O_RDWR)
        val = struct.unpack("Q", os.pread(f, 8, 0x1FC))[0]
        if val & 1:
            os.pwrite(f, struct.pack("Q", val & ~1), 0x1FC)
        os.close(f)
    except Exception:
        pass
' 2>/dev/null || true
cp /etc/t2fand.conf.normal /etc/t2fand.conf 2>/dev/null || true
systemctl restart t2fanrd.service 2>/dev/null || true
echo "normal" > /etc/macbook_thermal_mode 2>/dev/null || true
echo "⚖️ Modo Normal ACTIVADO (2.8 GHz, ventiladores silenciosos)"
EOF_SCRIPT

# Modo Turbo: 4.2+ GHz sostenidos, ventiladores agresivos
cat << 'EOF_SCRIPT' | sudo tee /usr/local/bin/boost_on > /dev/null
#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]; then
    sudo "$0" "$@"
    RET=$?
    if [ $RET -eq 0 ] && command -v notify-send &>/dev/null; then
        notify-send -i power-profile-performance-symbolic -a "MacBook Thermal" "Modo Turbo" "🚀 Turbo Boost ACTIVADO (4.2+ GHz) y Ventiladores Agresivos"
    fi
    exit $RET
fi

echo 0 | tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
echo 100 | tee /sys/devices/system/cpu/intel_pstate/max_perf_pct > /dev/null
echo 4700000 | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq > /dev/null
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    [ -f "$f" ] && echo "performance" | tee "$f" > /dev/null || true
done
python3 -c '
import struct, os, glob
for cpu in glob.glob("/dev/cpu/[0-9]*/msr"):
    try:
        f = os.open(cpu, os.O_RDWR)
        val = struct.unpack("Q", os.pread(f, 8, 0x1FC))[0]
        if val & 1:
            os.pwrite(f, struct.pack("Q", val & ~1), 0x1FC)
        os.close(f)
    except Exception:
        pass
' 2>/dev/null || true
cp /etc/t2fand.conf.aggressive /etc/t2fand.conf 2>/dev/null || true
systemctl restart t2fanrd.service 2>/dev/null || true
echo "turbo" > /etc/macbook_thermal_mode 2>/dev/null || true
echo "🚀 Modo Turbo ACTIVADO (4.2+ GHz y ventiladores agresivos)"
EOF_SCRIPT

# Conmutador cíclico: Normal -> Turbo -> Cool -> Normal
cat << 'EOF_SCRIPT' | sudo tee /usr/local/bin/boost_toggle > /dev/null
#!/usr/bin/env bash
CURRENT_MODE=""
if [ -f /etc/macbook_thermal_mode ]; then
    CURRENT_MODE=$(cat /etc/macbook_thermal_mode 2>/dev/null | tr -d "[:space:]")
fi

if [ -z "$CURRENT_MODE" ]; then
    MAX_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null || echo "2800000")
    NO_TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || echo "1")
    if [ "$NO_TURBO" = "0" ]; then
        CURRENT_MODE="turbo"
    elif [ "$MAX_FREQ" -le 1500000 ]; then
        CURRENT_MODE="cool"
    else
        CURRENT_MODE="normal"
    fi
fi

case "$CURRENT_MODE" in
    normal)
        /usr/local/bin/boost_on "$@"
        ;;
    turbo)
        /usr/local/bin/boost_cool "$@"
        ;;
    cool|*)
        /usr/local/bin/boost_normal "$@"
        ;;
esac
EOF_SCRIPT

sudo chmod +x /usr/local/bin/boost_cool /usr/local/bin/boost_normal /usr/local/bin/boost_on /usr/local/bin/boost_toggle
sudo ln -sf /usr/local/bin/boost_normal /usr/local/bin/boost_off
sudo ln -sf /usr/local/bin/boost_on /usr/local/bin/boost_turbo

TARGET_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
[ -z "$USER_HOME" ] && USER_HOME="$HOME"

echo "$TARGET_USER ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/boost_on, /usr/local/bin/boost_off, /usr/local/bin/boost_normal, /usr/local/bin/boost_cool, /usr/local/bin/boost_toggle" | sudo tee /etc/sudoers.d/boost_scripts > /dev/null
sudo chmod 0440 /etc/sudoers.d/boost_scripts

sudo systemctl enable --now throttled.service

# 6. Crear accesos directos de escritorio (compatibles con GNOME y KDE)
echo -e "\n${YELLOW}[6/6] Creando aplicaciones de escritorio (GNOME / KDE)...${NC}"
mkdir -p "$USER_HOME/.local/share/applications"

cat << 'EOF_DESK' > "$USER_HOME/.local/share/applications/modo-cool.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Modo Cool
Comment=Limita a 1.0 GHz y mantiene el Mac frío para videos y tareas ligeras
Exec=/usr/local/bin/boost_cool
Icon=weather-snow-symbolic
Terminal=false
Categories=Utility;System;Settings;
StartupNotify=false
EOF_DESK

cat << 'EOF_DESK' > "$USER_HOME/.local/share/applications/modo-normal.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Modo Normal
Comment=Frecuencia base a 2.8 GHz y ventiladores silenciosos
Exec=/usr/local/bin/boost_normal
Icon=power-profile-balanced-symbolic
Terminal=false
Categories=Utility;System;Settings;
StartupNotify=false
EOF_DESK

cat << 'EOF_DESK' > "$USER_HOME/.local/share/applications/modo-turbo.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Modo Turbo
Comment=Activa el rendimiento máximo sostenido (4.2+ GHz) y ventiladores agresivos
Exec=/usr/local/bin/boost_on
Icon=power-profile-performance-symbolic
Terminal=false
Categories=Utility;System;Settings;
StartupNotify=false
EOF_DESK

cat << 'EOF_DESK' > "$USER_HOME/.local/share/applications/modo-toggle.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Control Térmico MacBook
GenericName=Gestión Térmica T2
Comment=Alternar entre Modo Normal, Turbo y Cool
Exec=/usr/local/bin/boost_toggle
Icon=power-profile-balanced-symbolic
Terminal=false
Categories=Utility;System;Settings;
StartupNotify=false
Actions=Normal;Turbo;Cool;

[Desktop Action Normal]
Name=⚖️ Modo Normal (2.8 GHz)
Exec=/usr/local/bin/boost_normal
Icon=power-profile-balanced-symbolic

[Desktop Action Turbo]
Name=🚀 Modo Turbo (4.2+ GHz)
Exec=/usr/local/bin/boost_on
Icon=power-profile-performance-symbolic

[Desktop Action Cool]
Name=❄️ Modo Cool (1.0 GHz)
Exec=/usr/local/bin/boost_cool
Icon=weather-snow-symbolic
EOF_DESK

rm -f "$USER_HOME/.local/share/applications/modo-silencio.desktop" 2>/dev/null || true

if [ -n "$SUDO_USER" ]; then
    chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.local/share/applications/modo-"*.desktop 2>/dev/null || true
fi

update-desktop-database "$USER_HOME/.local/share/applications" 2>/dev/null || true

# Si se detecta GNOME Shell, instalar la extensión nativa del panel superior
if command -v gnome-shell &>/dev/null && [ -d "$SCRIPT_DIR/gnome-extension" ]; then
    echo -e "${YELLOW}Instalando extensión del panel superior para GNOME Shell...${NC}"
    EXT_DIR="$USER_HOME/.local/share/gnome-shell/extensions/macbook-thermal@local"
    mkdir -p "$EXT_DIR"
    cp -r "$SCRIPT_DIR/gnome-extension/"* "$EXT_DIR/"
    if [ -n "$SUDO_USER" ]; then
        chown -R "$TARGET_USER:$TARGET_USER" "$EXT_DIR" 2>/dev/null || true
    fi
    echo "Extensión del panel superior instalada en $EXT_DIR"
fi

# 7. Resumen y recomendaciones según el Entorno de Escritorio
CURRENT_DE="${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}"
echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}¡INSTALACIÓN COMPLETADA CON ÉXITO!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${YELLOW}RECORDATORIOS IMPORTANTES:${NC}"
echo -e "1. ${RED}REINICIA TU MAC${NC} para que los cambios del Kernel MSR surtan efecto."

if [[ "$CURRENT_DE" =~ [Gg][Nn][Oo][Mm][Ee] ]]; then
    echo -e "2. ${GREEN}Detectado entorno GNOME:${NC}"
    echo -e "   - Disponibles los 3 modos: ${BLUE}Modo Cool (1.0 GHz)${NC}, ${BLUE}Modo Normal (2.8 GHz)${NC} y ${BLUE}Modo Turbo (4.2+ GHz)${NC}."
    echo -e "   - Con ${BLUE}'Control Térmico MacBook'${NC} puedes dar 1 clic para ciclar, o clic derecho para elegir modo."
    echo -e "   - ${YELLOW}Atajos de teclado:${NC} Ejecuta './setup-gnome-shortcuts.sh' (Super+F1: Cool, Super+F2: Normal, Super+F3: Turbo, Super+B: Ciclo)."
    echo -e "   - ${YELLOW}Barra superior:${NC} Usa la extensión nativa o Custom Command Toggle."
elif [[ "$CURRENT_DE" =~ [Kk][Dd][Ee] ]]; then
    echo -e "2. ${GREEN}Detectado entorno KDE Plasma:${NC}"
    echo -e "   - Busca 'Modo Cool', 'Modo Normal' y 'Modo Turbo' en el menú de KDE y anclalos al panel."
    echo -e "   - Ignora el menú nativo de batería de KDE."
else
    echo -e "2. ${GREEN}Comandos listos para usar:${NC}"
    echo -e "   - /usr/local/bin/boost_cool   (❄️ Modo Cool - 1.0 GHz)"
    echo -e "   - /usr/local/bin/boost_normal (⚖️ Modo Normal - 2.8 GHz)"
    echo -e "   - /usr/local/bin/boost_on     (🚀 Modo Turbo - 4.2+ GHz)"
    echo -e "   - /usr/local/bin/boost_toggle (🔄 Ciclo entre los 3 modos)"
fi
echo ""
