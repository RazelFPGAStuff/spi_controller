onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider internal_sig
add wave -noupdate /spi_tb/clk
add wave -noupdate /spi_tb/reset
add wave -noupdate /spi_tb/EN
add wave -noupdate /spi_tb/RdWr
add wave -noupdate /spi_tb/SDO
add wave -noupdate /spi_tb/regAddress
add wave -noupdate /spi_tb/writeData
add wave -noupdate /spi_tb/CS
add wave -noupdate /spi_tb/SPC
add wave -noupdate /spi_tb/SDI
add wave -noupdate -expand /spi_tb/readData
add wave -noupdate /spi_tb/dataReady
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1007 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {42 us}
