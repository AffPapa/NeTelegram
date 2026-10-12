#ifndef NETELEGRAM_TDLIB_C_BRIDGE_H
#define NETELEGRAM_TDLIB_C_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

int nt_tdlib_load(const char *library_path, char *error_buffer, size_t error_capacity);
int32_t nt_tdlib_create_client_id(void);
int nt_tdlib_send(int32_t client_id, const char *request);
char *nt_tdlib_receive_copy(double timeout_seconds);
void nt_tdlib_free(void *buffer);

#endif
