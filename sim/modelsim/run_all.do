vlib work
vcom -93 -work work -f sim/filelist.f

set fp [open "sim/tb_list.txt" r]
set tbs [read $fp]
close $fp

foreach tb $tbs {
    if {$tb ne ""} {
        puts "=== Running $tb ==="
        vsim -t ps work.$tb
        run -all
        quit -sim
    }
}