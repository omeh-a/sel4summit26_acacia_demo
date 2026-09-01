#
# Copyright 2026, UNSW
#
# SPDX-License-Identifier: BSD-2-Clause
#
# This Makefile is copied into the build directory
# and operated on from there.
#

ifeq ($(strip $(MICROKIT_SDK)),)
$(error MICROKIT_SDK must be specified)
endif

ifeq ($(strip $(SDDF)),)
$(error SDDF must be specified)
endif

ifeq ($(strip $(PYTHON)),)
$(error PYTHON must be specified)
endif

IMAGE_FILE = loader.img
REPORT_FILE = report.txt
BUILD_DIR ?= build
MICROKIT_CONFIG ?= debug
TOOLCHAIN ?= clang

SUPPORTED_BOARDS:= qemu_virt_aarch64 \
		   qemu_virt_riscv64 \
		   x86_64_generic

include ${SDDF}/tools/make/board/common.mk

METAPROGRAM := $(TOP)/meta.py
UTIL := $(SDDF)/util
SERIAL_COMPONENTS := $(SDDF)/serial/components
UART_DRIVER := $(SDDF)/drivers/serial/$(UART_DRIV_DIR)
TIMER_DRIVER := $(SDDF)/drivers/timer/$(TIMER_DRIV_DIR)
SYSTEM_FILE := acaciademo.system
SDDF_CUSTOM_LIBC := 1

IMAGES := serial_driver.elf \
	  timer_driver.elf \
	  client.elf \
	  serial_virt_tx.elf serial_virt_rx.elf \
	  secretserial.elf secretserver.elf

CFLAGS +=  -Wno-unused-function -Werror

LDFLAGS := -L$(BOARD_DIR)/lib -L$(SDDF)/lib
LIBS := --start-group -lmicrokit -Tmicrokit.ld libsddf_util_debug.a --end-group

CFLAGS += \
	-I${TOP}/include \
	-I${SDDF}/include \
	-I${SDDF}/include/microkit

${IMAGES}: libsddf_util_debug.a

include ${SDDF}/util/util.mk
include ${UART_DRIVER}/serial_driver.mk
include ${TIMER_DRIVER}/timer_driver.mk
include ${SERIAL_COMPONENTS}/serial_components.mk

client.elf: client.o libsddf_util.a
	$(LD) $(LDFLAGS) $^ $(LIBS) -o $@

client.o: ${TOP}/client.c
	$(CC) $(CFLAGS) -c -o $@ $<

secretserial.elf: secretserial.o libsddf_util.a
	$(LD) $(LDFLAGS) $^ $(LIBS) -o $@

secretserial.o: ${TOP}/secretserial.c
	$(CC) $(CFLAGS) -c -o $@ $<

secretserver.elf: secretserver.o libsddf_util.a
	$(LD) $(LDFLAGS) $^ $(LIBS) -o $@

secretserver.o: ${TOP}/secretserver.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(SYSTEM_FILE): $(METAPROGRAM) $(IMAGES) $(DTB)
	cp client.elf client0.elf
	cp client.elf client1.elf
ifneq ($(strip $(DTS)),)
	$(PYTHON) $(METAPROGRAM) --board $(MICROKIT_BOARD) --dtb $(DTB) --output . --sdf $(SYSTEM_FILE)
else
	$(PYTHON) $(METAPROGRAM) --sddf $(SDDF) --board $(MICROKIT_BOARD) --output . --sdf $(SYSTEM_FILE)
endif
	$(OBJCOPY) --update-section .device_resources=serial_driver_device_resources.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_driver_config=serial_driver_serial_driver_config.data serial_driver.elf
	$(OBJCOPY) --update-section .serial_virt_rx_config=serial_virt_rx_serial_virt_rx_config.data serial_virt_rx.elf
	$(OBJCOPY) --update-section .serial_virt_tx_config=serial_virt_tx_serial_virt_tx_config.data serial_virt_tx.elf
	$(OBJCOPY) --update-section .serial_client_config=client0_serial_client_config.data client0.elf
	$(OBJCOPY) --update-section .serial_client_config=client1_serial_client_config.data client1.elf
	$(OBJCOPY) --update-section .serial_client_config=secretserver_serial_client_config.data secretserver.elf
	$(OBJCOPY) --update-section .serial_client_config=secretserial_serial_client_config.data secretserial.elf
	$(OBJCOPY) --update-section .secretserial_config=secretserial_secretserial_config.data secretserial.elf
	$(OBJCOPY) --update-section .secretserver_config=secretserver_secretserver_config.data secretserver.elf
	$(OBJCOPY) --update-section .device_resources=timer_driver_device_resources.data timer_driver.elf
	$(OBJCOPY) --update-section .timer_client_config=secretserver_timer_client_config.data secretserver.elf
	touch $@

$(IMAGE_FILE) $(REPORT_FILE): $(IMAGES) $(SYSTEM_FILE)
	MICROKIT_SDK=${MICROKIT_SDK} $(MICROKIT_TOOL) $(SYSTEM_FILE) --search-path $(BUILD_DIR) --board $(MICROKIT_BOARD) --config $(MICROKIT_CONFIG) -o $(IMAGE_FILE) -r $(REPORT_FILE)

qemu: ${IMAGE_FILE}
	$(QEMU) -nographic -d guest_errors $(QEMU_ARCH_ARGS)

clean::
	${RM} -f *.elf
	find . -name '*.[od]' | xargs ${RM} -f

clobber:: clean
	${RM} -f ${IMAGE_FILE} ${REPORT_FILE}
