import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Keycast settings popup, hosted by BarWidget.qml through a Loader. While it
// is open the overlay stays up (service.previewing), so every change shows on
// screen as it is made.
Panel {
  id: root
  moduleName: "io.github.rewuschel.keycast"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dimFg: Qt.darker(fg, 1.45)
  readonly property string mono: bar ? bar.fontFamily : Style.font.family
  readonly property var s: service ? service.settings : Model.DEFAULTS
  readonly property bool on: s.enabled

  function t(key, fallback) { return service ? service.strings.t(key, fallback) : (fallback || key) }
  function set(patch) { if (service) service.update(patch) }

  onOpenedChanged: if (service) service.previewing = opened

  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Section title with an optional value on the right ("SIZE   120%").
  component SectionLabel: Item {
    id: sectionLabel
    property string text: ""
    property string rightText: ""
    width: parent ? parent.width : 0
    height: lbl.implicitHeight
    PanelSectionHeader { id: lbl; text: sectionLabel.text; foreground: root.fg; fontFamily: root.mono }
    Text {
      anchors.right: parent.right
      anchors.baseline: lbl.baseline
      textFormat: Text.PlainText
      text: sectionLabel.rightText
      color: root.dimFg
      font.family: root.mono
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  // Title + caption on the left, switch on the right.
  component SwitchRow: Item {
    id: switchRow
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    signal toggled()
    width: parent ? parent.width : 0
    height: Math.max(col.implicitHeight, sw.implicitHeight)
    Column {
      id: col
      anchors.left: parent.left
      anchors.right: sw.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)
      Text { textFormat: Text.PlainText; text: switchRow.title; color: root.fg; font.family: root.mono; font.pixelSize: Style.font.body }
      Text {
        textFormat: Text.PlainText; text: switchRow.subtitle; color: root.dimFg
        font.family: root.mono; font.pixelSize: Style.font.caption; visible: text !== ""
        width: parent.width; wrapMode: Text.WordWrap
      }
    }
    ToggleSwitch {
      id: sw
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      foreground: root.fg
      trackHeight: 18
      checked: switchRow.checked
      onToggled: switchRow.toggled()
    }
  }

  // Pick-one row.
  component Choice: ButtonGroup {
    foreground: root.fg
    fontFamily: root.mono
    fontSize: Style.font.caption
    focusable: false
  }

  // Label over a slider.
  component SliderRow: Column {
    id: sliderRow
    property string title: ""
    property string valueText: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 0.05
    property bool integer: false
    signal moved(real v)
    width: parent ? parent.width : 0
    spacing: Style.space(4)
    SectionLabel { text: sliderRow.title; rightText: sliderRow.valueText }
    PanelSlider {
      bar: root.bar
      width: sliderRow.width
      minimum: sliderRow.minimum
      maximum: sliderRow.maximum
      step: sliderRow.step
      integer: sliderRow.integer
      value: sliderRow.value
      onMoved: function (v) { sliderRow.moved(v) }
    }
  }

  PopupCard {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.barIdentity
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Flickable {
      id: flick
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: column
        width: flick.width
        spacing: Style.space(12)

        // ---- hero ----
        PanelHero {
          width: parent.width
          title: "Keycast"
          meta: root.service ? root.t(root.service.statusKey) : root.t("status.starting")
          foreground: root.service && root.service.keysDenied ? Color.urgent : root.fg
          fontFamily: root.mono
          iconOpacity: root.on ? 1.0 : 0.5
          iconComponent: Component {
            Keycap {
              text: root.s.layout === "gamer" ? "W" : "Aa"
              held: root.on
              unit: Style.space(40)
              keyStyle: root.s.keyStyle
              fontFamily: root.mono
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              foreground: root.fg
              checked: root.on
              onToggled: if (root.service) root.service.toggle()
            }
          }
        }

        Text {
          width: parent.width
          visible: text !== ""
          textFormat: Text.PlainText
          text: !root.service ? ""
            : root.service.keysDenied ? root.t("panel.denied")
            : root.service.settings.enabled && root.service.fromHyprland && root.service.hyprlandError !== "" ? root.t("panel.nohyprland")
            : root.service.mouseDenied ? root.t("panel.mousedenied")
            : ""
          color: Color.urgent
          font.family: root.mono
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        // ---- input ----
        SectionLabel { text: root.t("panel.source") }
        Choice {
          value: root.s.source
          options: [
            { value: "hyprland", label: root.t("source.hyprland"), tooltip: root.t("source.hyprland.tip") },
            { value: "devices", label: root.t("source.devices"), tooltip: root.t("source.devices.tip") }
          ]
          onChanged: function (v) { root.set({ source: v }) }
        }

        // ---- layout ----
        SectionLabel { text: root.t("panel.layout") }
        Choice {
          value: root.s.layout
          options: [
            { value: "stream", label: root.t("layout.stream"), tooltip: root.t("layout.stream.tip") },
            { value: "gamer", label: root.t("layout.gamer"), tooltip: root.t("layout.gamer.tip") },
            { value: "both", label: root.t("layout.both"), tooltip: root.t("layout.both.tip") }
          ]
          onChanged: function (v) { root.set({ layout: v }) }
        }

        // ---- placement ----
        SectionLabel { text: root.t("panel.position") }
        Row {
          spacing: Style.space(14)

          // Reading order, so each button sits where the overlay will.
          Grid {
            columns: 3
            spacing: Style.space(4)
            Repeater {
              model: Model.POSITIONS
              Button {
                required property var modelData
                width: Style.space(26)
                height: Style.space(20)
                text: ""
                tooltipText: root.t("position." + modelData)
                bordered: true
                selected: root.s.position === modelData
                foreground: root.fg
                onClicked: root.set({ position: modelData })
              }
            }
          }

          Column {
            spacing: Style.space(6)
            Text {
              textFormat: Text.PlainText
              text: root.t("panel.monitor")
              color: root.dimFg
              font.family: root.mono
              font.pixelSize: Style.font.caption
            }
            Choice {
              value: root.s.monitor
              options: [
                { value: "focused", label: root.t("monitor.focused") },
                { value: "all", label: root.t("monitor.all") }
              ]
              onChanged: function (v) { root.set({ monitor: v }) }
            }
          }
        }

        SliderRow {
          title: root.t("panel.margin")
          valueText: root.s.margin + " px"
          minimum: 0; maximum: 300; step: 4; integer: true
          value: root.s.margin
          onMoved: function (v) { root.set({ margin: v }) }
        }

        PanelSeparator { foreground: root.fg }

        // ---- look ----
        SectionLabel { text: root.t("panel.style") }
        Choice {
          value: root.s.keyStyle
          options: [
            { value: "3d", label: root.t("style.3d") },
            { value: "flat", label: root.t("style.flat") },
            { value: "outline", label: root.t("style.outline") }
          ]
          onChanged: function (v) { root.set({ keyStyle: v }) }
        }

        SliderRow {
          title: root.t("panel.size")
          valueText: Math.round(root.s.scale * 100) + "%"
          minimum: 0.6; maximum: 2.5; step: 0.05
          value: root.s.scale
          onMoved: function (v) { root.set({ scale: v }) }
        }

        SliderRow {
          title: root.t("panel.background")
          valueText: Math.round(root.s.opacity * 100) + "%"
          minimum: 0; maximum: 1; step: 0.05
          value: root.s.opacity
          onMoved: function (v) { root.set({ opacity: v }) }
        }

        SectionLabel { text: root.t("panel.labels") }
        Choice {
          value: root.s.keymap
          options: [
            { value: "auto", label: root.t("keymap.auto", "System (%1)").arg(root.service ? root.service.layoutCode.toUpperCase() : "US"), tooltip: root.t("keymap.auto.tip") },
            { value: "us", label: root.t("keymap.us"), tooltip: root.t("keymap.us.tip") }
          ]
          onChanged: function (v) { root.set({ keymap: v }) }
        }

        // ---- stream ----
        PanelSeparator { foreground: root.fg; visible: root.s.layout !== "gamer" }
        Column {
          visible: root.s.layout !== "gamer"
          width: parent.width
          spacing: Style.space(10)

          SectionLabel { text: root.t("panel.stream") }
          Choice {
            value: root.s.filter
            options: [
              { value: "all", label: root.t("filter.all"), tooltip: root.t("filter.all.tip") },
              { value: "shortcuts", label: root.t("filter.shortcuts"), tooltip: root.t("filter.shortcuts.tip") }
            ]
            onChanged: function (v) { root.set({ filter: v }) }
          }
          SwitchRow {
            visible: root.s.filter === "all"
            title: root.t("stream.merge")
            subtitle: root.t("stream.merge.sub")
            checked: root.s.mergeTyping
            onToggled: root.set({ mergeTyping: !root.s.mergeTyping })
          }
          SwitchRow {
            title: root.t("stream.loneMods")
            subtitle: root.t("stream.loneMods.sub")
            checked: root.s.loneMods
            onToggled: root.set({ loneMods: !root.s.loneMods })
          }
          SwitchRow {
            title: root.t("stream.mouse")
            checked: root.s.streamMouse
            onToggled: root.set({ streamMouse: !root.s.streamMouse })
          }
          SwitchRow {
            title: root.t("stream.scroll")
            checked: root.s.streamScroll
            onToggled: root.set({ streamScroll: !root.s.streamScroll })
          }
          SliderRow {
            title: root.t("stream.linger")
            valueText: (root.s.linger / 1000).toFixed(1) + " s"
            minimum: 500; maximum: 8000; step: 250; integer: true
            value: root.s.linger
            onMoved: function (v) { root.set({ linger: v }) }
          }
          SliderRow {
            title: root.t("stream.maxItems")
            valueText: String(root.s.maxItems)
            minimum: 1; maximum: 10; step: 1; integer: true
            value: root.s.maxItems
            onMoved: function (v) { root.set({ maxItems: v }) }
          }
        }

        // ---- gamer ----
        PanelSeparator { foreground: root.fg; visible: root.s.layout !== "stream" }
        Column {
          visible: root.s.layout !== "stream"
          width: parent.width
          spacing: Style.space(10)

          SectionLabel { text: root.t("panel.gamer") }
          Choice {
            value: root.s.preset
            options: [
              { value: "compact", label: root.t("preset.compact"), tooltip: root.t("preset.compact.tip") },
              { value: "wasd", label: root.t("preset.wasd"), tooltip: root.t("preset.wasd.tip") },
              { value: "full", label: root.t("preset.full"), tooltip: root.t("preset.full.tip") }
            ]
            onChanged: function (v) { root.set({ preset: v }) }
          }
          SwitchRow {
            title: root.t("gamer.mouse")
            subtitle: root.t("gamer.mouse.sub")
            checked: root.s.gamerMouse
            onToggled: root.set({ gamerMouse: !root.s.gamerMouse })
          }
          SwitchRow {
            title: root.t("gamer.stats")
            subtitle: root.t("gamer.stats.sub")
            checked: root.s.stats
            onToggled: root.set({ stats: !root.s.stats })
          }
        }

        // ---- privacy ----
        PanelSeparator { foreground: root.fg }
        SectionLabel { text: root.t("panel.privacy") }
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.t("privacy.note")
          color: root.dimFg
          font.family: root.mono
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
        TextField {
          width: parent.width
          foreground: root.fg
          font.family: root.mono
          font.pixelSize: Style.font.caption
          placeholderText: root.service && root.service.activeApp !== ""
            ? root.t("privacy.placeholder.app", "app ids, e.g. %1").arg(root.service.activeApp)
            : root.t("privacy.placeholder")
          text: root.service ? root.service.denylistText() : ""
          onEditingFinished: if (root.service) root.service.setDenylistText(text)
          Keys.onEscapePressed: root.close()
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.t("panel.footer")
          color: root.dimFg
          font.family: root.mono
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
