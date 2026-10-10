#!/usr/bin/env bash
# Configura atajos de teclado globales en GNOME para los 3 modos térmicos de MacBook
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Configurando atajos de teclado de GNOME para MacBook Thermal Fix (3 Modos)...${NC}"

python3 - << 'EOF'
from gi.repository import Gio

SHORTCUTS = [
    {
        "id": "macbook-cool",
        "name": "Modo Cool (1.0 GHz)",
        "command": "/usr/local/bin/boost_cool",
        "binding": "<Super>F1"
    },
    {
        "id": "macbook-normal",
        "name": "Modo Normal (2.8 GHz)",
        "command": "/usr/local/bin/boost_normal",
        "binding": "<Super>F2"
    },
    {
        "id": "macbook-turbo",
        "name": "Modo Turbo (4.2+ GHz)",
        "command": "/usr/local/bin/boost_on",
        "binding": "<Super>F3"
    },
    {
        "id": "macbook-toggle",
        "name": "Alternar Modo Térmico (Ciclo)",
        "command": "/usr/local/bin/boost_toggle",
        "binding": "<Super>b"
    }
]

media_keys = Gio.Settings.new("org.gnome.settings-daemon.plugins.media-keys")
current_bindings = list(media_keys.get_strv("custom-keybindings"))

for sc in SHORTCUTS:
    path = f"/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/{sc['id']}/"
    custom_setting = Gio.Settings.new_with_path(
        "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding", path
    )
    custom_setting.set_string("name", sc["name"])
    custom_setting.set_string("command", sc["command"])
    custom_setting.set_string("binding", sc["binding"])
    
    if path not in current_bindings:
        current_bindings.append(path)

# Limpiar posibles atajos viejos como macbook-silencio
if "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/macbook-silencio/" in current_bindings:
    current_bindings.remove("/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/macbook-silencio/")

media_keys.set_strv("custom-keybindings", current_bindings)
Gio.Settings.sync()
print("Atajos registrados correctamente en GNOME.")
EOF

echo -e "\n${GREEN}¡Atajos configurados exitosamente!${NC}"
echo -e "• ${YELLOW}Super + F1${NC} : ❄️ Modo Cool (1.0 GHz, ideal para videos y temperatura helada)"
echo -e "• ${YELLOW}Super + F2${NC} : ⚖️ Modo Normal (2.8 GHz, ventiladores silenciosos)"
echo -e "• ${YELLOW}Super + F3${NC} : 🚀 Modo Turbo (4.2+ GHz, máximo rendimiento y ventiladores agresivos)"
echo -e "• ${YELLOW}Super + B${NC}  : 🔄 Alternar cíclicamente entre los 3 modos"
echo -e "\nPuedes modificarlos en cualquier momento desde ${BLUE}Ajustes -> Teclado -> Atajos de teclado -> Atajos personalizados${NC}."
