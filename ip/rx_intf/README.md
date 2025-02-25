
# make verilator run

## fix missing def file 

run `tclsh side_ch.tcl`
```
# generate below 
src/fpga_scale.v
src/has_side_ch_flag.v
src/side_ch_pre_def.v

## generate filelist.f

from the rx_intf.tcl , you can get 
```
set obj [get_filesets sources_1]
set files [list \
 "[file normalize "$origin_dir/src/adc_intf.v"]"\
 "[file normalize "$origin_dir/src/byte_to_word_fcs_sn_insert.v"]"\
 "[file normalize "$origin_dir/src/gpio_status_rf_to_bb.v"]"\
 "[file normalize "$origin_dir/src/mv_avg_dual_ch.v"]"\
 "[file normalize "$origin_dir/src/rx_intf_m_axis.v"]"\
 "[file normalize "$origin_dir/src/rx_intf_pl_to_m_axis.v"]"\
 "[file normalize "$origin_dir/src/rx_intf_s_axi.v"]"\
 "[file normalize "$origin_dir/src/rx_iq_intf.v"]"\
 "[file normalize "$origin_dir/src/edge_to_flip.v"]"\
 "[file normalize "$origin_dir/src/rx_intf.v"]"\
]
add_files -norecurse -fileset $obj $files
```


## fix missing `src/lib/xpm_fifo_sync.v`
run and copy for backup
```
# get verilator_ast.txt
bash ./run_verilator.sh

# then copy obj/V<module_i>.xml
cp obj_dir/Vside_ch.xml verilator_ast.xml


```

summary
```
   620 verilator_ast.txt
  7562 verilator_ast.xml
  8182 total
```
