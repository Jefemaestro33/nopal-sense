# Nopal-Sense v1 — Testbench runner
# Usage: make all | make test_spi | make test_crc | make test_pulse | make clean

IVERILOG = iverilog
VVP = vvp
RTL = ../rtl
TB = .

.PHONY: all clean test_spi test_crc test_pulse test_onewire test_scheduler test_wake_timer test_cordic test_dds test_is_fsm test_alert test_calib test_mavg test_puf test_porbod test_sleepctrl test_spim test_i2c test_top

all: test_spi test_crc test_pulse test_onewire test_scheduler test_wake_timer test_cordic test_dds test_is_fsm test_alert test_calib test_mavg test_puf test_porbod test_sleepctrl test_spim test_i2c test_top

test_spi:
	@$(IVERILOG) -o tb_spi_reg $(TB)/tb_spi_reg.v $(RTL)/spi_slave.v $(RTL)/reg_bank.v
	@$(VVP) tb_spi_reg | grep -E "PASS|FAIL|\*\*\*"

test_crc:
	@$(IVERILOG) -o tb_crc16 $(TB)/tb_crc16.v $(RTL)/crc16.v
	@$(VVP) tb_crc16 | grep -E "PASS|FAIL|\*\*\*"

test_pulse:
	@$(IVERILOG) -o tb_pulse_counter $(TB)/tb_pulse_counter.v $(RTL)/pulse_counter.v
	@$(VVP) tb_pulse_counter | grep -E "PASS|FAIL|\*\*\*"

test_onewire:
	@$(IVERILOG) -o tb_onewire $(TB)/tb_onewire.v $(RTL)/onewire_master.v
	@$(VVP) tb_onewire | grep -E "PASS|FAIL|\*\*\*"

test_scheduler:
	@$(IVERILOG) -o tb_scheduler $(TB)/tb_scheduler.v $(RTL)/scheduler.v
	@$(VVP) tb_scheduler | grep -E "PASS|FAIL|\*\*\*"

test_wake_timer:
	@$(IVERILOG) -o tb_wake_timer $(TB)/tb_wake_timer.v $(RTL)/wake_timer.v
	@$(VVP) tb_wake_timer | grep -E "PASS|FAIL|\*\*\*"

test_cordic:
	@$(IVERILOG) -o tb_cordic $(TB)/tb_cordic.v $(RTL)/cordic.v
	@$(VVP) tb_cordic | grep -E "PASS|FAIL|\*\*\*"

test_dds:
	@$(IVERILOG) -o tb_dds $(TB)/tb_dds_control.v $(RTL)/dds_control.v
	@$(VVP) tb_dds | grep -E "PASS|FAIL|\*\*\*"

test_is_fsm:
	@$(IVERILOG) -o tb_is_fsm $(TB)/tb_is_fsm.v $(RTL)/is_fsm.v $(RTL)/cordic.v
	@$(VVP) tb_is_fsm | grep -E "PASS|FAIL|\*\*\*"

test_alert:
	@$(IVERILOG) -o tb_alert $(TB)/tb_alert_engine.v $(RTL)/alert_engine.v
	@$(VVP) tb_alert | grep -E "PASS|FAIL|\*\*\*"

test_calib:
	@$(IVERILOG) -o tb_calib $(TB)/tb_calibration.v $(RTL)/calibration.v
	@$(VVP) tb_calib | grep -E "PASS|FAIL|\*\*\*"

test_mavg:
	@$(IVERILOG) -o tb_mavg $(TB)/tb_moving_avg.v $(RTL)/moving_avg.v
	@$(VVP) tb_mavg | grep -E "PASS|FAIL|\*\*\*"

test_puf:
	@$(IVERILOG) -o tb_puf $(TB)/tb_puf.v $(RTL)/puf.v
	@$(VVP) tb_puf | grep -E "PASS|FAIL|\*\*\*"

test_porbod:
	@$(IVERILOG) -o tb_porbod $(TB)/tb_por_bod.v $(RTL)/por_bod.v
	@$(VVP) tb_porbod | grep -E "PASS|FAIL|\*\*\*"

test_sleepctrl:
	@$(IVERILOG) -o tb_sleepctrl $(TB)/tb_sleep_ctrl.v $(RTL)/sleep_ctrl.v
	@$(VVP) tb_sleepctrl | grep -E "PASS|FAIL|\*\*\*"

test_spim:
	@$(IVERILOG) -o tb_spim $(TB)/tb_spi_master.v $(RTL)/spi_master.v
	@$(VVP) tb_spim | grep -E "PASS|FAIL|\*\*\*"

test_i2c:
	@$(IVERILOG) -o tb_i2c $(TB)/tb_i2c_bitbang.v $(RTL)/i2c_bitbang.v
	@$(VVP) tb_i2c | grep -E "PASS|FAIL|\*\*\*"

test_top:
	@$(IVERILOG) -g2012 -o tb_top $(TB)/tb_chip_core.v $(RTL)/chip_core.sv \
	    $(RTL)/nopal_sense_top.v \
	    $(RTL)/spi_slave.v $(RTL)/reg_bank.v $(RTL)/scheduler.v \
	    $(RTL)/wake_timer.v $(RTL)/is_fsm.v $(RTL)/cordic.v \
	    $(RTL)/dds_control.v $(RTL)/alert_engine.v $(RTL)/puf.v \
	    $(RTL)/sleep_ctrl.v $(RTL)/spi_master.v $(RTL)/i2c_bitbang.v \
	    $(RTL)/onewire_master.v
	@$(VVP) tb_top | grep -E "PASS|FAIL|\*\*\*"

clean:
	rm -f tb_spi_reg tb_crc16 tb_pulse_counter tb_onewire tb_scheduler tb_wake_timer tb_cordic tb_dds tb_is_fsm tb_alert tb_calib tb_mavg tb_puf tb_porbod tb_sleepctrl tb_spim tb_i2c tb_top *.vcd
