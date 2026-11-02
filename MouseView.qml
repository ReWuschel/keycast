import QtQuick
import qs.Commons

// A mouse drawn from rectangles: left and right buttons, the wheel (lit while
// the middle button is held, an arrow flashes on each notch) and the two side
// buttons. evdev codes: 272 left, 273 right, 274 middle, 275 side, 276 extra.
Item {
  id: root

  property var service: null
  property real unit: 40
  property string keyStyle: "3d"
  property color foreground: Color.foreground
  property color background: Color.background
  property color accent: Color.accent

  readonly property var held: service ? service.held : ({})
  readonly property int wheelDir: service ? service.wheelFlash : 0
  readonly property real w: Math.round(unit * 2.1)
  readonly property real h: Math.round(unit * 3.1)
  readonly property real r: Math.round(w * 0.42)
  readonly property real line: Math.max(1, Math.round(unit * 0.05))
  readonly property bool outline: keyStyle === "outline"
  readonly property color idle: outline ? Util.alpha(foreground, 0.04) : Qt.tint(background, Util.alpha(foreground, 0.16))
  readonly property color edge: Util.alpha(foreground, outline ? 0.55 : 0.2)

  function lit(code) { return root.held[code] === true }
  function fill(on) { return on ? (root.outline ? Util.alpha(root.accent, 0.25) : root.accent) : root.idle }

  implicitWidth: w + Math.round(unit * 0.3)
  implicitHeight: h

  component Part: Rectangle {
    id: part
    property bool on: false
    color: root.fill(on)
    border.width: root.line
    border.color: on ? root.accent : root.edge
    Behavior on color { ColorAnimation { duration: part.on ? 25 : 320; easing.type: Easing.OutCubic } }
  }

  // Body, behind the buttons.
  Rectangle {
    id: body
    x: Math.round(root.unit * 0.3)
    width: root.w
    height: root.h
    radius: root.r
    color: Qt.tint(root.background, Util.alpha(root.foreground, 0.06))
    border.width: root.line
    border.color: root.edge
  }

  // Left and right buttons: the top 42% of the body, split down the middle.
  Item {
    x: body.x
    width: body.width
    height: Math.round(body.height * 0.42)
    clip: true

    Part {
      on: root.lit(272)
      x: 0
      width: parent.width / 2 - root.line
      height: parent.height + root.r
      radius: root.r
      topRightRadius: 0
      bottomRightRadius: 0
      bottomLeftRadius: 0
    }
    Part {
      on: root.lit(273)
      x: parent.width / 2 + root.line
      width: parent.width / 2 - root.line
      height: parent.height + root.r
      radius: root.r
      topLeftRadius: 0
      bottomLeftRadius: 0
      bottomRightRadius: 0
    }
  }

  // Wheel.
  Part {
    on: root.lit(274) || root.wheelDir !== 0
    x: body.x + body.width / 2 - width / 2
    y: Math.round(body.height * 0.1)
    width: Math.round(root.unit * 0.32)
    height: Math.round(body.height * 0.24)
    radius: width / 2

    Text {
      anchors.centerIn: parent
      visible: root.wheelDir !== 0
      textFormat: Text.PlainText
      text: root.wheelDir > 0 ? "▲" : "▼"
      color: root.outline ? root.accent : root.background
      font.pixelSize: Math.max(6, Math.round(root.unit * 0.2))
    }
  }

  // Side buttons on the left flank: 276 (forward) above 275 (back).
  Part {
    on: root.lit(276)
    x: 0
    y: Math.round(body.height * 0.48)
    width: Math.round(root.unit * 0.42)
    height: Math.round(body.height * 0.15)
    radius: Math.round(width * 0.4)
  }
  Part {
    on: root.lit(275)
    x: 0
    y: Math.round(body.height * 0.66)
    width: Math.round(root.unit * 0.42)
    height: Math.round(body.height * 0.15)
    radius: Math.round(width * 0.4)
  }
}
