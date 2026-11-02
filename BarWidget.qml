import QtQuick
import qs.Commons
import qs.Ui
import "Registry.js" as Registry

// Bar entry: keyboard glyph (gamepad in the gamer layout). Left click opens
// the settings panel, right click turns the overlay on/off, middle click
// cycles the layout.
BarWidget {
  id: root
  moduleName: "io.github.rewuschel.keycast"

  readonly property var hostService: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("io.github.rewuschel.keycast") : null
  property var ownService: null
  readonly property var service: hostService || ownService

  // A replacement bar gives no service lookup; pick up the one the service
  // published itself (it may load after the bar, hence the short retry).
  Timer {
    interval: 250
    repeat: true
    running: !root.hostService && !root.ownService
    onTriggered: root.ownService = Registry.service
  }
  readonly property bool on: service ? service.settings.enabled : false

  // Shape contract the bar uses to route shell summon/hide/toggle to us.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.service
  }

  onBarChanged: injectPanel()
  onServiceChanged: injectPanel()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.service && root.service.settings.layout === "gamer" ? "" : ""
    dimmed: !root.on
    active: root.opened
    tooltipText: !root.service ? "Keycast"
      : "Keycast · " + root.service.strings.t("layout." + root.service.settings.layout)
        + " · " + root.service.strings.t(root.service.statusKey)

    onPressed: function (b) {
      if (!root.service) return
      if (b === Qt.RightButton) root.service.toggle()
      else if (b === Qt.MiddleButton) root.service.cycleLayout()
      else root.togglePanel()
    }
  }
}
