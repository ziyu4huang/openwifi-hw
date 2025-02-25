
# make verilator run

## fix missing def file 

run `tclsh side_ch.tcl`
```
# generate below 
src/fpga_scale.v
src/has_side_ch_flag.v
src/side_ch_pre_def.v
```

## fix missing `src/lib/xpm_fifo_sync.v`

use copilot

## fix ERROR

below is github link and the prompt for generate src/lib/_dummy.v_

[create dummy module verilog for this instance](https://github.com/ziyu4huang/openwifi-hw/blob/8bfa4625e53d89559beedb650ed73e57d1470f8d/ip/tx_intf/src/tx_bit_intf.v#L1112-L1181)

[create dummy module for xpm_cdc_array_singleinstance](https://github.com/ziyu4huang/openwifi-hw/blob/8bfa4625e53d89559beedb650ed73e57d1470f8d/ip/tx_intf/src/dac_intf.v#L127-L153)

[create dummy module verilog for this instance](https://github.com/ziyu4huang/openwifi-hw/blob/8bfa4625e53d89559beedb650ed73e57d1470f8d/ip/rx_intf/src/gpio_status_rf_to_bb.v#L33-L79)
> create xpm_fifo_async.v  follow the definition of /gpio_status_rf_to_bb.v#L33-L79

```
%Error: src/tx_bit_intf.v:1112:5: Cannot find file containing module: 'xpm_memory_tdpram'
 1112 |     xpm_memory_tdpram # (
      |     ^~~~~~~~~~~~~~~~~
        src/tx_intf.v:478:1: ... note: In file included from 'tx_intf.v'
        ... Looked in:
             rtl/xpm_memory_tdpram
             rtl/xpm_memory_tdpram.v
             rtl/xpm_memory_tdpram.sv
             rtl/lib/xpm_memory_tdpram
             rtl/lib/xpm_memory_tdpram.v
             rtl/lib/xpm_memory_tdpram.sv
             src/xpm_memory_tdpram
             src/xpm_memory_tdpram.v
             src/xpm_memory_tdpram.sv
             src/lib/xpm_memory_tdpram
             src/lib/xpm_memory_tdpram.v
             src/lib/xpm_memory_tdpram.sv
             xpm_memory_tdpram
             xpm_memory_tdpram.v
             xpm_memory_tdpram.sv
             obj_dir/xpm_memory_tdpram
             obj_dir/xpm_memory_tdpram.v
             obj_dir/xpm_memory_tdpram.sv
%Error: src/dac_intf.v:127:5: Cannot find file containing module: 'xpm_cdc_array_single'
  127 |     xpm_cdc_array_single #(
      |     ^~~~~~~~~~~~~~~~~~~~
        src/tx_intf.v:295:1: ... note: In file included from 'tx_intf.v'
%Error: src/dac_intf.v:141:5: Cannot find file containing module: 'xpm_cdc_array_single'
  141 |     xpm_cdc_array_single #(
      |     ^~~~~~~~~~~~~~~~~~~~
        src/tx_intf.v:295:1: ... note: In file included from 'tx_intf.v'
%Error: src/dac_intf.v:155:4: Cannot find file containing module: 'xpm_fifo_async'
  155 |    xpm_fifo_async #(
      |    ^~~~~~~~~~~~~~
        src/tx_intf.v:295:1: ... note: In file included from 'tx_intf.v'
%Error: Exiting due to 4 error(s), 2 warning(s)
```


## generate AST
run and copy for backup
```
# get verilator_ast.txt
bash ./run_verilator.sh

# then copy obj/V<module_i>.xml
cp obj_dir/Vside_ch.xml verilator_ast.xml


```

summary
```
 11476 obj_dir/Vtx_intf.xml
   663 verilator_ast.txt
 12139 total
```
