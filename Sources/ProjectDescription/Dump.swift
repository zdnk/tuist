import Foundation

func dumpIfNeeded<E: Encodable>(_ entity: E) {
    if CommandLine.argc > 0 {
        if entity is EnvironmentAt && shouldDumpEnvironments() {
            dump(entity)
            return
        }
        if entity is EnvironmentAt == false && shouldDump() {
            dump(entity)
            return
        }
    }
}

private func shouldDump() -> Bool {
    return CommandLine.arguments.contains("--dump")
}

private func shouldDumpEnvironments() -> Bool {
    return CommandLine.arguments.contains("--dump-environment")
}

private func dump<E: Encodable>(_ entity: E) {
    let encoder = JSONEncoder()
    // swiftlint:disable:next force_try
    let data = try! encoder.encode(entity)
    let string = String(data: data, encoding: .utf8)!
    print(string)
}
