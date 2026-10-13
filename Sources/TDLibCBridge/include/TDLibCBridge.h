#ifndef NETELEGRAM_TDLIB_C_BRIDGE_H
#define NETELEGRAM_TDLIB_C_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

int nt_tdlib_load(const char *library_path, char *error_buffer, size_t error_capacity);
int32_t nt_tdlib_create_client_id(void);
int nt_tdlib_send(int32_t client_id, const char *request);
typedef enum nt_tdlib_receive_status {
    NT_TDLIB_RECEIVE_ERROR = -1,
    NT_TDLIB_RECEIVE_TIMEOUT = 0,
    NT_TDLIB_RECEIVE_UPDATE = 1,
    NT_TDLIB_RECEIVE_TOO_LARGE = 2
} nt_tdlib_receive_status;

nt_tdlib_receive_status nt_tdlib_receive_copy(double timeout_seconds, size_t maximum_bytes, char **output, size_t *actual_bytes);
void nt_tdlib_free(void *buffer);

int nt_lock_file_exclusive(int file_descriptor);
void nt_unlock_file(int file_descriptor);

#endif
