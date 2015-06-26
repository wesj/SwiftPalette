import Foundation
import UIKit
import CoreGraphics

private let MinAlphaSearchMaxIterations = 10
private let MinAlphaSearchPrecision: CGFloat = 10

final class ColorUtils {
    private init() {}

    /**
    * Composite two potentially translucent colors over each other and returns the result.
    */
    private class func compositeColors(fg: CGColor, bg: CGColor) -> CGColor {
        let fgColors = CGColorGetComponents(fg)
        let bgColors = CGColorGetComponents(bg)

        let alpha1 = CGColorGetAlpha(fg)
        let alpha2 = CGColorGetAlpha(bg)

        let a = (alpha1 + alpha2) * (1.0 - alpha1)
        let r = (fgColors[0] * alpha1) + (bgColors[0] * alpha2 * (1.0 - alpha1))
        let g = (fgColors[1] * alpha1) + (bgColors[1] * alpha2 * (1.0 - alpha1));
        let b = (fgColors[2] * alpha1) + (fgColors[2] * alpha2 * (1.0 - alpha1));

        return UIColor(red: r, green: g, blue: b, alpha: a).CGColor
    }

    /**
    * Returns the luminance of a color.
    *
    * Formula defined here: http://www.w3.org/TR/2008/REC-WCAG20-20081211/#relativeluminancedef
    */
    private class func calculateLuminance(color: CGColor) -> CGFloat {
        let colors = CGColorGetComponents(color)

        let red = colors[0] < 0.03928 ? colors[0] / 12.92 : pow((colors[0] + 0.055) / 1.055, 2.4)
        let green = colors[1] < 0.03928 ? colors[1] / 12.92 : pow((colors[1] + 0.055) / 1.055, 2.4)
        let blue = colors[2] < 0.03928 ? colors[2] / 12.92 : pow((colors[2] + 0.055) / 1.055, 2.4)

        return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }

    /**
    * Returns the contrast ratio between two colors.
    *
    * Formula defined here: http://www.w3.org/TR/2008/REC-WCAG20-20081211/#contrast-ratiodef
    */
    private class func calculateContrast(var foreground: CGColor, background: CGColor) -> CGFloat {
        let alpha = CGColorGetAlpha(foreground)
        if (alpha != 1.0) {
            // throw new IllegalArgumentException("background can not be translucent")
            return -1
        }
        let alpha2 = CGColorGetAlpha(background)
        if (alpha2 < 1.0) {
            // If the foreground is translucent, composite the foreground over the background
            foreground = compositeColors(foreground, bg: background)
        }

        var luminance1 = calculateLuminance(foreground) + 0.05
        var luminance2 = calculateLuminance(background) + 0.05

        // Now return the lighter luminance divided by the darker luminance
        return max(luminance1, luminance2) / min(luminance1, luminance2)
    }

    /**
    * Finds the minimum alpha value which can be applied to {@code foreground} so that is has a
    * contrast value of at least {@code minContrastRatio} when compared to background.
    *
    * @return the alpha value in the range 0-255.
    */
    private class func findMinimumAlpha(foreground: CGColor, background: CGColor, minContrastRatio: CGFloat) -> CGFloat {
        let alpha = CGColorGetAlpha(background)
        if (alpha != 1.0) {
            // throw new IllegalArgumentException("background can not be translucent");
            return -1
        }

        // First lets check that a fully opaque foreground has sufficient contrast
        var testForeground = modifyAlpha(foreground, alpha: 1.0)
        var testRatio = calculateContrast(testForeground, background: background)
        if (testRatio < minContrastRatio) {
            // Fully opaque foreground does not have sufficient contrast, return error
            return -1
        }

        // Binary search to find a value with the minimum value which provides sufficient contrast
        var numIterations = 0
        var minAlpha: CGFloat = 0
        var maxAlpha: CGFloat = 1.0

        while (numIterations <= MinAlphaSearchMaxIterations &&
            (maxAlpha - minAlpha) > MinAlphaSearchPrecision) {
                let testAlpha = (minAlpha + maxAlpha) / 2

                testForeground = modifyAlpha(foreground, alpha: testAlpha)
                testRatio = calculateContrast(testForeground, background: background)
                
                if (testRatio < minContrastRatio) {
                    minAlpha = testAlpha
                } else {
                    maxAlpha = testAlpha
                }
                
                numIterations++
        }

        // Conservatively return the max of the range of possible alphas, which is known to pass.
        return maxAlpha
    }

    class func getTextColorForBackground(backgroundColor: CGColor, minContrastRatio: CGFloat) -> CGColor {
        // First we will check white as most colors will be dark
        var whiteMinAlpha = ColorUtils.findMinimumAlpha(UIColor.whiteColor().CGColor, background: backgroundColor, minContrastRatio: minContrastRatio)

        if (whiteMinAlpha >= 0) {
            return modifyAlpha(UIColor.whiteColor().CGColor, alpha: whiteMinAlpha)
        }

        // If we hit here then there is not an translucent white which provides enough contrast,
        // so check black
        var blackMinAlpha = ColorUtils.findMinimumAlpha(UIColor.blackColor().CGColor, background: backgroundColor, minContrastRatio: minContrastRatio)

        if (blackMinAlpha >= 0) {
            return modifyAlpha(UIColor.blackColor().CGColor, alpha: blackMinAlpha)
        }
        
        // This should not happen!
        return UIColor.whiteColor().CGColor
    }

    class func RGBtoHSL(r: CGFloat, g: CGFloat, b: CGFloat) -> [CGFloat] {
        // println("Convert \(r) \(g) \(b)")
        let maximum = max(r, max(g, b))
        let minimum = min(r, min(g, b))
        let deltaMaxMin = maximum - minimum

        var h: CGFloat = 0.0
        var s: CGFloat = 0.0
        var l: CGFloat = (maximum + minimum) / 2.0

        if (maximum == minimum) {
            // Monochromatic
            h = 0.0
            s = 0.0
        } else {
            if (maximum == r) {
                h = ((g - b) / deltaMaxMin) % 6.0
            } else if (maximum == g) {
                h = ((b - r) / deltaMaxMin) + 2.0
            } else {
                h = ((r - g) / deltaMaxMin) + 4.0
            }
            
            s =  deltaMaxMin / (1.0 - abs(2.0 * l - 1.0))
        }
        
        return [(h * 60.0) % 360.0, s, l]
    }

    class func HSLtoRGB(hsl: [CGFloat]) -> UIColor {
        let h = hsl[0]
        let s = hsl[1]
        let l = hsl[2]

        let c = (1.0 - abs(2.0 * l - 1.0)) * s
        let m = l - 0.5 * c
        let x = c * (1.0 - abs((h / 60.0 % 2.0) - 1.0))

        let hueSegment = h / 60

        var r: CGFloat = 0,
            g: CGFloat = 0,
            b: CGFloat = 0

        switch (hueSegment) {
        case 0:
            r = c + m
            g = x + m
            b = m
        case 1:
            r = x + m
            g = c + m
            b = m
        case 2:
            r = m
            g = c + m
            b = x + m
        case 3:
            r = m
            g = x + m
            b = c + m
        case 4:
            r = x + m
            g = m
            b = c + m
        case 5...6:
            r = c + m
            g = m
            b = x + m
        default:
            break
        }
        
        r = max(0, min(1.0, r))
        g = max(0, min(1.0, g))
        b = max(0, min(1.0, b))

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    /**
    * Set the alpha component of {@code color} to be {@code alpha}.
    */
    class func modifyAlpha(color: CGColor, alpha: CGFloat) -> CGColor {
        return CGColorCreateCopyWithAlpha(color, alpha)
    }
}
