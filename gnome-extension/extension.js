/* extension.js - MacBook Thermal Indicator for GNOME Shell 45+ (3 Modes: Cool, Normal, Turbo) */
import GObject from 'gi://GObject';
import St from 'gi://St';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const Indicator = GObject.registerClass(
class Indicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'MacBook Thermal');

        const box = new St.BoxLayout({
            style_class: 'panel-status-indicators-box',
            reactive: true,
        });

        this._icon = new St.Icon({
            icon_name: 'power-profile-balanced-symbolic',
            style_class: 'system-status-icon',
        });
        box.add_child(this._icon);

        this._label = new St.Label({
            text: '...',
            y_align: Clutter.ActorAlign.CENTER,
            style: 'margin-left: 4px; font-weight: bold;',
        });
        box.add_child(this._label);

        this.add_child(box);

        // Build Menu
        this._headerItem = new PopupMenu.PopupMenuItem('Estado Térmico', {reactive: false});
        this.menu.addMenuItem(this._headerItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        const cycleItem = new PopupMenu.PopupMenuItem('🔄 Alternar Modo (Ciclo)');
        cycleItem.connect('activate', () => {
            GLib.spawn_command_line_async('/usr/local/bin/boost_toggle');
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
                this._updateStatus();
                return GLib.SOURCE_REMOVE;
            });
        });
        this.menu.addMenuItem(cycleItem);

        const coolItem = new PopupMenu.PopupMenuItem('❄️ Modo Cool (1.0 GHz)');
        coolItem.connect('activate', () => {
            GLib.spawn_command_line_async('/usr/local/bin/boost_cool');
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
                this._updateStatus();
                return GLib.SOURCE_REMOVE;
            });
        });
        this.menu.addMenuItem(coolItem);

        const normalItem = new PopupMenu.PopupMenuItem('⚖️ Modo Normal (2.8 GHz)');
        normalItem.connect('activate', () => {
            GLib.spawn_command_line_async('/usr/local/bin/boost_normal');
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
                this._updateStatus();
                return GLib.SOURCE_REMOVE;
            });
        });
        this.menu.addMenuItem(normalItem);

        const turboItem = new PopupMenu.PopupMenuItem('🚀 Modo Turbo (4.2+ GHz)');
        turboItem.connect('activate', () => {
            GLib.spawn_command_line_async('/usr/local/bin/boost_on');
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
                this._updateStatus();
                return GLib.SOURCE_REMOVE;
            });
        });
        this.menu.addMenuItem(turboItem);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this._tempItem = new PopupMenu.PopupMenuItem('🌡️ Temperatura: -- °C', {reactive: false});
        this.menu.addMenuItem(this._tempItem);

        const monitorItem = new PopupMenu.PopupMenuItem('📊 Monitor del Sistema');
        monitorItem.connect('activate', () => {
            GLib.spawn_command_line_async('gnome-system-monitor');
        });
        this.menu.addMenuItem(monitorItem);

        this._updateStatus();
        this._timeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
            this._updateStatus();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _getTemperature() {
        try {
            const [ok, contents] = GLib.file_get_contents('/sys/class/thermal/thermal_zone0/temp');
            if (ok) {
                const temp = parseInt(new TextDecoder().decode(contents).trim(), 10);
                if (!isNaN(temp)) {
                    return Math.round(temp / 1000);
                }
            }
        } catch (e) {}
        return null;
    }

    _getCurrentMode() {
        try {
            const [ok, contents] = GLib.file_get_contents('/etc/macbook_thermal_mode');
            if (ok) {
                const mode = new TextDecoder().decode(contents).trim().toLowerCase();
                if (['cool', 'normal', 'turbo'].includes(mode)) {
                    return mode;
                }
            }
        } catch (e) {}

        // Fallback detection via sysfs
        try {
            const [okTurbo, turboContent] = GLib.file_get_contents('/sys/devices/system/cpu/intel_pstate/no_turbo');
            if (okTurbo && new TextDecoder().decode(turboContent).trim() === '0') {
                return 'turbo';
            }
            const [okFreq, freqContent] = GLib.file_get_contents('/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq');
            if (okFreq) {
                const freq = parseInt(new TextDecoder().decode(freqContent).trim(), 10);
                if (freq <= 1500000) return 'cool';
            }
        } catch (e) {}

        return 'normal';
    }

    _updateStatus() {
        const mode = this._getCurrentMode();
        const temp = this._getTemperature();
        const tempStr = temp !== null ? `${temp}°C` : '';

        if (mode === 'turbo') {
            this._icon.icon_name = 'power-profile-performance-symbolic';
            this._label.text = `🚀 ${tempStr}`;
            this._headerItem.label.text = 'Estado: 🚀 Modo Turbo (4.2+ GHz)';
        } else if (mode === 'cool') {
            this._icon.icon_name = 'weather-snow-symbolic';
            this._label.text = `❄️ ${tempStr}`;
            this._headerItem.label.text = 'Estado: ❄️ Modo Cool (1.0 GHz)';
        } else {
            this._icon.icon_name = 'power-profile-balanced-symbolic';
            this._label.text = `⚖️ ${tempStr}`;
            this._headerItem.label.text = 'Estado: ⚖️ Modo Normal (2.8 GHz)';
        }

        if (this._tempItem) {
            this._tempItem.label.text = `🌡️ Temperatura CPU: ${temp !== null ? temp + '°C' : 'N/A'}`;
        }
    }

    destroy() {
        if (this._timeoutId) {
            GLib.Source.remove(this._timeoutId);
            this._timeoutId = null;
        }
        super.destroy();
    }
});

export default class MacBookThermalExtension extends Extension {
    enable() {
        this._indicator = new Indicator();
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }
    }
}
