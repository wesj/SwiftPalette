/*
* Copyright 2014 The Android Open Source Project
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*       http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
import Foundation
import CoreGraphics
import UIKit

typealias Color = UInt32
extension Color {
    func red() -> UInt32 { return self >> 16 & 0xFF }
    func green() -> UInt32 { return self >> 8 & 0xFF }
    func blue() -> UInt32 { return self >> 0 & 0xFF }
    func alpha() -> UInt32 { return self >> 24 & 0xFF }

    func toUIColor() -> UIColor { return UIColor(red: CGFloat(Float(red()) / 255.0),
        green: CGFloat(Float(green()) / 255.0),
        blue: CGFloat(Float(blue()) / 255.0),
        alpha: CGFloat(Float(alpha()) / 255.0)) }

     static func fromRGBA(red: UInt32, green: UInt32, blue: UInt32, alpha: UInt32) -> Color {
        return Color(
            ((red & 0xFF) << 16) +
            ((green & 0xFF) << 8) +
            ((blue & 0xFF) << 0) +
            ((alpha & 0xFF) << 24))
    }

    static func fromRGBA(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) -> Color {
        return fromRGBA(UInt32(red), green: UInt32(green), blue: UInt32(blue), alpha: UInt32(alpha))
    }
}

/**
* An color quantizer based on the Median-cut algorithm, but optimized for picking out distinct
* colors rather than representation colors.
*
* The color space is represented as a 3-dimensional cube with each dimension being an RGB
* component. The cube is then repeatedly divided until we have reduced the color space to the
* requested number of colors. An average color is then generated from each cube.
*
* What makes this different to median-cut is that median-cut divided cubes so that all of the cubes
* have roughly the same population, where this quantizer divides boxes based on their color volume.
* This means that the color space is divided into distinct colors, rather than representative
* colors.
*/
private enum Components: String {
    case RED = "Red"
    case GREEN = "Green"
    case BLUE = "blue"
}

final class ColorCutQuantizer {
    private static let LOG_TAG = "ColorCutQuantizer"
    private var mTempHsl = [Float](count: 4, repeatedValue: 0.0)
    private static let BLACK_MAX_LIGHTNESS: CGFloat = 0.05
    private static let WHITE_MIN_LIGHTNESS: CGFloat = 0.95

    private var mColors: [Color]
    private var mColorPopulations: [Color: Int]
    private var mQuantizedColors: [Swatch]!

    /**
    * Factory-method to generate a {@link ColorCutQuantizer} from a {@link Bitmap} object.
    *
    * @param bitmap Bitmap to extract the pixel data from
    * @param maxColors The maximum number of colors that should be in the result palette.
    */
    convenience init(fromImage image: UIImage, maxColors: Int) {
        let width = image.size.width
        let height = image.size.height

        let pixels = image.getPixelData(atX: 0, andY: 0, count: Int(width * height))
        let histogram = ColorHistogram(pixels: pixels)
        self.init(colorHistogram: histogram, maxColors: maxColors);
    }

    /**
    * Private constructor.
    *
    * @param colorHistogram histogram representing an image's pixel data
    * @param maxColors The maximum number of colors that should be in the result palette.
    */
    private init(colorHistogram: ColorHistogram, maxColors: Int) {
        let rawColorCount = colorHistogram.getNumberOfColors()
        let rawColors = colorHistogram.getColors()
        let rawColorCounts = colorHistogram.getColorCounts()

        // First, lets pack the populations into a SparseIntArray so that they can be easily
        // retrieved without knowing a color's index
        mColorPopulations = [Color:Int](minimumCapacity: rawColorCount)
        for i in 0..<rawColorCount {
            let color = rawColors[i]
            mColorPopulations[rawColors[i]] = rawColorCounts[i]
        }

        // Now go through all of the colors and keep those which we do not want to ignore
        mColors = [Color](count: rawColorCount, repeatedValue: 0)
        var validColorCount = 0
        for i in 0..<rawColorCount {
            let color = rawColors[i]
            if (!ColorCutQuantizer.shouldIgnoreColor(color)) {
                mColors[validColorCount++] = color
            }
        }

        if (validColorCount <= maxColors) {
            // The image has fewer colors than the maximum requested, so just return the colors
            mQuantizedColors = [Swatch]()
            for color in mColors {
                mQuantizedColors.append(Swatch(rgb: color.toUIColor(), population: mColorPopulations[color] ?? 0));
            }
        } else {
            // We need use quantization to reduce the number of colors
            mQuantizedColors = quantizePixels(validColorCount - 1, maxColors: maxColors);
        }
    }

    /**
    * @return the list of quantized colors
    */
    func getQuantizedColors() -> [Swatch] {
        return mQuantizedColors
    }

    private func quantizePixels(maxColorIndex: Int, maxColors: Int) -> [Swatch] {
        // Create the priority queue which is sorted by volume descending. This means we always
        // split the largest box in the queue
        var pq = PriorityQueue<Vbox>()

        // To start, offer a box which contains all of the colors
        pq.push(Vbox(colors: mColors[0...maxColorIndex], populations: mColorPopulations))

        // Now go through the boxes, splitting them until we have reached maxColors or there are no more boxes to split
        splitBoxes(&pq, maxSize: maxColors)

        // Finally, return the average colors of the color boxes
        return generateAverageColors(pq)
    }

    /**
    * Iterate through the {@link java.util.Queue}, popping
    * {@link ColorCutQuantizer.Vbox} objects from the queue
    * and splitting them. Once split, the new box and the remaining box are offered back to the
    * queue.
    *
    * @param queue {@link java.util.PriorityQueue} to poll for boxes
    * @param maxSize Maximum amount of boxes to split
    */
    private func splitBoxes(inout queue: PriorityQueue<Vbox>, maxSize: Int) {
        var pass = 0
        while (queue.count < maxSize) {
            /*
            for (index, colors) in enumerate(queue) {
                let img = UIImage.fromColors(colors.mColors)
                var pngPath = NSHomeDirectory().stringByAppendingPathComponent("Documents/Test-\(pass)-\(index).png")
                println(pngPath)
                UIImagePNGRepresentation(img).writeToFile(pngPath, atomically: true)
            }
            */
            for (index, colors) in enumerate(queue) {
                var str = String(format: "Box \(pass) \(index): %#010x \(colors.getColorCount())", colors.getAverageColor().toInt())
                // println(str)
            }
            pass++

            if let vbox = queue.pop() {
                if let split = vbox.splitBox() {
                    queue.push(split)
                    queue.push(vbox)
                } else {
                    // queue.push(vbox)
                    return
                }
            }
        }
    }

    private func generateAverageColors(vboxes: PriorityQueue<Vbox>) -> [Swatch] {
        var colors = [Swatch]()
        for vbox in vboxes {
            var color = vbox.getAverageColor()
            if (!ColorCutQuantizer.shouldIgnoreColor(color)) {
                // As we're averaging a color box, we can still get colors which we do not want, so we check again here
                colors.append(color)
            }
        }
        return colors;
    }

    private class func shouldIgnoreColor(color: Color) -> Bool {
        let swatch = Swatch(rgb: color.toUIColor(), population: 0)
        // println("Should ignore \(swatch.hsl)")
        return shouldIgnoreColor(swatch)
    }

    private class func shouldIgnoreColor(color: Swatch) -> Bool {
    	return shouldIgnoreColor(color.hsl)
    }

    private class func shouldIgnoreColor(hslColor: [CGFloat]) -> Bool {
        return isWhite(hslColor) || isBlack(hslColor) || isNearRedILine(hslColor)
    }

    /**
    * @return true if the color represents a color which is close to black.
    */
    private class func isBlack(hslColor: [CGFloat]) -> Bool {
        // println("Is Black \(hslColor)")
        return hslColor[2] <= BLACK_MAX_LIGHTNESS
    }

    /**
    * @return true if the color represents a color which is close to white.
    */
    private class func isWhite(hslColor: [CGFloat]) -> Bool {
        return hslColor[2] >= WHITE_MIN_LIGHTNESS;
    }

    /**
    * @return true if the color lies close to the red side of the I line.
    */
    private class func isNearRedILine(hslColor: [CGFloat]) -> Bool {
        return hslColor[0] >= 10 && hslColor[0] <= 37 && hslColor[1] <= 0.82
    }
}

/**
* Represents a tightly fitting box around a color space.
*/
class Vbox: Comparable {
    // lower and upper index are inclusive
    private var mColors: ArraySlice<UInt32>
    private var mColorPopulations: [Color:Int]

    private var mMinRed: UInt32 = 0,
                mMaxRed: UInt32 = 0,
                mMinGreen: UInt32 = 0,
                mMaxGreen: UInt32 = 0,
                mMinBlue: UInt32 = 0,
                mMaxBlue: UInt32 = 0

    init(colors: ArraySlice<UInt32>, populations: [Color:Int]) {
        mColors = colors
        mColorPopulations = populations
        fitBox()
    }

    func getVolume() -> UInt32 {
        return (mMaxRed - mMinRed + 1) * (mMaxGreen - mMinGreen + 1) * (mMaxBlue - mMinBlue + 1)
    }

    func canSplit() -> Bool {
        return getColorCount() > 1
    }

    func getColorCount() -> Int {
        return mColors.count
    }

    /**
    * Recomputes the boundaries of this box to tightly fit the colors within the box.
    */
    func fitBox() {
        // Reset the min and max to opposite values
        mMinRed = 255
        mMinGreen = 255
        mMinBlue = 255
        mMaxRed = 0
        mMaxGreen = 0
        mMaxBlue = 0

        for color in mColors {
            let r = color.red()
            let g = color.green()
            let b = color.blue()

            if (r > mMaxRed) {
                mMaxRed = r;
            }
            if (r < mMinRed) {
                mMinRed = r;
            }
            if (g > mMaxGreen) {
                mMaxGreen = g;
            }
            if (g < mMinGreen) {
                mMinGreen = g;
            }
            if (b > mMaxBlue) {
                mMaxBlue = b;
            }
            if (b < mMinBlue) {
                mMinBlue = b;
            }
        }
    }

    /**
    * Split this color box at the mid-point along it's longest dimension
    *
    * @return the new ColorBox
    */
    func splitBox() -> Vbox? {
        if (!canSplit()) {
            // throw new IllegalStateException("Can not split a box with only 1 color");
            return nil
        }

        // find median along the longest dimension
        let splitPoint = findSplitPoint()
        if splitPoint == mColors.count-1 {
            return nil
        }

        var newBox = Vbox(colors: mColors[splitPoint+1...mColors.count-1], populations: mColorPopulations)

        // Now change this box's upperIndex and recompute the color boundaries
        mColors = mColors[0...splitPoint]
        fitBox()

        return newBox
    }

    /**
    * @return the dimension which this box is largest in
    */
    private func getLongestColorDimension() -> Components {
        let redLength = mMaxRed - mMinRed;
        let greenLength = mMaxGreen - mMinGreen;
        let blueLength = mMaxBlue - mMinBlue;

        if (redLength >= greenLength && redLength >= blueLength) {
            return .RED;
        } else if (greenLength >= redLength && greenLength >= blueLength) {
            return .GREEN;
        } else {
            return .BLUE;
        }
    }

    /**
    * Finds the point within this box's lowerIndex and upperIndex index of where to split.
    *
    * This is calculated by finding the longest color dimension, and then sorting the
    * sub-array based on that dimension value in each color. The colors are then iterated over
    * until a color is found with at least the midpoint of the whole box's dimension midpoint.
    *
    * @return the index of the colors array to split from
    */
    func findSplitPoint() -> Int {
        let longestDimension = getLongestColorDimension()

        // We need to sort the colors in this box based on the longest color dimension.
        mColors.sort { (a, b) -> Bool in
            switch(longestDimension) {
                case .RED: return a.red() < b.red()
                case .GREEN: return a.green() < b.green()
                case .BLUE: return a.blue() < b.blue()
            }
        }

        let dimensionMidPoint = midPoint(longestDimension)

        for (index, color) in enumerate(mColors) {
            switch (longestDimension) {
            case .RED: if color.red() >= dimensionMidPoint { return index }
            case .GREEN: if color.green() >= dimensionMidPoint { return index }
            case .BLUE: if color.blue() >= dimensionMidPoint { return index }
            }
        }

        return 0
    }

    /**
     * @return the average color of this box.
     */
    func getAverageColor() -> Swatch {
        var redSum: Int = 0
        var greenSum: Int = 0
        var blueSum: Int = 0
        var totalPopulation: Int = 0

        for color in mColors {
            let colorPopulation = mColorPopulations[color] ?? 0

            totalPopulation += colorPopulation
            redSum += colorPopulation * Int(color.red())
            greenSum += colorPopulation * Int(color.green())
            blueSum += colorPopulation * Int(color.blue())
        }

        if (totalPopulation == 0) {
            return Swatch(red: 0, green: 0, blue: 0, alpha: 1.0, population: 0)
        }

        // println("\(redSum) \(greenSum) \(blueSum)")
        let redAverage: CGFloat = CGFloat(Double(redSum / totalPopulation) / 255.0)
        let greenAverage: CGFloat = CGFloat(Double(greenSum / totalPopulation) / 255.0)
        let blueAverage: CGFloat = CGFloat(Double(blueSum / totalPopulation) / 255.0)

        return Swatch(red: redAverage, green: greenAverage, blue: blueAverage, alpha: 1.0, population: Int(totalPopulation))
    }

    /**
    * @return the midpoint of this box in the given {@code dimension}
    */
    private func midPoint(dimension: Components) -> UInt32 {
        switch (dimension) {
            case .GREEN: return (mMinGreen + mMaxGreen) / 2
            case .BLUE:  return (mMinBlue + mMaxBlue)   / 2
            case .RED:   return (mMinRed + mMaxRed)     / 2
        }
    }
}


/**
 * Comparator which sorts {@link Vbox} instances based on their volume, in descending order
 */
func ==(lhs: Vbox, rhs: Vbox) -> Bool { return rhs.getVolume() == lhs.getVolume() }
func <=(lhs: Vbox, rhs: Vbox) -> Bool { return lhs.getVolume() <= rhs.getVolume() }
func >=(lhs: Vbox, rhs: Vbox) -> Bool { return lhs.getVolume() >= rhs.getVolume() }
func >(lhs: Vbox, rhs: Vbox) -> Bool { return lhs.getVolume() > rhs.getVolume() }
func <(lhs: Vbox, rhs: Vbox) -> Bool { return lhs.getVolume() < rhs.getVolume() }

