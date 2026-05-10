// CGSPrivate — runtime-resolved private Core Graphics Services symbols.

import CoreGraphics
import Darwin
import Foundation

// Runtime-resolved private CGS symbols. These are not linked at build time.
// If the symbols are unavailable (future macOS), lookups fall back gracefully.

typealias CGSConnectionID = Int32
typealias CGSSpaceID = UInt64
typealias CGSMainConnectionIDFunction = @convention(c) () -> CGSConnectionID
typealias CGSManagedDisplayGetCurrentSpaceFunction = @convention(c) (CGSConnectionID, CFString) -> CGSSpaceID
typealias CGSGetActiveSpaceFunction = @convention(c) (CGSConnectionID) -> CGSSpaceID

struct CGSPrivateSymbols {
    let mainConnectionID: (() -> CGSConnectionID)?
    let managedDisplayGetCurrentSpace: ((CGSConnectionID, CFString) -> CGSSpaceID)?
    let getActiveSpace: ((CGSConnectionID) -> CGSSpaceID)?

    static let live = CGSPrivateSymbols(
        mainConnectionID: CGSMainConnectionID.map { function in { function() } },
        managedDisplayGetCurrentSpace: CGSManagedDisplayGetCurrentSpace.map { function in { function($0, $1) } },
        getActiveSpace: CGSGetActiveSpace.map { function in { function($0) } }
    )
}

private let cgsFrameworkPaths = [
    "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
    "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
]

private let cgsHandles: [UnsafeMutableRawPointer] = cgsFrameworkPaths.compactMap { dlopen($0, RTLD_LAZY) }

private func resolveCGSSymbol(named names: [String]) -> UnsafeMutableRawPointer? {
    for handle in cgsHandles {
        for name in names {
            if let symbol = dlsym(handle, name) {
                return symbol
            }
        }
    }
    return nil
}

let CGSMainConnectionID: CGSMainConnectionIDFunction? = {
    guard let sym = resolveCGSSymbol(named: ["CGSMainConnectionID", "SLSMainConnectionID"]) else { return nil }
    return unsafeBitCast(sym, to: CGSMainConnectionIDFunction.self)
}()

let CGSManagedDisplayGetCurrentSpace: CGSManagedDisplayGetCurrentSpaceFunction? = {
    guard let sym = resolveCGSSymbol(named: ["CGSManagedDisplayGetCurrentSpace", "SLSManagedDisplayGetCurrentSpace"]) else { return nil }
    return unsafeBitCast(sym, to: CGSManagedDisplayGetCurrentSpaceFunction.self)
}()

let CGSGetActiveSpace: CGSGetActiveSpaceFunction? = {
    guard let sym = resolveCGSSymbol(named: ["CGSGetActiveSpace", "SLSGetActiveSpace"]) else { return nil }
    return unsafeBitCast(sym, to: CGSGetActiveSpaceFunction.self)
}()

func currentCGSSpaceID(forDisplayUUID displayUUID: String, symbols: CGSPrivateSymbols = .live) -> UInt64? {
    guard let mainConn = symbols.mainConnectionID else {
        fputs("VirtualOverlay: CGSMainConnectionID unavailable; falling back to public Space fingerprint.\n", stderr)
        return nil
    }

    let connection = mainConn()
    if let managedDisplayGetCurrentSpace = symbols.managedDisplayGetCurrentSpace {
        let id = managedDisplayGetCurrentSpace(connection, displayUUID as CFString)
        if id > 0 {
            return id
        }
        fputs("VirtualOverlay: CGSManagedDisplayGetCurrentSpace returned invalid Space ID; falling back to CGSGetActiveSpace.\n", stderr)
    } else {
        fputs("VirtualOverlay: CGSManagedDisplayGetCurrentSpace unavailable; falling back to CGSGetActiveSpace.\n", stderr)
    }

    guard let getActive = symbols.getActiveSpace else {
        fputs("VirtualOverlay: CGSGetActiveSpace unavailable; falling back to public Space fingerprint.\n", stderr)
        return nil
    }

    let id = getActive(connection)
    guard id > 0 else {
        fputs("VirtualOverlay: CGSGetActiveSpace returned invalid Space ID; falling back to public Space fingerprint.\n", stderr)
        return nil
    }
    return id
}
