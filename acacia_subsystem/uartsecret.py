from re import A
from socket import timeout
from typing import override

from acacia_sddf import sDDFSerial

from acacia import (
    Channel,
    ConfigStruct,
    Map,
    MemoryRegion,
    ProtectionDomain,
    Subsystem,
    System,
)

SECRET_PAGE_SZ = 0x1000
MAX_CLIENTS = 62


class UartSecretSystem(Subsystem):
    def __init__(
        self,
        sdf: System,
        serial: sDDFSerial,
        timer: sDDFTimer,
        key: str,
        secret: str,
        timeout_secs: int = 5,
        secret_elf: str = "secretserver.elf",
        serialserver_elf: str = "secretserial.elf",
    ):
        self.key = key
        self.secret = secret
        self.timeout = timeout_secs

        # Initialise subsystem
        super().__init__(sdf, f"uartsecret_{key}", True)

        # Create PDs
        self.secretserver = ProtectionDomain(
            sdf, f"{self.name}_secret", secret_elf, priority=50
        )
        self.serialserver = ProtectionDomain(
            sdf, f"{self.name}_serial", serialserver_elf, priority=49
        )

        # Create channel between PDs
        self.secret_ch = Channel(
            self.sdf,  # set by super()
            Channel.End(self.serialserver, can_notify=False, can_pp=True),
            Channel.End(self.secretserver, can_notify=False, can_pp=False),
        )

        # Create shared memory region between PDs and map it into each
        secret_mr = MemoryRegion(sdf, f"{self.name}_secret", SECRET_PAGE_SZ)

        # Automap maps region into vspace of PD and returns the map object.
        self.secretserver_vaddr = self.secretserver.create_automap(secret_mr, "r").vaddr
        self.serialserver_vaddr = self.serialserver.create_automap(
            secret_mr, "rw"
        ).vaddr

        # Add servers as clients to drivers
        timer.add_client(self.secretserver)
        serial.add_client(self.serialserver)
        serial.add_client(self.secretserver)

    def connect_clients(self):
        # Create a channel to each client for the secret server to notify them.
        # Only store the channel ID of the client seen by secretserver, since we
        # don't need the channel object itself (stored in self.sdf!)
        self.client_channel_ids: List[int] = [
            Channel(
                self.sdf,
                Channel.End(self.secretserver, can_pp=False, can_notify=True),
                Channel.End(c, can_pp=False, can_notify=True),
            ).id_for_pd(self.secretserver)
            for c in self.clients
        ]

    def generate_config_structs(self) -> List["ConfigStruct"]:
        # We need:
        # a) secret server config
        # b) serial server config
        serial_config = ConfigStruct(
            {
                "secretserver_id": self.secret_ch.id_for_pd(self.serialserver),
                "key_share_page": self.serialserver_vaddr,
                "key_share_page_sz": SECRET_PAGE_SZ,
            },
            type_name="secretserial_config_t",
            section_name="secretserial_config",
            target_file=self.serialserver.prog_image,
        )
        secret_config = ConfigStruct(
            {
                "key": self.key,
                "key_share_page": self.secretserver_vaddr,
                "key_share_page_sz": SECRET_PAGE_SZ,
                "secret": self.secret,
                "client_ids": sorted(self.client_channel_ids),
                "num_clients": len(self.clients),
                "timeout_ns": self.timeout * 1000000000,
            },
            type_name="secretserver_config_t",
            section_name="secretserver_config",
            target_file=self.secretserver.prog_image,
        )
        return super().generate_config_structs() + [serial_config, secret_config]
