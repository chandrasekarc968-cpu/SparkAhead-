with open('formal/arbiter_bmc/engine_0/trace.vcd', 'r') as f:
    scope = []
    for line in f:
        line = line.strip()
        if line.startswith('$scope'):
            scope.append(line.split()[2])
        elif line.startswith('$upscope'):
            if scope: scope.pop()
        elif 'n481' in line and line.startswith('$var'):
            print('Scope of n481:', '.'.join(scope))
            print(line)
        elif line.startswith('$enddefinitions'):
            break
