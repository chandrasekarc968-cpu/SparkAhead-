import sys

targets = ["r_resp_phase", "r_state", "r_owner_id", "s_axi_rvalid", "r_owner_id_r", "r_target_invalid", "r_target_invalid_r"]
id_to_name = {}

with open("formal/arbiter_bmc/engine_0/trace.vcd", "r") as f:
    for line in f:
        line = line.strip()
        if line.startswith("$var"):
            parts = line.split()
            vid = parts[3]
            name = parts[4]
            if name in targets:
                id_to_name[vid] = name

time = 0
vals = {}
history = {}

with open("formal/arbiter_bmc/engine_0/trace.vcd", "r") as f:
    for line in f:
        line = line.strip()
        if line.startswith("#"):
            if time not in history:
                history[time] = {}
            history[time].update({id_to_name[k]: v for k, v in vals.items() if k in id_to_name})
            time = int(line[1:])
        elif len(line) > 0 and line[0] in "01xXzZ":
            if " " in line:
                val, vid = line.split(" ")
                if vid in id_to_name:
                    vals[vid] = val
            else:
                val, vid = line[0], line[1:]
                if vid in id_to_name:
                    vals[vid] = val

if time not in history:
    history[time] = {}
history[time].update({id_to_name[k]: v for k, v in vals.items() if k in id_to_name})

for t in sorted(history.keys()):
    print(f"Time {t}: {history[t]}")
