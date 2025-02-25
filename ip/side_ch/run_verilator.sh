verilator -E --timing -Wno-IMPLICIT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -I./rtl -I./rtl/lib -I./src -I./src/lib -f filelist.f > verilator_ast.txt
verilator --xml-only --timing -Wno-IMPLICIT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -I./rtl -I./rtl/lib -I./src -I./src/lib -f filelist.f
