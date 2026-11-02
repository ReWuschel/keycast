import QtQuick
import qs.Commons

// The all-purpose layout: a run of recent keys. Plain typing merges into one
// wide cap, shortcuts get one cap per key joined by "+", repeats count up.
// Newest sits at the end; entries fade out over their last 400 ms.
Item {
  id: root

  property var service: null
  property bool vertical: false
  property bool alignEnd: false
  property real unit: 40
  property string keyStyle: "3d"
  property string fontFamily: Style.font.family
  property color foreground: Color.foreground
  property color background: Color.background
  property color accent: Color.accent

  readonly property real spacing: Math.round(unit * 0.32)
  readonly property bool empty: !service || service.streamModel.count === 0

  implicitWidth: empty && service && service.previewing ? hint.implicitWidth : flow.implicitWidth
  implicitHeight: empty && service && service.previewing ? hint.implicitHeight : flow.implicitHeight

  Keycap {
    id: hint
    visible: root.empty && root.service && root.service.previewing
    text: root.service ? root.service.strings.t("overlay.hint", "Keycast is ready, press something") : ""
    unit: root.unit
    units: 1
    keyStyle: root.keyStyle
    fontFamily: root.fontFamily
    foreground: root.foreground
    background: root.background
    accent: root.accent
    fontScale: 0.8
    opacity: 0.7
  }

  Grid {
    id: flow
    columns: root.vertical || !root.service ? 1 : Math.max(1, root.service.streamModel.count)
    spacing: root.spacing
    horizontalItemAlignment: root.alignEnd ? Grid.AlignRight : Grid.AlignLeft
    visible: !root.empty

    // No `add` transition: when an old entry expires while a new one is still
    // animating in, the resulting `move` interrupts `add` and leaves the new
    // entry stuck half faded. Each entry animates itself in instead (appear).
    move: Transition {
      NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
    }

    Repeater {
      model: root.service ? root.service.streamModel : null

      Item {
        id: entry

        required property string kind
        required property string text
        required property string parts
        required property int count
        required property double t

        readonly property var partList: entry.kind === "text" ? [] : entry.parts.split("\u0001")
        readonly property double age: root.service ? root.service.now - entry.t : 0
        readonly property double linger: root.service ? root.service.settings.linger : 2000

        // 0 -> 1 once when the entry is created: a scale pop only, so the key
        // is fully visible from its first frame. Owned by the delegate, so no
        // positioner transition can interrupt it.
        property real appear: 0
        NumberAnimation on appear { from: 0; to: 1; duration: 200; easing.type: Easing.OutBack }

        implicitWidth: body.implicitWidth
        implicitHeight: body.implicitHeight
        scale: 0.7 + 0.3 * entry.appear

        onTChanged: pulse.restart()

        Row {
          id: body
          spacing: Math.round(root.unit * 0.14)
          opacity: Math.max(0, Math.min(1, (entry.linger - entry.age) / 400))
          transformOrigin: Item.Center

          SequentialAnimation {
            id: pulse
            NumberAnimation { target: body; property: "scale"; to: 1.08; duration: 50 }
            NumberAnimation { target: body; property: "scale"; to: 1.0; duration: 160; easing.type: Easing.OutBack }
          }

          Keycap {
            visible: entry.kind === "text"
            text: entry.text
            held: entry.age < 90
            unit: root.unit
            units: 1
            keyStyle: root.keyStyle
            fontFamily: root.fontFamily
            foreground: root.foreground
            background: root.background
            accent: root.accent
            fontScale: 1.25
          }

          Repeater {
            model: entry.partList

            Row {
              id: partRow
              required property string modelData
              required property int index
              spacing: body.spacing

              Text {
                visible: partRow.index > 0
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "+"
                color: Util.alpha(root.foreground, 0.6)
                font.family: root.fontFamily
                font.pixelSize: Math.round(root.unit * 0.42)
                font.bold: true
              }

              Keycap {
                text: partRow.modelData
                held: entry.age < 90 && partRow.index === entry.partList.length - 1
                unit: root.unit
                units: 1
                keyStyle: root.keyStyle
                fontFamily: root.fontFamily
                foreground: root.foreground
                background: root.background
                accent: root.accent
              }
            }
          }

          Text {
            visible: entry.count > 1
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "×" + entry.count
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.unit * 0.42)
            font.bold: true
          }
        }
      }
    }
  }
}
