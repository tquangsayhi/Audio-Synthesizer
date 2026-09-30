onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+system_top_level -L xil_defaultlib -L util_vector_logic_v2_0_1 -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.system_top_level xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {system_top_level.udo}

run -all

endsim

quit -force
