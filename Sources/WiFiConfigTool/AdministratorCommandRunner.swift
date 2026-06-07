import AuthorizationShim
import Foundation
import Security

actor AdministratorCommandRunner {
    static let shared = AdministratorCommandRunner()

    private var authorization: AuthorizationRef?

    private init() {}

    func run(_ shellCommand: String) async throws -> CommandResult {
        let authorization = try authorize()
        let command = "(\(shellCommand)) 2>&1"
        let outputBufferSize = 64 * 1024
        let outputBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: outputBufferSize)
        defer {
            outputBuffer.deallocate()
        }

        var terminationStatus: CInt = -1
        let authorizationStatus = command.withCString { commandCString in
            WFTExecutePrivilegedShellCommand(
                authorization,
                commandCString,
                outputBuffer,
                outputBufferSize,
                &terminationStatus
            )
        }

        let output = String(cString: outputBuffer)

        if authorizationStatus == errAuthorizationCanceled {
            self.authorization = nil
            throw NetworkSetupError.administratorAuthorizationCancelled
        }

        guard authorizationStatus == errAuthorizationSuccess else {
            self.authorization = nil
            throw NetworkSetupError.administratorAuthorizationFailed(status: authorizationStatus)
        }

        guard terminationStatus == 0 else {
            throw NetworkSetupError.commandFailed(
                executable: "/bin/zsh",
                arguments: ["-c", command],
                status: terminationStatus,
                stdout: output,
                stderr: ""
            )
        }

        return CommandResult(stdout: output, stderr: "", exitCode: 0)
    }

    private func authorize() throws -> AuthorizationRef {
        if let authorization {
            return authorization
        }

        var createdAuthorization: AuthorizationRef?
        let createStatus = AuthorizationCreate(nil, nil, [], &createdAuthorization)
        guard createStatus == errAuthorizationSuccess, let createdAuthorization else {
            throw NetworkSetupError.administratorAuthorizationFailed(status: createStatus)
        }

        let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        let copyStatus = kAuthorizationRightExecute.withCString { rightName in
            var item = AuthorizationItem(
                name: rightName,
                valueLength: 0,
                value: nil,
                flags: 0
            )

            return withUnsafeMutablePointer(to: &item) { itemPointer in
                var rights = AuthorizationRights(count: 1, items: itemPointer)
                return withUnsafeMutablePointer(to: &rights) { rightsPointer in
                    AuthorizationCopyRights(createdAuthorization, rightsPointer, nil, flags, nil)
                }
            }
        }

        if copyStatus == errAuthorizationCanceled {
            _ = AuthorizationFree(createdAuthorization, [])
            throw NetworkSetupError.administratorAuthorizationCancelled
        }

        guard copyStatus == errAuthorizationSuccess else {
            _ = AuthorizationFree(createdAuthorization, [])
            throw NetworkSetupError.administratorAuthorizationFailed(status: copyStatus)
        }

        authorization = createdAuthorization
        return createdAuthorization
    }
}
