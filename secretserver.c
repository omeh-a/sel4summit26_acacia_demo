/*
 * Copyright 2026, UNSW
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdint.h>
#include <os/sddf.h>
#include <sddf/serial/queue.h>
#include <sddf/serial/config.h>
#include <sddf/util/printf.h>
#include <sddf/timer/client.h>
#include <sddf/timer/config.h>

#define MAX_KEY_SZ (20)

typedef struct secretserver_config {
    char *key_share_page;
    size_t key_share_page_sz;
    char key[200];
    char secret[200];
    uint32_t client_ids[62];
    size_t num_clients;
    uint64_t timeout_ns;
} secretserver_config_t;

__attribute__((__section__(".timer_client_config"))) timer_client_config_t timer_config;
__attribute__((__section__(".serial_client_config"))) serial_client_config_t serial_config;
__attribute__((__section__(".secretserver_config"))) secretserver_config_t s_config;

serial_queue_handle_t tx_queue_handle;

void init(void)
{
    assert(serial_config_check_magic(&serial_config));

    serial_queue_init(&tx_queue_handle, serial_config.tx.queue.vaddr, serial_config.tx.data.size, serial_config.tx.data.vaddr);
    assert(timer_config_check_magic(&timer_config));

    serial_putchar_init(serial_config.tx.id, &tx_queue_handle);
    sddf_printf("(%s) Awaiting key challenge\n", sddf_get_pd_name());
}

void notified(sddf_channel ch)
{
}

static inline void punish(void)
{
    sddf_printf("(%s) Bad key! Timing out...\n", sddf_get_pd_name());
    uint64_t wait_start = sddf_timer_time_now(timer_config.driver_id);
    uint64_t wait_end = wait_start + s_config.timeout_ns;

    // Do a nasty busy wait to keep things simple
    while (sddf_timer_time_now(timer_config.driver_id) < wait_end) {
        for (int i = 0; i < (1 << 16); i++) {}
    }
    sddf_printf("(%s) Wait elapsed.\n", sddf_get_pd_name());
}

static inline void success(void) {
    // Print secret & kick serial server to make sure we print now.
    sddf_printf("(%s) SECRET=%s\n", sddf_get_pd_name(), s_config.secret);
    microkit_notify(serial_config.tx.id);

    // Notify clients!
    for (size_t i=0; i < s_config.num_clients; i++) {
        microkit_notify(s_config.client_ids[i]);
    }
}

seL4_MessageInfo_t protected(sddf_channel ch, seL4_MessageInfo_t msginfo)
{
    uint16_t len = (uint16_t)seL4_MessageInfo_get_label(msginfo);
    char key[MAX_KEY_SZ + 1];
    size_t i;

    if (len == 0 || len > MAX_KEY_SZ || (size_t)len + 1 > s_config.key_share_page_sz) {
        punish();
        return seL4_MessageInfo_new(0, 0, 0, 0);
    }

    memcpy(key, s_config.key_share_page, len);
    key[len] = '\0';

    // Check key
    for (i = 0; i < len; i++) {
        if (key[i] != s_config.key[i]) {
            punish();
            return seL4_MessageInfo_new(0, 0, 0, 0);
        }
    }

    // Expected key longer than the candidate -> obviously wrong
    if (s_config.key[len] != '\0') {
        punish();
        return seL4_MessageInfo_new(0, 0, 0, 0);
    }

    success();
    return seL4_MessageInfo_new(0, 0, 0, 0);
}
