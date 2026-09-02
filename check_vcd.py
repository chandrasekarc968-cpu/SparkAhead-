with open('formal/arbiter_bmc/engine_0/trace.vcd') as f:
    lines = f.readlines()
    for i, line in enumerate(lines):
        if 'n198 ' in line or 'n164 ' in line or 'n197 ' in line or 'n147 ' in line:
            if not line.startswith('$var'):
                print(f'Line {i+1}: {line.strip()}')
