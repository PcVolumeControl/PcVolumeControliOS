import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testCaptureConnectionScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshotMode"]
        setupSnapshot(app)
        app.launch()
        snapshot("01_ConnectionScreen")
    }

    func testCaptureAutoDiscoveryScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshotMode", "--mockDiscovered"]
        setupSnapshot(app)
        app.launch()
        // The injected server appears as an auto-discovered row, whose connect
        // button carries the server's computer name as its accessibility label.
        let discoveredRow = app.buttons["Connect to MYPC"]
        XCTAssert(discoveredRow.waitForExistence(timeout: 5))
        snapshot("02_AutoDiscovery")
    }

    func testCaptureSliderScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshotMode", "--mockConnected"]
        setupSnapshot(app)
        app.launch()
        // Wait for the slider view to appear (the overflow menu button is unique to SliderView).
        let moreOptions = app.buttons["More options"]
        XCTAssert(moreOptions.waitForExistence(timeout: 5))
        snapshot("03_SliderScreen")
    }

    func testCaptureDeviceSelectorScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshotMode", "--mockConnected"]
        setupSnapshot(app)
        app.launch()
        let selectDevice = app.buttons["Select master device"]
        XCTAssert(selectDevice.waitForExistence(timeout: 5))
        selectDevice.tap()
        // The slide-up sheet carries the navigation title "Select Master Device".
        let sheetTitle = app.staticTexts["Select Master Device"]
        XCTAssert(sheetTitle.waitForExistence(timeout: 3))
        snapshot("04_DeviceSelector")
    }

    func testCaptureSettingsScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshotMode", "--mockConnected"]
        setupSnapshot(app)
        app.launch()
        let moreOptions = app.buttons["More options"]
        XCTAssert(moreOptions.waitForExistence(timeout: 5))
        moreOptions.tap()
        let settingsButton = app.buttons["Settings"]
        XCTAssert(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()
        snapshot("05_SettingsScreen")
    }
}
