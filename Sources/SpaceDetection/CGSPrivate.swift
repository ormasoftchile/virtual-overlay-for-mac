// CGSPrivate — runtime-resolved private Core Graphics Services symbols.

import CoreGraphics
import Darwin

// Runtime-resolved private CGS symbols. These are not linked at build time.
// If the symbols are unavailable (future macOS), all lookups return nil/0.

typealias CGSConnectionID = Int32
typealias CGSSpaceID = UInt64
typealias CGSMainConnectionIDFunction = @convention(c) () -> CGSConnectionID
typealias CGSGetActiveSpaceFunction = @convention(c) (CGSConnectionID) -> CGSSpaceID

private let cgsHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY
)

let CGSMainConnectionID: CGSMainConnectionIDFunction? = {
    guard let handle = cgsHandle,
          let sym = dlsym(handle, "CGSMainConnectionID")
    else { return nil }
    return unsafeBitCast(sym, to: CGSMainConnectionIDFunction.self)
}()

let CGSGetActiveSpace: CGSGetActiveSpaceFunction? = {
    guard let handle = cgsHandle,
          let sym = dlsym(handle, "CGSGetActiveSpace")
    else { return nil }
    return unsafeBitCast(sym, to: CGSGetActiveSpaceFunction.self)
}()

func currentCGSSpaceID() -> UInt64? {
    guard let mainConn = CGSMainConnectionID else {
        fputs("VirtualOverlay: CGSMainConnectionID unavailable; falling back to public Space fingerprint.\n", stderr)
        return nil
    }
    guard let getActive = CGSGetActiveSpace else {
        fputs("VirtualOverlay: CGSGetActiveSpace unavailable; falling back to public Space fingerprint.\n", stderr)
        return nil
    }

    let id = getActive(mainConn())
    guard id > 0 else {
        fputs("VirtualOverlay: CGSGetActiveSpace returned invalid Space ID; falling back to public Space fingerprint.\n", stderr)
        return nil
    }
    return id
}
