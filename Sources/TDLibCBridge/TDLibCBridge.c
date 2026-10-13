#include "TDLibCBridge.h"

#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef int (*create_client_id_fn)(void);
typedef void (*send_fn)(int, const char *);
typedef const char *(*receive_fn)(double);

static pthread_mutex_t load_mutex = PTHREAD_MUTEX_INITIALIZER;
static void *tdlib_handle;
static char *loaded_path;
static create_client_id_fn create_client_id;
static send_fn send_request;
static receive_fn receive_update;

static void set_error(char *buffer, size_t capacity, const char *message) {
    if (buffer != NULL && capacity > 0) {
        snprintf(buffer, capacity, "%s", message != NULL ? message : "unknown dynamic loader error");
    }
}

int nt_tdlib_load(const char *library_path, char *error_buffer, size_t error_capacity) {
    if (library_path == NULL || library_path[0] == '\0') {
        set_error(error_buffer, error_capacity, "TDLib library path is empty");
        return 0;
    }

    pthread_mutex_lock(&load_mutex);
    if (tdlib_handle != NULL) {
        int same_path = strcmp(loaded_path, library_path) == 0;
        if (!same_path) set_error(error_buffer, error_capacity, "TDLib is already loaded from a different path");
        pthread_mutex_unlock(&load_mutex);
        return same_path;
    }

    void *handle = dlopen(library_path, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        set_error(error_buffer, error_capacity, dlerror());
        pthread_mutex_unlock(&load_mutex);
        return 0;
    }

    dlerror();
    create_client_id_fn create = (create_client_id_fn)dlsym(handle, "td_create_client_id");
    send_fn send = (send_fn)dlsym(handle, "td_send");
    receive_fn receive = (receive_fn)dlsym(handle, "td_receive");
    const char *symbol_error = dlerror();
    if (symbol_error != NULL || create == NULL || send == NULL || receive == NULL) {
        set_error(error_buffer, error_capacity, symbol_error != NULL ? symbol_error : "TDLib JSON symbols are missing");
        dlclose(handle);
        pthread_mutex_unlock(&load_mutex);
        return 0;
    }

    loaded_path = strdup(library_path);
    if (loaded_path == NULL) {
        set_error(error_buffer, error_capacity, "Unable to retain TDLib library path");
        dlclose(handle);
        pthread_mutex_unlock(&load_mutex);
        return 0;
    }
    create_client_id = create;
    send_request = send;
    receive_update = receive;
    tdlib_handle = handle;
    pthread_mutex_unlock(&load_mutex);
    return 1;
}

int32_t nt_tdlib_create_client_id(void) {
    pthread_mutex_lock(&load_mutex);
    create_client_id_fn function = create_client_id;
    pthread_mutex_unlock(&load_mutex);
    return function != NULL ? (int32_t)function() : INT32_MIN;
}

int nt_tdlib_send(int32_t client_id, const char *request) {
    pthread_mutex_lock(&load_mutex);
    send_fn function = send_request;
    pthread_mutex_unlock(&load_mutex);
    if (function == NULL || request == NULL) return 0;
    function((int)client_id, request);
    return 1;
}

nt_tdlib_receive_status nt_tdlib_receive_copy(double timeout_seconds, char **output) {
    if (output == NULL) return NT_TDLIB_RECEIVE_ERROR;
    *output = NULL;
    pthread_mutex_lock(&load_mutex);
    receive_fn function = receive_update;
    pthread_mutex_unlock(&load_mutex);
    if (function == NULL) return NT_TDLIB_RECEIVE_ERROR;
    const char *borrowed = function(timeout_seconds);
    if (borrowed == NULL) return NT_TDLIB_RECEIVE_TIMEOUT;
    char *copy = strdup(borrowed);
    if (copy == NULL) return NT_TDLIB_RECEIVE_ERROR;
    *output = copy;
    return NT_TDLIB_RECEIVE_UPDATE;
}

void nt_tdlib_free(void *buffer) {
    free(buffer);
}
