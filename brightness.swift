// awake's brightness helper: `bright` prints the built-in display's brightness (0-1), `bright V` sets it.
// Uses the private DisplayServices framework; the public APIs can't set brightness on Apple Silicon.
import CoreGraphics
import Foundation

let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
guard let g = dlsym(h, "DisplayServicesGetBrightness"), let s = dlsym(h, "DisplayServicesSetBrightness") else { exit(2) }
let get = unsafeBitCast(g, to: (@convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32).self)
let set = unsafeBitCast(s, to: (@convention(c) (UInt32, Float) -> Int32).self)

var ids = [CGDirectDisplayID](repeating: 0, count: 16), n: UInt32 = 0
CGGetOnlineDisplayList(16, &ids, &n)
guard let d = ids.prefix(Int(n)).first(where: { CGDisplayIsBuiltin($0) != 0 }) else { exit(1) }
if CommandLine.arguments.count > 1, let v = Float(CommandLine.arguments[1]) {
  exit(set(d, max(0, min(1, v))) == 0 ? 0 : 1)
}
var v: Float = 0
guard get(d, &v) == 0 else { exit(1) }
print(v)
