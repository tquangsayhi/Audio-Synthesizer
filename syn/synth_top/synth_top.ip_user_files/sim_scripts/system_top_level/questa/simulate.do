onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib system_top_level_opt

do {wave.do}

view wave
view structure
view signals

do {system_top_level.udo}

run -all

quit -force
