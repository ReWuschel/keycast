import QtQuick
import qs.Commons
import "Model.js" as Model

// The gamer layout: a fixed board that lights every held key, an optional
// mouse beside it, and live keys-per-second / actions-per-minute.
Item {
  id: root

  property var service: null
  property real unit: 40
  property string keyStyle: "3d"
  property string fontFamily: Style.font.family
  property color foreground: Color.foreground
  property color background: Color.background
  property color accent: Color.accent

  readonly property var held: service ? service.held : ({})
  readonly property var settings: service ? service.settings : Model.DEFAULTS
  readonly property var rows: Model.board(settings.preset)
  readonly property real gap: Math.max(2, Math.round(unit * 0.08))
  readonly property var keyTable: service ? service.keyTable : null

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  Row {
    id: layout
    spacing: Math.round(root.unit * 0.4)

    Column {
      id: board
      spacing: root.gap
      anchors.bottom: parent.bottom

      Repeater {
        model: root.rows

        Row {
          id: boardRow
          required property var modelData
          spacing: root.gap

          Repeater {
            model: boardRow.modelData

            Item {
              id: cell
              required property var modelData
              readonly property int code: modelData[0]
              readonly property real units: modelData[1]

              width: cell.code === 0
                ? root.unit * cell.units
                : root.unit * cell.units + root.gap * (Math.ceil(cell.units) - 1)
              height: root.unit

              Keycap {
                visible: cell.code !== 0
                width: parent.width
                height: parent.height
                text: Model.label(cell.code, root.keyTable)
                held: root.held[cell.code] === true
                unit: root.unit
                units: cell.units
                keyStyle: root.keyStyle
                fontFamily: root.fontFamily
                foreground: root.foreground
                background: root.background
                accent: root.accent
              }
            }
          }
        }
      }
    }

    Column {
      anchors.bottom: parent.bottom
      spacing: Math.round(root.unit * 0.25)
      visible: root.settings.gamerMouse || root.settings.stats

      MouseView {
        visible: root.settings.gamerMouse
        anchors.horizontalCenter: parent.horizontalCenter
        service: root.service
        unit: root.unit
        foreground: root.foreground
        background: root.background
        accent: root.accent
        keyStyle: root.keyStyle
      }

      Column {
        visible: root.settings.stats
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.service ? String(root.service.kps) : "0"
          color: root.service && root.service.kps > 0 ? root.accent : Util.alpha(root.foreground, 0.5)
          font.family: root.fontFamily
          font.pixelSize: Math.round(root.unit * 0.6)
          font.bold: true
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.service ? root.service.strings.t("overlay.kps", "KPS") : "KPS"
          color: Util.alpha(root.foreground, 0.55)
          font.family: root.fontFamily
          font.pixelSize: Math.max(7, Math.round(root.unit * 0.22))
          font.bold: true
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.service ? String(root.service.apm) : "0"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Math.round(root.unit * 0.42)
          font.bold: true
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: root.service ? root.service.strings.t("overlay.apm", "APM") : "APM"
          color: Util.alpha(root.foreground, 0.55)
          font.family: root.fontFamily
          font.pixelSize: Math.max(7, Math.round(root.unit * 0.22))
          font.bold: true
        }
      }
    }
  }
}
