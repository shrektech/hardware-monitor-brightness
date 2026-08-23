#!/usr/bin/env python3
"""
Hardware Monitor Brightness Worker Backend
==========================================
Provides fast, non-blocking, multi-monitor DDC/CI hardware backlight adjustments
with zero background polling and zero GPU I2C bus lock contention.

Architecture:
1. State Management:
   - Caches active display topologies in /tmp/ddc_brightness_state.json to avoid
     repeated slow `ddcutil detect` sweeps.
   - Saves state atomically using temporary files and `os.replace`.

2. Concurrency & Debouncing:
   - Uses a non-blocking process lock (fcntl.flock with LOCK_NB).
   - Fast UI response: Updates JSON target in ~2ms, fires KDE D-Bus OSD, and spawns
     a single background daemon worker.
   - Sequential I2C writes: Sends DDC commands sequentially to each display to
     prevent simultaneous bus acquisition errors (EBUSY) on shared GPU controllers.
"""

import sys
import os
import subprocess
import json
import fcntl
import time

STATE_FILE = "/tmp/ddc_brightness_state.json"
LOCK_FILE = "/tmp/ddc_brightness_worker.lock"


def probe_hardware_displays():
    """
    Performs a physical VESA DDC/CI bus scan using `ddcutil detect --brief`.
    Extracts display numbers, I2C bus device paths, model names, and serial numbers.
    Only executed on first startup or when explicitly requested via 'rescan'.
    """
    try:
        out = subprocess.check_output(
            ['ddcutil', 'detect', '--brief'],
            stderr=subprocess.DEVNULL,
            timeout=10
        ).decode('utf-8')
    except Exception:
        return []

    displays = []
    current = {}

    for line in out.splitlines():
        line = line.strip()
        if line.startswith('Display '):
            if current and 'display' in current:
                displays.append(current)
            parts = line.split()
            current = {
                'display': int(parts[1]),
                'model': 'External Display',
                'bus': '',
                'serial': '',
                'brightness': 50,
                'target_brightness': 50
            }
        elif line.startswith('I2C bus:'):
            current['bus'] = line.split(':', 1)[1].strip()
        elif line.startswith('Monitor:'):
            # Format: Mfg:Model:Serial (e.g., DEL:DELL P2422H:8XHW9J3)
            m_parts = line.split(':', 1)[1].strip().split(':')
            if len(m_parts) >= 2 and m_parts[1].strip():
                current['model'] = m_parts[1].strip()
            if len(m_parts) >= 3 and m_parts[2].strip():
                current['serial'] = m_parts[2].strip()

    if current and 'display' in current:
        displays.append(current)

    # Read current physical backlight brightness for each detected display
    for d in displays:
        try:
            b_out = subprocess.check_output(
                ['ddcutil', 'getvcp', '10', '--brief', '--display', str(d['display'])],
                stderr=subprocess.DEVNULL,
                timeout=3
            ).decode('utf-8')
            # Format: VCP 10 C <current_val> <max_val>
            val = int(b_out.strip().split()[3])
            d['brightness'] = val
            d['target_brightness'] = val
        except Exception:
            pass

    return displays


def get_state(force_rescan=False):
    """
    Loads active display state from RAM cache (/tmp), or performs a fresh probe
    if the state file is missing, empty, or a forced rescan is requested.
    """
    if not force_rescan and os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                state = json.load(f)
                if state.get('displays') and len(state['displays']) > 0:
                    return state
        except Exception:
            pass

    displays = probe_hardware_displays()
    master = displays[0]['brightness'] if displays else 50
    state = {'master': master, 'displays': displays}
    save_state(state)
    return state


def save_state(state):
    """
    Atomically writes state dictionary to STATE_FILE to prevent partial reads.
    """
    try:
        tmp_file = STATE_FILE + ".tmp"
        with open(tmp_file, 'w') as f:
            json.dump(state, f, indent=2)
        os.replace(tmp_file, STATE_FILE)
    except Exception:
        pass


def trigger_osd(val):
    """
    Triggers KDE Plasma's native On-Screen Display (OSD) brightness overlay
    via D-Bus session bus with zero perceptible latency.
    """
    try:
        subprocess.run(
            ['qdbus6', 'org.kde.plasmashell', '/org/kde/osdService',
             'org.kde.osdService.brightnessChanged', str(val)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1
        )
    except Exception:
        pass


def spawn_single_worker():
    """
    Spawns a detached single background daemon worker to write DDC values to hardware.
    Uses non-blocking flock: if a worker is already active, the new request simply
    updates the state file, and the running worker will pick up the new targets.
    """
    try:
        lock_fd = os.open(LOCK_FILE, os.O_CREAT | os.O_RDWR)
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (BlockingIOError, IOError):
            # Worker is already actively processing; it will catch the updated targets
            os.close(lock_fd)
            return
    except Exception:
        return

    pid = os.fork()
    if pid > 0:
        os.close(lock_fd)
        return  # Parent process returns immediately to keep UI responsive

    # Child process daemonization
    os.setsid()
    try:
        while True:
            try:
                with open(STATE_FILE, 'r') as f:
                    state = json.load(f)
            except Exception:
                break

            displays = state.get('displays', [])
            for d in displays:
                target = d.get('target_brightness', d.get('brightness', 50))
                last = d.get('last_written')
                if last != target:
                    try:
                        # Sequential write per display avoids EBUSY on shared GPU I2C adapters
                        subprocess.run(
                            ['ddcutil', 'setvcp', '10', str(target), '--display', str(d['display'])],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            timeout=4
                        )
                        d['last_written'] = target
                        d['brightness'] = target
                    except Exception:
                        pass

            save_state(state)

            # Check if any new target values arrived while we were writing to hardware
            try:
                with open(STATE_FILE, 'r') as f:
                    new_state = json.load(f)
                still_pending = False
                for d in new_state.get('displays', []):
                    if d.get('target_brightness') != d.get('last_written'):
                        still_pending = True
                if not still_pending:
                    break
            except Exception:
                break

            time.sleep(0.05)
    finally:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
        except Exception:
            pass
        os._exit(0)


def main():
    """
    Main command-line router supporting:
      - 'get' / 'json' : Output current display list and brightness as JSON
      - 'rescan'       : Force a hardware I2C re-probe
      - 'set_display'  : Set brightness for an individual display ID
      - 'set <val>'    : Set brightness for all displays (absolute or relative delta)
      - '<number>'     : Direct absolute value
      - '+5' / '-5'    : Relative step adjustments
    """
    if len(sys.argv) < 2:
        print(json.dumps(get_state()))
        return

    cmd = sys.argv[1]

    if cmd in ['get', 'json']:
        print(json.dumps(get_state()))

    elif cmd == 'rescan':
        print(json.dumps(get_state(force_rescan=True)))

    elif cmd == 'set_display' and len(sys.argv) >= 4:
        disp_id = int(sys.argv[2])
        val = max(0, min(100, int(sys.argv[3])))
        state = get_state()
        for d in state.get('displays', []):
            if d['display'] == disp_id:
                d['target_brightness'] = val
        save_state(state)
        spawn_single_worker()
        print(json.dumps(state))

    else:
        state = get_state()
        master = state.get('master', 50)

        # Parse absolute vs. relative target values
        if cmd == 'set' and len(sys.argv) >= 3:
            val_str = sys.argv[2]
            if val_str.startswith('+'):
                new_val = master + int(val_str[1:])
            elif val_str.startswith('-'):
                new_val = master - int(val_str[1:])
            elif val_str.isdigit():
                new_val = int(val_str)
            else:
                new_val = master
        elif cmd.isdigit():
            new_val = int(cmd)
        elif cmd in ['up', '+5']:
            new_val = master + 5
        elif cmd in ['down', '-5']:
            new_val = master - 5
        elif cmd.startswith('+'):
            new_val = master + int(cmd[1:])
        elif cmd.startswith('-'):
            new_val = master - int(cmd[1:])
        else:
            new_val = 50

        new_val = max(0, min(100, new_val))
        state['master'] = new_val
        for d in state.get('displays', []):
            d['target_brightness'] = new_val

        save_state(state)
        trigger_osd(new_val)
        spawn_single_worker()
        print(json.dumps(state))


if __name__ == '__main__':
    main()
