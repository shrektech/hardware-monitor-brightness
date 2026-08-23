import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as Plasma5Support

/*
 * Hardware Monitor Brightness Plasmoid
 * ====================================
 * A lightweight, flicker-free hardware DDC/CI brightness control widget for KDE Plasma 6.
 *
 * Features:
 * - Direct mouse-wheel scrolling on the taskbar icon (+/- step size).
 * - Optional percentage badge next to the taskbar icon.
 * - Master slider adjusting all connected displays simultaneously.
 * - One-click preset quick buttons (25%, 50%, 75%, 100%).
 * - Individual per-display sliders with live model names and IDs.
 * - Asynchronous debouncing engine avoiding bus lockups and UI freezes.
 */
PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: "monitorian-brightness"
    toolTipMainText: i18n("Hardware Monitor Brightness")
    toolTipSubText: `${masterBrightness}%`

    // Dynamically resolve self-contained worker script path (zero hardcoded paths)
    readonly property string workerScript: Qt.resolvedUrl("../scripts/brightness-worker.py").toString().replace("file://", "")
    readonly property string customIcon: Qt.resolvedUrl("../images/monitorian.svg")
    readonly property bool showIndividual: (plasmoid.configuration.showIndividualSliders !== false)
    readonly property bool showBadge: (plasmoid.configuration.showPercentage === true)

    property int masterBrightness: 50
    property bool isDragging: false

    // =========================================================================
    // Control & Synchronization Functions
    // =========================================================================

    // Query active state from the backend (or force a hardware re-probe)
    function refreshDisplays(force) {
        var cmd = force ? `${workerScript} rescan #${Date.now()}` : `${workerScript} get #${Date.now()}`;
        queryRunner.exec(cmd);
    }

    // Set brightness across all displays and sync individual sliders
    function setMasterBrightness(val) {
        masterBrightness = Math.max(0, Math.min(100, Math.round(val)));
        for (var i = 0; i < displayModel.count; ++i) {
            displayModel.setProperty(i, "brightness", masterBrightness);
        }
        cmdRunner.exec(`${workerScript} set ${masterBrightness} #${Date.now()}`);
    }

    // Adjust master brightness by relative step from mouse wheel
    function adjustMasterBrightness(delta) {
        var step = plasmoid.configuration.stepSize || 5;
        var finalDelta = (delta > 0) ? `+${step}` : `-${step}`;
        if (plasmoid.configuration.invertScroll) {
            finalDelta = (delta > 0) ? `-${step}` : `+${step}`;
        }
        cmdRunner.exec(`${workerScript} ${finalDelta} #${Date.now()}`);
        queryTimer.restart();
    }

    // Set brightness for a specific individual display
    function setDisplayBrightness(displayId, val) {
        var clamped = Math.max(0, Math.min(100, Math.round(val)));
        cmdRunner.exec(`${workerScript} set_display ${displayId} ${clamped} #${Date.now()}`);
    }

    Component.onCompleted: {
        refreshDisplays(false);
    }

    // ListModel holding detected monitor models, IDs, and brightness percentages
    ListModel {
        id: displayModel
    }

    // =========================================================================
    // Asynchronous Execution Engines (Plasma5Support executable DataSources)
    // =========================================================================

    // Command runner for write operations
    Plasma5Support.DataSource {
        id: cmdRunner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);
        }
        function exec(cmd) {
            if (cmd) connectSource(cmd);
        }
    }

    // Query runner for reading state JSON
    Plasma5Support.DataSource {
        id: queryRunner
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var out = (data["stdout"] || "").trim();
            try {
                var res = JSON.parse(out);
                if (res.master !== undefined && !root.isDragging) {
                    root.masterBrightness = res.master;
                }
                if (res.displays && Array.isArray(res.displays) && res.displays.length > 0) {
                    // Update model in-place if count matches to prevent UI flicker
                    if (displayModel.count === res.displays.length) {
                        for (var i = 0; i < res.displays.length; ++i) {
                            if (!root.isDragging) {
                                displayModel.setProperty(i, "brightness", res.displays[i].brightness || 50);
                            }
                        }
                    } else {
                        displayModel.clear();
                        for (var j = 0; j < res.displays.length; ++j) {
                            displayModel.append({
                                displayId: res.displays[j].display,
                                modelName: res.displays[j].model || `Display ${res.displays[j].display}`,
                                serialNumber: res.displays[j].serial || "",
                                brightness: res.displays[j].brightness || 50
                            });
                        }
                    }
                }
            } catch (e) {
                console.warn("HardwareBrightness: Failed to parse state json:", e);
            }
            disconnectSource(sourceName);
        }
        function exec(cmd) {
            if (cmd) connectSource(cmd);
        }
    }

    // Debounce timer for refreshing state after adjustments
    Timer {
        id: queryTimer
        interval: 200
        repeat: false
        onTriggered: root.refreshDisplays(false)
    }

    // Debounce timer for smooth slider dragging (avoids micro-command flooding)
    Timer {
        id: masterDebounceTimer
        interval: 40
        repeat: false
        onTriggered: root.setMasterBrightness(masterBrightness)
    }

    // =========================================================================
    // 1. Taskbar Compact Representation (Panel Icon + Scroll + Badge)
    // =========================================================================
    compactRepresentation: MouseArea {
        id: compactRoot
        Layout.minimumWidth: root.showBadge ? (Kirigami.Units.gridUnit * 3.4) : (Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2)
        Layout.preferredWidth: root.showBadge ? (Kirigami.Units.gridUnit * 3.8) : (Kirigami.Units.iconSizes.medium)
        Layout.fillHeight: true
        hoverEnabled: true

        onClicked: {
            root.refreshDisplays(false);
            root.expanded = !root.expanded;
        }

        onWheel: (wheel) => {
            root.adjustMasterBrightness(wheel.angleDelta.y);
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 2
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Math.min(parent.height - 4, Kirigami.Units.iconSizes.medium)
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter
                source: root.customIcon
            }

            PlasmaComponents3.Label {
                visible: root.showBadge
                text: `${root.masterBrightness}%`
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // =========================================================================
    // 2. Popup Full Representation (Header + Master Controls + Multi-Monitor Sliders)
    // =========================================================================
    fullRepresentation: ColumnLayout {
        id: fullRoot
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        spacing: Kirigami.Units.mediumSpacing

        // Header Bar with Rescan Button
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.customIcon
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }

            Kirigami.Heading {
                level: 3
                text: i18n("Hardware Brightness")
                Layout.fillWidth: true
            }

            PlasmaComponents3.ToolButton {
                icon.name: "view-refresh"
                text: i18n("Rescan")
                display: PlasmaComponents3.AbstractButton.IconOnly
                onClicked: root.refreshDisplays(true)
                PlasmaComponents3.ToolTip.text: i18n("Rescan connected displays")
                PlasmaComponents3.ToolTip.visible: hovered
            }
        }

        // Section A: Master Brightness Control
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents3.Label {
                    text: i18n("All Displays")
                    font.bold: true
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Label {
                    text: `${root.masterBrightness}%`
                    font.bold: true
                }
            }

            PlasmaComponents3.Slider {
                id: masterSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: plasmoid.configuration.stepSize || 5
                value: root.masterBrightness
                onPressedChanged: {
                    root.isDragging = pressed;
                }
                onMoved: {
                    root.masterBrightness = Math.round(value);
                    masterDebounceTimer.restart();
                }
            }

            // Quick Preset Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    text: "25%"
                    Layout.fillWidth: true
                    onClicked: root.setMasterBrightness(25)
                }
                PlasmaComponents3.Button {
                    text: "50%"
                    Layout.fillWidth: true
                    onClicked: root.setMasterBrightness(50)
                }
                PlasmaComponents3.Button {
                    text: "75%"
                    Layout.fillWidth: true
                    onClicked: root.setMasterBrightness(75)
                }
                PlasmaComponents3.Button {
                    text: "100%"
                    Layout.fillWidth: true
                    onClicked: root.setMasterBrightness(100)
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: root.showIndividual && displayModel.count > 0
        }

        // Section B: Individual Per-Display Sliders List
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showIndividual && displayModel.count > 0
            spacing: Kirigami.Units.mediumSpacing

            PlasmaComponents3.Label {
                text: i18n("Individual Displays")
                font.bold: true
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            Repeater {
                model: displayModel
                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents3.Label {
                            text: `${model.modelName} (#${model.displayId})`
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        PlasmaComponents3.Label {
                            text: `${Math.round(indivSlider.value)}%`
                        }
                    }

                    PlasmaComponents3.Slider {
                        id: indivSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        stepSize: plasmoid.configuration.stepSize || 5
                        value: model.brightness
                        onPressedChanged: {
                            root.isDragging = pressed;
                        }
                        onMoved: {
                            var v = Math.round(value);
                            displayModel.setProperty(index, "brightness", v);
                            root.setDisplayBrightness(model.displayId, v);
                        }
                    }
                }
            }
        }
    }
}
