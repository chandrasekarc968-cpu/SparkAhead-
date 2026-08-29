import os

def replace_in_file(filepath, old, new):
    with open(filepath, 'r') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(filepath, 'w') as f:
        f.write(content)

replace_in_file('src/rtl/write_arbiter.sv', 'target_slave_r', 'w_target_slave_r')
replace_in_file('src/rtl/write_arbiter.sv', 'target_invalid_r', 'w_target_invalid_r')

replace_in_file('src/rtl/read_arbiter.sv', 'owner_id_r', 'r_owner_id_r')
replace_in_file('src/rtl/read_arbiter.sv', 'target_slave_r', 'r_target_slave_r')
replace_in_file('src/rtl/read_arbiter.sv', 'target_invalid_r', 'r_target_invalid_r')

replace_in_file('formal/arbiter_formal.sv', 'dut.u_write_arbiter.owner_id_r', 'dut.u_write_arbiter.w_owner_id_r')
replace_in_file('formal/arbiter_formal.sv', 'dut.u_write_arbiter.target_slave_r', 'dut.u_write_arbiter.w_target_slave_r')
replace_in_file('formal/arbiter_formal.sv', 'dut.u_write_arbiter.target_invalid_r', 'dut.u_write_arbiter.w_target_invalid_r')

replace_in_file('formal/arbiter_formal.sv', 'dut.u_read_arbiter.owner_id_r', 'dut.u_read_arbiter.r_owner_id_r')
replace_in_file('formal/arbiter_formal.sv', 'dut.u_read_arbiter.target_slave_r', 'dut.u_read_arbiter.r_target_slave_r')
replace_in_file('formal/arbiter_formal.sv', 'dut.u_read_arbiter.target_invalid_r', 'dut.u_read_arbiter.r_target_invalid_r')

print("Renamed variables.")
