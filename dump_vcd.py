import sys
import re

def parse_vcd(vcd_path):
    signals = {}
    time = 0
    with open(vcd_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('$var'):
                parts = line.split()
                var_type = parts[1]
                size = parts[2]
                code = parts[3]
                name = parts[4]
                signals[code] = {'name': name, 'size': size, 'values': []}
            elif line.startswith('#'):
                time = int(line[1:])
            elif line.startswith('b'):
                parts = line.split()
                val = parts[0][1:]
                code = parts[1]
                if code in signals:
                    signals[code]['values'].append((time, val))
            elif len(line) >= 2 and line[0] in ['0', '1', 'x', 'z']:
                val = line[0]
                code = line[1:]
                if code in signals:
                    signals[code]['values'].append((time, val))
    return signals

def print_sig(signals, sig_name):
    for code, sig in signals.items():
        if sig_name in sig['name']:
            print(f"Signal: {sig['name']} (Code: {code})")
            for t, v in sig['values']:
                print(f"  Time {t}: {v}")

signals = parse_vcd('formal/arbiter_bmc/engine_0/trace.vcd')
print_sig(signals, 'm_axi_arvalid')
print_sig(signals, 'r_target_slave_r')
print_sig(signals, 'r_state')
print_sig(signals, 'slave_sel')
print_sig(signals, 'target_invalid')
print_sig(signals, 'aresetn')
