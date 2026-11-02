import QtQuick
import qs.Commons

// One keycap. `units` is the width in key units (1 = a letter key); a cap
// whose label does not fit grows to fit it. Three looks:
//   3d      - a darker skirt with the top face sitting on it; the face sinks
//             onto the skirt while held
//   flat    - one face that fills with the accent while held
//   outline - hairline cap whose border and label take the accent while held
// Pressing snaps to the lit colour, releasing fades back, so quick taps still
// leave a visible trail.
Item {
  id: cap

  property string text: ""
  property bool held: false
  property real units: 1
  property real unit: 40
  property string keyStyle: "3d"
  property color foreground: Color.foreground
  property color background: Color.background
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property real fontScale: 1

  readonly property bool threeD: keyStyle === "3d"
  readonly property bool outline: keyStyle === "outline"
  readonly property real lip: threeD ? Math.max(2, Math.round(unit * 0.09)) : 0
  readonly property real gap: Math.max(2, Math.round(unit * 0.08))
  readonly property real radius: Math.max(3, Math.round(unit * 0.16))
  readonly property real pad: Math.round(unit * 0.28)
  readonly property real baseWidth: unit * units + gap * (Math.ceil(units) - 1)
  readonly property int labelSize: Math.max(8, Math.round(unit * (text.length > 1 ? 0.28 : 0.42) * fontScale))

  readonly property color faceIdle: outline ? Util.alpha(foreground, 0.04) : Qt.tint(background, Util.alpha(foreground, 0.16))
  readonly property color faceLit: outline ? Util.alpha(accent, 0.18) : accent
  readonly property color skirtIdle: Qt.tint(background, Util.alpha(foreground, 0.06))
  readonly property color skirtLit: Qt.darker(accent, 1.6)
  readonly property color labelIdle: foreground
  readonly property color labelLit: outline ? accent : background

  implicitWidth: Math.max(baseWidth, label.implicitWidth + pad * 2)
  implicitHeight: unit

  Rectangle {
    id: skirt
    visible: cap.threeD
    anchors.fill: parent
    radius: cap.radius
    color: cap.held ? cap.skirtLit : cap.skirtIdle
    border.width: 1
    border.color: Util.alpha(cap.foreground, 0.10)
    Behavior on color { ColorAnimation { duration: cap.held ? 25 : 320; easing.type: Easing.OutCubic } }
  }

  Rectangle {
    id: face
    x: cap.threeD ? cap.lip : 0
    width: parent.width - (cap.threeD ? cap.lip * 2 : 0)
    height: parent.height - (cap.threeD ? cap.lip * 2 : 0)
    y: cap.threeD ? (cap.held ? cap.lip * 1.6 : cap.lip * 0.4) : 0
    radius: Math.max(2, cap.radius - (cap.threeD ? 1 : 0))
    color: cap.held ? cap.faceLit : cap.faceIdle
    border.width: cap.outline ? Math.max(1, Math.round(cap.unit * 0.04)) : 1
    border.color: cap.held ? cap.accent : Util.alpha(cap.foreground, cap.outline ? 0.55 : 0.18)

    Behavior on color { ColorAnimation { duration: cap.held ? 25 : 320; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: cap.held ? 25 : 320 } }
    Behavior on y { NumberAnimation { duration: cap.held ? 20 : 140; easing.type: Easing.OutBack } }

    Text {
      id: label
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: cap.text
      color: cap.held ? cap.labelLit : cap.labelIdle
      font.family: cap.fontFamily
      font.pixelSize: cap.labelSize
      font.bold: true
      Behavior on color { ColorAnimation { duration: cap.held ? 25 : 320 } }
    }
  }
}
