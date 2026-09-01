# Copyright 2025, UNSW
# SPDX-License-Identifier: BSD-2-Clause
import argparse
import os
import sys
from dataclasses import dataclass
from typing import List

# Add local Acacia module, sDDF Acacia module and Acacia itself
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "acacia"))
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), "sddf"))
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from acacia.arch import x86_64
from acacia_sddf import BOARDS, sDDFSerial, sDDFTimer

from acacia import DeviceTreeBlob, ProtectionDomain, System
from acacia_subsystem.uartsecret import UartSecretSystem


def generate(sdf_file: str, output_dir: str):
    client0 = ProtectionDomain(sdf, "client0", "client0.elf", priority=1)
    client1 = ProtectionDomain(sdf, "client1", "client1.elf", priority=1)

    serial = sDDFSerial(
        sdf,
        board.serial.compatible,
        board.serial.node_path,
        driver_prio=200,
        virt_tx_prio=199,
        allow_rx=True,
        enable_color=True,
        baud_rate=board.baud_rate if board.baud_rate else 115200,
    )
    timer = sDDFTimer(sdf, board.timer.compatible, board.timer.node_path)
    secret_a = UartSecretSystem(
        sdf, serial, timer, key="security", secret="is no excuse for poor performance!"
    )

    for pd in [client0, client1]:
        secret_a.add_client(pd)
        serial.add_client(pd, allow_rx=False, allow_tx=True)

    sdf.make_config_structs()
    out_file = f"{output_dir}/{sdf_file}"
    print(f"Saving to {out_file}")
    sdf.write_xml_file(out_file)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dtb", required=False)
    parser.add_argument("--board", required=True, choices=[b.name for b in BOARDS])
    parser.add_argument("--output", required=True)
    parser.add_argument("--sdf", required=True)

    args = parser.parse_args()

    board = next(filter(lambda b: b.name == args.board, BOARDS))

    if board.arch == x86_64:
        dtb = None  # x86 has no DTB.
        raise NotImplementedError("This demo hasn't been tested with x86!")
    dtb = DeviceTreeBlob(args.dtb)
    sdf = System(board.arch, board.paddr_top, dtb)

    generate(args.sdf, args.output)
