import sys

def parse_vcd(vcd_path):
    with open(vcd_path, 'r') as f:
        lines = f.readlines()
    
    signals = {}
    time = -1
    
    for line in lines:
        line = line.strip()
        if line.startswith('$var'):
            parts = line.split()
            var_id = parts[3]
            var_name = parts[4]
            signals[var_id] = {'name': var_name, 'values': []}
        elif line.startswith('#'):
            time = int(line[1:])
        elif line.startswith('b'):
            parts = line.split(' ')
            if len(parts) >= 2:
                val, var_id = parts[0], parts[1]
                if var_id in signals:
                    signals[var_id]['values'].append((time, val))
        elif len(line) == 2 and line[0] in '01xXzZ':
            val, var_id = line[0], line[1]
            if var_id in signals:
                signals[var_id]['values'].append((time, val))

    for vid, data in signals.items():
        name = data['name']
        if name in ['w_state', 'owner_id_r', 'aresetn', 'f_reset_count', 'f_active']:
            print(f"{vid} ({name}): {data['values']}")

parse_vcd('formal/arbiter_bmc/engine_0/trace.vcd')
