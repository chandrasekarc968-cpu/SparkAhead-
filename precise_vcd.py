import sys

events = {}
signals = {}
with open('formal/arbiter_bmc/engine_0/trace.vcd', 'r') as f:
    for line in f:
        line = line.strip()
        if line.startswith('$var'):
            parts = line.split()
            signals[parts[3]] = parts[4]
        elif line.startswith('#'):
            time = int(line[1:])
            if time not in events: events[time] = {}
        elif line.startswith('b'):
            parts = line.split(' ')
            if len(parts) >= 2 and parts[1] in signals:
                events[time][signals[parts[1]]] = parts[0]
        elif len(line) == 2 and line[0] in '01xXzZ':
            if line[1] in signals:
                events[time][signals[line[1]]] = line[0]

state = {}
for t in sorted(events.keys())[6:12]:
    print(f'--- Time {t} ---')
    state.update(events[t])
    for k, v in state.items():
        if k in ['w_owner_id', 'r_owner_id', 'w_state', 'r_state', 'aresetn', 'f_reset_count', 'f_active']:
            print(f'  {k} = {v}')
