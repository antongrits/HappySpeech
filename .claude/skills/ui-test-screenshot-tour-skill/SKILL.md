---
name: ui-test-screenshot-tour-skill
description: Workflow для UI Tests target (XCUITest) с waitForExistence per screen, XCTAttachment screenshot, parse .xcresult → PNG extract. Replaces bash MCP screenshot которые ловят пустые экраны до render. Used в HappySpeech Plan v23 Block 1.1-1.2.
tools: Read, Write, Edit, Bash
---

# UI Test Screenshot Tour — Reliable Screen Capture

## Когда использовать

Старый подход в HappySpeech v17-v22:
- `mcp__ios-simulator__screenshot` после `launch_app` → screenshot снимался до render → пустой/loading экран

Новый подход v23:
- XCUITest UI test target с `waitForExistence(timeout:)` per screen
- Screenshot ТОЛЬКО после явного render confirm
- XCTAttachment с lifetime `.keepAlways` → сохраняется в .xcresult

## Структура target

`project.yml`:
```yaml
targets:
  HappySpeechUITests:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: 17.0
    sources:
      - HappySpeechUITests
    info:
      path: HappySpeechUITests/Info.plist
      properties:
        CFBundleName: HappySpeechUITests
    dependencies:
      - target: HappySpeech
```

## Workflow тур по экрану

```swift
import XCTest

final class AllScreensTourUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Theme через launchArguments — UITests-Light vs UITests-Dark schemes
        if ProcessInfo.processInfo.environment["HS_THEME"] == "dark" {
            app.launchArguments = ["-AppleInterfaceStyle", "Dark", "-UITEST_MODE", "1"]
        } else {
            app.launchArguments = ["-AppleInterfaceStyle", "Light", "-UITEST_MODE", "1"]
        }
        app.launch()
    }

    /// Универсальный метод: навигация → wait → screenshot
    private func captureScreen(name: String, waitFor: String, timeout: TimeInterval = 8) {
        let anchor = app.descendants(matching: .any).matching(identifier: waitFor).firstMatch
        XCTAssertTrue(anchor.waitForExistence(timeout: timeout), "Screen \(name) did not render: anchor \(waitFor) missing")

        // Дополнительное ожидание чтобы анимации завершились
        Thread.sleep(forTimeInterval: 0.5)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(name)_\(ProcessInfo.processInfo.environment["HS_THEME"] ?? "light")"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_screen_onboardingWelcome() {
        captureScreen(name: "onboardingWelcome", waitFor: "onboarding.welcome.title")
    }

    func test_screen_childHome() {
        // Navigate
        app.buttons["onboarding.skip"].tap()
        app.buttons["auth.skipAnonymous"].tap()
        captureScreen(name: "childHome", waitFor: "childHome.heroLabel")
    }

    // ... 110+ test methods
}
```

## Запуск

```bash
# Light
HS_THEME=light xcodebuild test \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeechUITests \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -resultBundlePath _workshop/v23_uitest_tour_light.xcresult

# Dark
HS_THEME=dark xcodebuild test \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeechUITests \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -resultBundlePath _workshop/v23_uitest_tour_dark.xcresult
```

## Extract PNG из .xcresult

```bash
extract_screenshots() {
    local xcresult=$1
    local outdir=$2
    mkdir -p "$outdir"
    # Список всех attachments
    xcrun xcresulttool get --legacy --path "$xcresult" --format json > /tmp/xcresult.json
    # Через jq extract attachment refs
    python3 << 'EOF'
import json, subprocess, os, sys
data = json.load(open('/tmp/xcresult.json'))
# Walk tests → activities → attachments
def walk(node, attachments=[]):
    if isinstance(node, dict):
        if node.get('_type', {}).get('_name') == 'ActionTestAttachment':
            attachments.append(node)
        for v in node.values():
            walk(v, attachments)
    elif isinstance(node, list):
        for v in node:
            walk(v, attachments)
    return attachments
all_attachments = walk(data)
for att in all_attachments:
    name = att.get('name', {}).get('_value', 'unknown')
    payload_ref = att.get('payloadRef', {}).get('id', {}).get('_value')
    if payload_ref and name.endswith(('light', 'dark')):
        out_path = os.path.join(os.environ['OUTDIR'], f"{name}.png")
        subprocess.run(['xcrun', 'xcresulttool', 'export', '--type', 'file',
                       '--path', os.environ['XCRESULT'], '--id', payload_ref,
                       '--output-path', out_path], check=False)
        print(out_path)
EOF
}

OUTDIR=_workshop/v23_uitest_tour XCRESULT=_workshop/v23_uitest_tour_light.xcresult \
  extract_screenshots _workshop/v23_uitest_tour_light.xcresult _workshop/v23_uitest_tour
```

## Verify

```bash
# Минимум 200 PNG (Light + Dark × 100+ screens)
ls _workshop/v23_uitest_tour/*.png | wc -l   # ≥200
```

## Critical: accessibilityIdentifier обязательны

В HappySpeech *View.swift нужно добавить `.accessibilityIdentifier("screenName.elementId")` на key elements чтобы UITests могли найти anchor для `waitForExistence`. Без identifier — wait fails → empty screenshot.

```swift
Text("Привет, дружок!")
    .accessibilityIdentifier("childHome.heroLabel")
```

## Преимущества над bash MCP screenshot

1. **Гарантированный render** — waitForExistence ждёт реального anchor element
2. **Reproducibility** — UI tests запускаются через CI/CD
3. **Coverage** — каждый screen test зафиксирован как unit
4. **Theme switching** — `app.launchArguments` без перезапуска симулятора
5. **Failure detection** — если экран не рендерится за 8 sec → test fails, мы видим точное место
