import CoreGraphics
import Foundation

let appPid = Int(CommandLine.arguments[1]) ?? 0

struct Candidate {
  let layer: Int
  let area: Int
  let id: Int
}

func intValue(_ value: Any?) -> Int {
  if let number = value as? NSNumber {
    return number.intValue
  }
  if let int = value as? Int {
    return int
  }
  if let double = value as? Double {
    return Int(double)
  }
  return 0
}

func doubleValue(_ value: Any?, default defaultValue: Double = 0) -> Double {
  if let number = value as? NSNumber {
    return number.doubleValue
  }
  if let double = value as? Double {
    return double
  }
  if let int = value as? Int {
    return Double(int)
  }
  return defaultValue
}

for _ in 0..<20 {
  let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
  var candidates: [Candidate] = []

  for window in info {
    let ownerPid = intValue(window[kCGWindowOwnerPID as String])
    if ownerPid != appPid {
      continue
    }

    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = intValue(bounds["Width"])
    let height = intValue(bounds["Height"])
    let windowID = intValue(window[kCGWindowNumber as String])
    let alpha = doubleValue(window[kCGWindowAlpha as String], default: 1)
    if width <= 1 || height <= 1 || windowID <= 0 || alpha <= 0 {
      continue
    }

    candidates.append(Candidate(
      layer: intValue(window[kCGWindowLayer as String]),
      area: width * height,
      id: windowID
    ))
  }

  if let best = candidates.sorted(by: {
    if $0.layer == $1.layer {
      return $0.area > $1.area
    }
    return $0.layer < $1.layer
  }).first {
    print(best.id)
    exit(0)
  }

  Thread.sleep(forTimeInterval: 0.5)
}

print("ERROR: CoreGraphics window not found")
exit(1)
