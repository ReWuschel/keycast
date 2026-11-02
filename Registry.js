.pragma library

// The live Keycast service, for this plugin's own widget. The built-in bar
// hands widgets bar.shell.serviceFor(), but a replacement bar (a cloned
// omarchy.bar) only gets a facade without services, and the widget then
// could not reach its settings at all. A .pragma library file is one shared
// instance per shell, so Service.qml publishes itself here.
var service = null
