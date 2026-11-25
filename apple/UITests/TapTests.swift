import XCTest

/// Comprueba en el simulador que tocar un correo lo abre (con datos de ejemplo, -preview)
final class TapTests: XCTestCase {
    func testPullShowsLogo() {
        let app = XCUIApplication()
        app.launchArguments = ["-preview"]
        app.launch()
        let row = app.staticTexts["Muestras de lana fría"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 380)), withVelocity: .slow, thenHoldForDuration: 0.1)
        Thread.sleep(forTimeInterval: 0.6)
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: NSHomeDirectory().components(separatedBy: "/Library/Developer").first! + "/SantoroMail-app/shots/pull.png"))
        let a = XCTAttachment(screenshot: shot); a.lifetime = .keepAlways; add(a)
    }

    func testTapOpensMail() {
        let app = XCUIApplication()
        app.launchArguments = ["-preview"]
        app.launch()
        let row = app.staticTexts["Muestras de lana fría"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no aparece la lista")
        row.tap()
        XCTAssertTrue(app.staticTexts["info@ferla.it"].waitForExistence(timeout: 6), "tocar el correo no lo abre")
        // volver atrás y abrir otro
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let second = app.staticTexts["Camisa a medida para boda"]
        XCTAssertTrue(second.waitForExistence(timeout: 6))
        second.tap()
        XCTAssertTrue(app.staticTexts["marta@gmail.com"].waitForExistence(timeout: 6), "el segundo correo no se abre")
    }
}
