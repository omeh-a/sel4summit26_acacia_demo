/*
 * Copyright 2026, UNSW
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <os/sddf.h>
#include <stdint.h>
#include <sddf/serial/queue.h>
#include <sddf/serial/config.h>
#include <sddf/util/printf.h>

#define MAX_KEY_SZ (20)

typedef struct secretserial_config {
    uint32_t secretserver_id;
    char *key_share_page;
    size_t key_share_page_sz;
} secretserial_config_t;

__attribute__((__section__(".serial_client_config"))) serial_client_config_t serial_config;
__attribute__((__section__(".secretserial_config"))) secretserial_config_t s_config;

serial_queue_handle_t rx_queue_handle;
serial_queue_handle_t tx_queue_handle;
static char key_buf[MAX_KEY_SZ];
static uint16_t char_count;

void init(void)
{
    assert(serial_config_check_magic(&serial_config));
    serial_queue_init(&rx_queue_handle, serial_config.rx.queue.vaddr, serial_config.rx.data.size, serial_config.rx.data.vaddr);
    serial_queue_init(&tx_queue_handle, serial_config.tx.queue.vaddr, serial_config.tx.data.size, serial_config.tx.data.vaddr);
    serial_putchar_init(serial_config.tx.id, &tx_queue_handle);
    sddf_printf("(%s) Enter key...\n", sddf_get_pd_name());
}

static void submit_key(const char *buf, uint16_t len)
{
    char key[MAX_KEY_SZ + 1];
    uint16_t i;

    for (i = 0; i < len; i++) {
        key[i] = buf[i];
    }
    key[len] = '\0';

    sddf_printf("\n(%s) captured key (%u chars): '%s'\n", sddf_get_pd_name(), len, key);

    // send to secret server using key share page; ppc to tell server to check it. we want to
    // block if the server times out.
    memcpy(s_config.key_share_page, buf, (unsigned long)len);
    microkit_msginfo msginfo = microkit_msginfo_new(len, 0);
    microkit_ppcall(s_config.secretserver_id, msginfo);
}

void notified(sddf_channel ch)
{
    char c;

    while (!serial_dequeue(&rx_queue_handle, &c)) {
        if (c == '\r') {
            if (char_count > 0) {
                submit_key(key_buf, char_count);
            }
            char_count = 0;
            continue;
        }

        // ignore first half of crlf
        if (c == '\n') {
            continue;
        }

        if (char_count < MAX_KEY_SZ) {
            key_buf[char_count++] = c;
            sddf_putchar_unbuffered(c);
        }
        // else: MAX_KEY_SZ chars already, do nothing
    }
}
