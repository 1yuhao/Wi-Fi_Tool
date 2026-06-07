#ifndef AuthorizationShim_h
#define AuthorizationShim_h

#include <Security/Authorization.h>
#include <stddef.h>

int WFTExecutePrivilegedShellCommand(
    AuthorizationRef authorization,
    const char *command,
    char *outputBuffer,
    size_t outputBufferSize,
    int *terminationStatus
);

#endif
