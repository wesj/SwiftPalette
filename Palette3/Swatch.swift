import Foundation
import UIKit

private let MinContrastTitleText: CGFloat = 3.0
private let MinContrastBodyText: CGFloat = 4.5


/**
* Represents a color swatch generated from an image's palette. The RGB color can be retrieved
* by calling {@link #getRgb()}.
*/
public class Swatch: Equatable, Printable {
    let rgb: UIColor
    let population: Int

    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0

    public var description: String {
        return "UIColor(red: \(red/255.0), green: \(green/255.0), blue: \(blue/255.0), alpha: 1)"
    }

    init(rgb: UIColor, population: Int) {
        self.rgb = rgb
        self.population = population

        var alpha: CGFloat = 1.0

        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        red *= 255
        green *= 255
        blue *= 255
    }

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat, population: Int) {
        self.red = red * 255
        self.green = green * 255
        self.blue = blue * 255
        self.rgb = UIColor(red: red, green: green, blue: blue, alpha: alpha)
        self.population = population;
    }

    /**
    * Return this swatch's HSL values.
    *     hsv[0] is Hue [0 .. 360)
    *     hsv[1] is Saturation [0...1]
    *     hsv[2] is Lightness [0...1]
    */
    public lazy var hsb: [CGFloat] = {
        // Lazily generate HSL values from RGB
        var hsb = [CGFloat](count: 3, repeatedValue: 0)
        var alpha: CGFloat = 1.0
        self.rgb.getHue(&hsb[0], saturation: &hsb[1], brightness: &hsb[2], alpha: &alpha)
        return hsb
    }()

    public lazy var hsl: [CGFloat] = {
        var rf = self.red / 255
        var gf = self.green / 255
        var bf = self.blue / 255

        var mx: CGFloat = max(rf, max(gf, bf));
        var mn: CGFloat = min(rf, min(gf, bf));
        var deltaMaxMin: CGFloat = mx - mn

        var h: CGFloat, s: CGFloat
        var l: CGFloat = (mx + mn) / 2.0

        if (mx == mn) {
            // Monochromatic
            h = 0
            s = 0
        } else {
            if (mx == rf) {
                h = ((gf - bf) / deltaMaxMin) % 6
            } else if (mx == gf) {
                h = ((bf - rf) / deltaMaxMin) + 2
            } else {
                h = ((rf - gf) / deltaMaxMin) + 4
            }
            s =  deltaMaxMin / (1.0 - abs(2.0 * l - 1.0))
        }

        return [(h * 60) % 360, s, l]
    }()

    /**
    * Returns an appropriate color to use for any 'title' text which is displayed over this
    * {@link Swatch}'s color. This color is guaranteed to have sufficient contrast.
    */
    public lazy var titleTextColor: UIColor = {
        var c = ColorUtils.getTextColorForBackground(self.rgb.CGColor, minContrastRatio: MinContrastTitleText)
        return UIColor(CGColor: c)!
    }()

    /**
    * Returns an appropriate color to use for any 'body' text which is displayed over this
    * {@link Swatch}'s color. This color is guaranteed to have sufficient contrast.
    */
    public lazy var bodyTextColor: UIColor = {
        var c = ColorUtils.getTextColorForBackground(self.rgb.CGColor, minContrastRatio: MinContrastBodyText)
        return UIColor(CGColor: c)!
    }()

    public var hashValue: Int {
        return 31 * rgb.hashValue + population
    }

    public func toInt() -> UInt32 {
        return Color.fromRGBA(UInt32(red), green: UInt32(green), blue: UInt32(blue), alpha: 0xFF)
    }
}


public func ==(lhs: Swatch, rhs: Swatch) -> Bool {
    if (lhs === rhs) {
        return true
    }

    return lhs.population == rhs.population &&
        fabs(lhs.red - rhs.red) < 0.001 &&
        fabs(lhs.green - rhs.green) < 0.001 &&
        fabs(lhs.blue - rhs.blue) < 0.001
}
