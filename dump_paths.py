import sys
import re

paths = {}
scope = []
time = -1
values = {}

with open('formal/arbiter_bmc/engine_0/trace.vcd', 'r') as f:
    for line in f:
        line = line.strip()
        if line.startswith('$scope'):
            scope.append(line.split()[2])
        elif line.startswith('$upscope'):
            if scope: scope.pop()
        elif line.startswith('$var'):
            parts = line.split()
            vid = parts[3]
            name = parts[4]
            if name in ['r_resp_phase', 'r_state', 'r_target_invalid', 'w_state', 'w_resp_phase', 'r_owner_id', 'w_owner_id', 's_axi_rvalid', 's_axi_bvalid', 'm_rvalid', 'decerr_rvalid']:
                full_path = '.'.join(scope) + '.' + name
                paths[vid] = full_path
                values[vid] = []
        elif line.startswith('#'):
            time = int(line[1:])
        elif len(line) > 0 and line[0] in '01xXzZ':
            if ' ' in line:
                val, vid = line.split(' ')
            else:
                val, vid = line[0], line[1:]
            if vid in paths:
                values[vid].append(f'T{time}:{val}')
        elif line.startswith('b') and ' ' in line:
            val, vid = line.split(' ')
            if vid in paths:
                values[vid].append(f'T{time}:{val}')

for vid, path in paths.items():
    print(f"{path} (ID: {vid}): {values[vid]}")
