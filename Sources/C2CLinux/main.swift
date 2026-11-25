import Foundation
import C2CLinuxGTK
import C2CCore
#if os(Linux)
import Glibc
#endif

#if os(Linux)
let application = LinuxApplication()
if ProcessInfo.processInfo.environment["C2C_LINUX_SELF_TEST"] == "1" {
    do {
        try application.selfTest()
        print("C2C Linux self-test passed")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("C2C Linux self-test failed: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

final class CallbackContext {
    let application: LinuxApplication
    init(application: LinuxApplication) { self.application = application }
}

let context = CallbackContext(application: application)
var callbacks = C2CLinuxGTKCallbacks(
    context: Unmanaged.passUnretained(context).toOpaque(),
    on_search: { context, query in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.handleSearch(String(cString: query!)) },
    on_pinned_filter: { context, enabled in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.setPinnedOnly(enabled != 0) },
    on_activate: { context, id in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.activate(id: String(cString: id!)) },
    on_pin: { context, id in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.togglePin(id: String(cString: id!)) },
    on_delete: { context, id in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.delete(id: String(cString: id!)) },
    on_clear: { context in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.clear() },
    on_settings: { context, json in
        let application = Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application
        guard let data = json.flatMap({ Data(String(cString: $0).utf8) }),
              let partial = try? JSONDecoder().decode(LinuxApplication.SettingsPatch.self, from: data) else { return }
        application.updateSettings(partial)
    },
    on_export: { context in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.exportArchive() },
    on_import: { context in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.importArchive() },
    on_quit: { context in Unmanaged<CallbackContext>.fromOpaque(context!).takeUnretainedValue().application.stop() }
)
application.start()
let status = c2c_linux_run(&callbacks)
application.stop()
exit(Int32(status))
#else
fatalError("C2CLinux requires Linux")
#endif
