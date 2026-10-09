#!/usr/bin/env bash
# Script de Instalación y Configuración Térmica para MacBook Pro (T2) en Arch Linux
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
if [ ! -f "/usr/lib/throttled/throttled.py" ]; then
    echo -e "${RED}Error: throttled no está instalado. Instálalo desde AUR (yay -S throttled).${NC}"
    exit 1
fi

# 2. Deshabilitar demonios conflictivos
echo -e "\n${YELLOW}[2/6] Deshabilitando servicios de energía conflictivos...${NC}"
for svc in power-profiles-daemon thermald auto-cpufreq; do
    if systemctl is-active --quiet "$svc" || systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        sudo systemctl disable --now "$svc" || true
        echo "Desactivado: $svc"
    fi
done

# 3. Configurar Kernel MSR
echo -e "\n${YELLOW}[3/6] Configurando permisos MSR en el Bootloader...${NC}"
if [ -f /boot/efi/loader/entries/arch.conf ]; then
    if ! grep -q "msr.allow_writes=on" /boot/efi/loader/entries/arch.conf; then
        sudo sed -i 's/^options.*/& msr.allow_writes=on/' /boot/efi/loader/entries/arch.conf
        echo "Añadido a systemd-boot (arch.conf)"
    fi
elif [ -f /etc/default/grub ]; then
    if ! grep -q "msr.allow_writes=on" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="msr.allow_writes=on /' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || sudo grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg
        echo "Añadido a GRUB."
    fi
else
    echo -e "${RED}No se detectó GRUB ni systemd-boot automáticamente. Añade msr.allow_writes=on manualmente a tu kernel.${NC}"
fi

# 4. Configurar Throttled y Perfiles de Ventilador
echo -e "\n${YELLOW}[4/6] Configurando throttled y perfiles t2fanrd...${NC}"
# Reparar y configurar throttled
sudo sed -i 's/^k\[GENERAL\]/[GENERAL]/g' /etc/throttled.conf 2>/dev/null || true
sudo sed -i 's/^Trip_Temp_C:.*/Trip_Temp_C: 95/g' /etc/throttled.conf
sudo sed -i 's/^cTDP:.*/cTDP: 0/g' /etc/throttled.conf

cat << 'EOF_CONF' | sudo tee /etc/t2fand.conf.quiet > /dev/null
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

# 5. Creando scripts boost_on y boost_off
echo -e "\n${YELLOW}[5/6] Creando comandos de Boost y permisos sudo...${NC}"
cat << 'EOF_SCRIPT' | sudo tee /usr/local/bin/boost_on > /dev/null
#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi
echo 0 | tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
echo 100 | tee /sys/devices/system/cpu/intel_pstate/max_perf_pct > /dev/null
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
cp /etc/t2fand.conf.aggressive /etc/t2fand.conf
systemctl restart t2fanrd.service || true
echo "🚀 Intel Turbo Boost ACTIVADO y Ventiladores Agresivos"
EOF_SCRIPT

cat << 'EOF_SCRIPT' | sudo tee /usr/local/bin/boost_off > /dev/null
#!/usr/bin/env bash
if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi
echo 1 | tee /sys/devices/system/cpu/intel_pstate/no_turbo > /dev/null
cp /etc/t2fand.conf.quiet /etc/t2fand.conf
systemctl restart t2fanrd.service || true
echo "🛑 Intel Turbo Boost DESACTIVADO y Ventiladores Silenciosos"
EOF_SCRIPT

sudo chmod +x /usr/local/bin/boost_on /usr/local/bin/boost_off

USER_NAME=$(whoami)
echo "$USER_NAME ALL=(ALL:ALL) NOPASSWD: /usr/local/bin/boost_on, /usr/local/bin/boost_off" | sudo tee /etc/sudoers.d/boost_scripts > /dev/null
sudo chmod 0440 /etc/sudoers.d/boost_scripts

sudo systemctl enable --now throttled.service

# 6. Crear accesos directos KDE
echo -e "\n${YELLOW}[6/6] Creando aplicaciones para KDE...${NC}"
mkdir -p "$HOME/.local/share/applications"

cat << 'EOF_DESK' > "$HOME/.local/share/applications/modo-turbo.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Modo Turbo
Comment=Activa el rendimiento máximo y ventiladores agresivos
Exec=/usr/local/bin/boost_on
Icon=preferences-system-performance
Terminal=false
Categories=Utility;System;
EOF_DESK

cat << 'EOF_DESK' > "$HOME/.local/share/applications/modo-silencio.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Modo Silencio
Comment=Desactiva Turbo Boost y silencia los ventiladores
Exec=/usr/local/bin/boost_off
Icon=preferences-system-power-management
Terminal=false
Categories=Utility;System;
EOF_DESK

update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}¡INSTALACIÓN COMPLETADA CON ÉXITO!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${YELLOW}RECORDATORIOS IMPORTANTES:${NC}"
echo -e "1. ${RED}REINICIA TU MAC${NC} para que los cambios del Kernel MSR surtan efecto."
echo -e "2. Abre el menú de KDE, busca 'Modo Turbo' y 'Modo Silencio' y ANCLALOS a tu barra de tareas."
echo -e "3. IGNORA el menú de batería de KDE. Usa siempre estos botones creados."
echo ""
