//
//  Palette3Tests.swift
//  Palette3Tests
//
//  Created by Wes Johnston on 6/20/15.
//  Copyright (c) 2015 Wes Johnston. All rights reserved.
//

import UIKit
import XCTest

class Palette3Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        /*
        imgTest("testImg", vib: Swatch(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0, population: 110),
            vibDark: Swatch(red: 0.0, green: 0.52, blue: 0.0, alpha: 1.0, population: 0),
            vibLight: Swatch(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0, population: 0),
            mut: nil, mutDark: nil, mutLight: nil)

        imgTest("testImg2", vib: Swatch(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0, population: 55),
            vibDark: Swatch(red: 0.0, green: 155/255, blue: 0.0, alpha: 1.0, population: 55),
            vibLight: nil,
            mut: nil, mutDark: Swatch(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0, population: 0), mutLight: nil)
        */

        imgTest("flower5.jpg", vib: Swatch(rgb: Color(0xffb02d28).toUIColor() , population: 15691),
            vibDark: Swatch(rgb: Color(0xff213259).toUIColor(), population: 15691),
            vibLight: Swatch(rgb: Color(0xffa592e1).toUIColor() , population: 15691),
            mut: Swatch(rgb: Color(0xffb374a5).toUIColor() , population: 15691),
            mutDark: Swatch(rgb: Color(0xff693855).toUIColor() , population: 15691),
            mutLight: Swatch(rgb: Color(0xffc6aeb0).toUIColor() , population: 15691))
    }

    func swatchTest(a: Swatch?, b: Swatch?, name: String) {
        if a == nil { XCTAssertNil(b, "\(name) is nil") }
        else if b == nil { XCTAssertNil(a, "\(name) is nil") }
        else { XCTAssertEqual(a!, b!, "\(name) is equal") }
    }

    func imgTest(img: String, vib: Swatch?, vibDark: Swatch?, vibLight: Swatch?,
        mut: Swatch?, mutDark: Swatch?, mutLight: Swatch?) {
            let bundle = NSBundle(forClass: Palette3Tests.self)
            let path = bundle.resourcePath?.stringByAppendingPathComponent(img)
            println(path)
            let img = UIImage(contentsOfFile: path!)
            XCTAssertNotNil(img)

            let p = Palette(fromImage: img!)
            swatchTest(p.vibrantSwatch, b: vib, name: "Vibrant")
            swatchTest(p.darkVibrantSwatch, b: vibDark, name: "Vibrant Dark")
            swatchTest(p.lightVibrantSwatch, b: vibLight, name: "Vibrant Light")
            swatchTest(p.mutedSwatch, b: mut, name: "Muted")
            swatchTest(p.darkMutedSwatch, b: mutDark, name: "Muted Dark")
            swatchTest(p.lightMutedColor, b: mutLight, name: "Muted Light")
    }

}
