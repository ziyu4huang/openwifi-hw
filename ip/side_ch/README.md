
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
