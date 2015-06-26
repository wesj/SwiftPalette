import Foundation
import UIKit

/**
* Class which provides a histogram for RGB values.
*/
final class ColorHistogram {
    private var mColors = [Color]()
    private var mColorCounts = [Int]()
    private let mNumberColors: Int

    /**
    * A new {@link ColorHistogram} instance.
    *
    * @param pixels array of image contents
    */
    init(var pixels: [Color]) {
        // Sort the pixels to enable counting below
        sort(&pixels)
        // pixels.sort { (a, b) -> Bool in a < b }

        // Count number of distinct colors
        mNumberColors = ColorHistogram.countDistinctColors(pixels)

        // Create arrays
        mColors = [Color](count: mNumberColors, repeatedValue: 0)
        mColorCounts = [Int](count: mNumberColors, repeatedValue: 0)

        // Finally count the frequency of each color
        countFrequencies(pixels)

        // mColors.sort { (a, b) -> Bool in
        //     return a.red() < b.red()
        // }
    }

    /**
    * @return number of distinct colors in the image.
    */
    func getNumberOfColors() -> Int {
        return mNumberColors;
    }

    /**
    * @return an array containing all of the distinct colors in the image.
    */
    func getColors() -> [Color] {
        return mColors;
    }

    /**
    * @return an array containing the frequency of a distinct colors within the image.
    */
    func getColorCounts() -> [Int] {
        return mColorCounts;
    }

    private class func countDistinctColors(pixels: [Color]) -> Int {
        if (pixels.count < 2) {
            // If we have less than 2 pixels we can stop here
            return pixels.count;
        }

        // If we have at least 2 pixels, we have a minimum of 1 color...
        var colorCount = 1;
        var currentColor = pixels[0];

        // Now iterate from the second pixel to the end, counting distinct colors
        for i in 1..<pixels.count {
            // If we encounter a new color, increase the population
            if (pixels[i] != currentColor) {
                currentColor = pixels[i]
                colorCount++
            }
        }

        return colorCount;
    }

    private func countFrequencies(pixels: [Color]) {
        if (pixels.count == 0) {
            return;
        }

        var currentColorIndex = 0
        var currentColor = pixels[0]

        mColors[currentColorIndex] = currentColor
        mColorCounts[currentColorIndex] = 1

        if (pixels.count == 1) {
            // If we only have one pixel, we can stop here
            return;
        }

        // Now iterate from the second pixel to the end, population distinct colors
        for i in 1..<pixels.count {
            if (pixels[i] == currentColor) {
                // We've hit the same color as before, increase population
                mColorCounts[currentColorIndex]++
            } else {
                // We've hit a new color, increase index
                currentColor = pixels[i]
                currentColorIndex++
                mColors[currentColorIndex] = currentColor
                mColorCounts[currentColorIndex] = 1
            }
        }
    }
}
