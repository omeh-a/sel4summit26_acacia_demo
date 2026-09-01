#
# Copyright 2026, UNSW
#
# SPDX-License-Identifier: BSD-2-Clause
#

# this is to prevent needing to give sdk etc. for `make clean`
NO_CONFIG_GOALS := clean

SKIP_CONFIG :=
ifneq ($(strip $(MAKECMDGOALS)),)
ifeq ($(strip $(filter-out $(NO_CONFIG_GOALS),$(MAKECMDGOALS))),)
SKIP_CONFIG := 1
endif
endif

ifndef SKIP_CONFIG
ifeq ($(strip $(MICROKIT_SDK)),)
$(error MICROKIT_SDK must be specified)
endif
ifeq ($(strip $(MICROKIT_BOARD)),)
$(error MICROKIT_BOARD must be specified)
endif
endif
# </config skip>

BUILD_DIR ?= build
override BUILD_DIR := $(abspath ${BUILD_DIR})
export BUILD_DIR
export SDDF := $(abspath ./sddf)
export ACACIA := $(abspath ./acacia)
export TOP := $(abspath ./)
override MICROKIT_SDK := $(abspath ${MICROKIT_SDK})
PYTHON ?= python3
export PYTHON

IMAGE_FILE := ${BUILD_DIR}/loader.img
REPORT_FILE := ${BUILD_DIR}/report.txt

all: ${IMAGE_FILE}

.PHONY: all qemu clean clobber

sddf:
	./dependencies.sh sddf

acacia:
	./dependencies.sh acacia

qemu ${IMAGE_FILE} ${REPORT_FILE} clean clobber: ${BUILD_DIR}/Makefile FORCE
	${MAKE} -C ${BUILD_DIR}  MICROKIT_SDK=${MICROKIT_SDK} $(notdir $@)

${BUILD_DIR}/Makefile: acaciademo.mk sddf acacia
	mkdir -p ${BUILD_DIR}
	cp acaciademo.mk $@

clean:
	rm -rf sddf acacia ${BUILD_DIR}

FORCE:
