/*
 * Copyright 2026, UNSW
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <os/sddf.h>
#include <sddf/serial/queue.h>
#include <sddf/serial/config.h>
#include <sddf/util/printf.h>

__attribute__((__section__(".serial_client_config"))) serial_client_config_t config;

serial_queue_handle_t tx_queue_handle;

void init(void)
{
    assert(serial_config_check_magic(&config));
    serial_queue_init(&tx_queue_handle, config.tx.queue.vaddr, config.tx.data.size, config.tx.data.vaddr);
    serial_putchar_init(config.tx.id, &tx_queue_handle);
}

uint16_t char_count;
void notified(sddf_channel ch)
{
    if (ch != config.tx.id)
        sddf_printf("(%s) It worked!\n", sddf_get_pd_name());
}
