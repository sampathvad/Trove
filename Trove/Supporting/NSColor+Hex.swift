import AppKit

extension NSColor {
    static func parse(_ text: String) -> NSColor? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Hex
        if t.hasPrefix("#") {
            let hex = String(t.dropFirst())
            var rgb: UInt64 = 0
            guard Scanner(string: hex).scanHexInt64(&rgb) else { return nil }
            switch hex.count {
            case 3:
                let r = Double((rgb >> 8) & 0xF) / 15
                let g = Double((rgb >> 4) & 0xF) / 15
                let b = Double(rgb & 0xF) / 15
                return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
            case 6:
                let r = Double((rgb >> 16) & 0xFF) / 255
                let g = Double((rgb >> 8)  & 0xFF) / 255
                let b = Double(rgb         & 0xFF) / 255
                return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
            case 8:
                let r = Double((rgb >> 24) & 0xFF) / 255
                let g = Double((rgb >> 16) & 0xFF) / 255
                let b = Double((rgb >> 8)  & 0xFF) / 255
                let a = Double(rgb         & 0xFF) / 255
                return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
            default:
                return nil
            }
        }

        // rgb(r, g, b)
        if t.lowercased().hasPrefix("rgb") {
            let nums = t.components(separatedBy: CharacterSet(charactersIn: "(),rgba ")).compactMap(Double.init)
            guard nums.count >= 3 else { return nil }
            return NSColor(srgbRed: nums[0]/255, green: nums[1]/255, blue: nums[2]/255, alpha: nums.count >= 4 ? nums[3] : 1)
        }

        // hsl(h, s%, l%)
        if t.lowercased().hasPrefix("hsl") {
            let nums = t.components(separatedBy: CharacterSet(charactersIn: "(),hsla% ")).compactMap(Double.init)
            guard nums.count >= 3 else { return nil }
            return NSColor(hue: nums[0]/360, saturation: nums[1]/100, brightness: nums[2]/100, alpha: nums.count >= 4 ? nums[3] : 1)
        }

        return nil
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var rgbString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "rgb(0,0,0)" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return "rgb(\(r), \(g), \(b))"
    }

    var hslString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "hsl(0,0%,0%)" }
        let r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent
        let maxC = max(r, g, b), minC = min(r, g, b)
        let l = (maxC + minC) / 2
        let d = maxC - minC
        let s = d == 0 ? 0 : d / (1 - abs(2*l - 1))
        var h: CGFloat = 0
        if d != 0 {
            switch maxC {
            case r: h = (g - b) / d + (g < b ? 6 : 0)
            case g: h = (b - r) / d + 2
            default: h = (r - g) / d + 4
            }
            h /= 6
        }
        return String(format: "hsl(%d, %d%%, %d%%)", Int(h*360), Int(s*100), Int(l*100))
    }
}
