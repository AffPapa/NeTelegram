#include "TDLibCBridge.h"

#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
    if (argc != 2) return 64;
    char error[1024] = {0};
    if (!nt_tdlib_load(argv[1], error, sizeof(error))) {
        fprintf(stderr, "TDLib load failed: %s\n", error);
        return 1;
    }

    int32_t client_id = nt_tdlib_create_client_id();
    if (client_id == INT32_MIN) {
        fputs("TDLib did not create a client ID\n", stderr);
        return 1;
    }

    const char *request = "{\"@type\":\"getOption\",\"name\":\"version\",\"@extra\":\"netelegram-tdlib-smoke\"}";
    if (!nt_tdlib_send(client_id, request)) {
        fputs("TDLib rejected the local smoke request\n", stderr);
        return 1;
    }

    char client_tag[64];
    snprintf(client_tag, sizeof(client_tag), "\"@client_id\":%d", client_id);
    int got_version = 0;
    int sent_close = 0;
    int got_closed = 0;
    for (int attempt = 0; attempt < 25 && !got_closed; attempt++) {
        char *json = NULL;
        nt_tdlib_receive_status receive_status = nt_tdlib_receive_copy(1.0, &json);
        if (receive_status == NT_TDLIB_RECEIVE_ERROR) {
            fputs("TDLib receive-copy failed during smoke test\n", stderr);
            return 1;
        }
        if (receive_status == NT_TDLIB_RECEIVE_TIMEOUT) continue;
        if (json == NULL) {
            fputs("TDLib returned update status without a copied buffer\n", stderr);
            return 1;
        }
        int same_client = strstr(json, client_tag) != NULL;
        if (same_client && strstr(json, "\"@extra\":\"netelegram-tdlib-smoke\"") != NULL &&
            strstr(json, "\"@type\":\"optionValueString\"") != NULL &&
            strstr(json, "\"value\":\"1.8.68\"") != NULL) {
            got_version = 1;
            if (!sent_close) {
                nt_tdlib_send(client_id, "{\"@type\":\"close\"}");
                sent_close = 1;
            }
        }
        if (same_client && strstr(json, "authorizationStateClosed") != NULL) got_closed = 1;
        nt_tdlib_free(json);
    }

    if (!got_version || !got_closed) {
        fprintf(stderr, "TDLib smoke incomplete: version=%d closed=%d\n", got_version, got_closed);
        return 1;
    }
    puts("TDLib JSON C ABI smoke passed: version response routed by client ID and close completed");
    return 0;
}
