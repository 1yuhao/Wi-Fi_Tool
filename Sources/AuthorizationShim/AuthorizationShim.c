#include "AuthorizationShim.h"

#include <stdio.h>
#include <string.h>
#include <sys/wait.h>

int WFTExecutePrivilegedShellCommand(
    AuthorizationRef authorization,
    const char *command,
    char *outputBuffer,
    size_t outputBufferSize,
    int *terminationStatus
) {
    if (outputBuffer != NULL && outputBufferSize > 0) {
        outputBuffer[0] = '\0';
    }
    if (terminationStatus != NULL) {
        *terminationStatus = -1;
    }

    char *arguments[] = { "-c", (char *)command, NULL };
    FILE *pipe = NULL;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    OSStatus status = AuthorizationExecuteWithPrivileges(
        authorization,
        "/bin/zsh",
        kAuthorizationFlagDefaults,
        arguments,
        &pipe
    );
#pragma clang diagnostic pop

    if (status != errAuthorizationSuccess) {
        return status;
    }

    if (pipe == NULL) {
        return errAuthorizationInternal;
    }

    if (outputBuffer != NULL && outputBufferSize > 0) {
        size_t used = 0;
        int character = 0;
        while ((character = fgetc(pipe)) != EOF) {
            if (used + 1 < outputBufferSize) {
                outputBuffer[used] = (char)character;
                used += 1;
            }
        }
        outputBuffer[used] = '\0';
    }

    int closeStatus = pclose(pipe);
    if (terminationStatus != NULL) {
        if (WIFEXITED(closeStatus)) {
            *terminationStatus = WEXITSTATUS(closeStatus);
        } else {
            *terminationStatus = closeStatus;
        }
    }

    return errAuthorizationSuccess;
}
