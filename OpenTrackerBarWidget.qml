import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // === State ===
    property var providers: []
    property bool isLoading: false
    property bool hasError: false
    property string errorMessage: ""
    property string lastUpdated: ""
    property string rawJsonBuffer: ""

    // === Settings ===
    property int refreshIntervalMs: {
        var val = pluginData.refreshInterval;
        return val ? parseInt(val) : 120000;
    }

    // === Derived: highest-usage provider for the bar pill ===
    readonly property var highestProvider: {
        if (providers.length === 0)
            return null;
        var filtered = providers.filter(function (p) {
            return p.usage && p.usage.rolling && !p.error;
        });
        if (filtered.length === 0)
            return null;
        var highest = filtered[0];
        for (var i = 1; i < filtered.length; i++) {
            if (filtered[i].usage.rolling.usedPercent > highest.usage.rolling.usedPercent)
                highest = filtered[i];
        }
        return highest;
    }

    readonly property real highestPercent: {
        if (!highestProvider || !highestProvider.usage || !highestProvider.usage.rolling)
            return 0;
        return highestProvider.usage.rolling.usedPercent;
    }

    readonly property string highestName: {
        if (!highestProvider)
            return "N/A";
        return formatProviderName(highestProvider.provider);
    }

    // === Helpers ===
    function getUsageColor(pct) {
        if (pct >= 80)
            return Theme.error;
        if (pct >= 60)
            return Theme.warning;
        return Theme.success;
    }

    function capitalizeFirst(s) {
        if (!s)
            return "";
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function formatProviderName(name) {
        if (name === "opencode-go")
            return "Opencode";
        return capitalizeFirst(name);
    }

    function formatTimeUntil(iso) {
        if (!iso)
            return "";
        var parts = iso.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?Z$/);
        var targetMs;
        if (parts) {
            var year = parseInt(parts[1], 10);
            var month = parseInt(parts[2], 10) - 1;
            var day = parseInt(parts[3], 10);
            var hour = parseInt(parts[4], 10);
            var minute = parseInt(parts[5], 10);
            var second = parseInt(parts[6], 10);
            targetMs = Date.UTC(year, month, day, hour, minute, second, 0);
        } else {
            var d = new Date(iso);
            if (isNaN(d.getTime()))
                return "";
            targetMs = d.getTime();
        }
        var diff = targetMs - Date.now();
        if (diff <= 0)
            return "now";
        var mins = Math.floor(diff / 60000);
        if (mins < 60)
            return mins + "m";
        var hrs = Math.floor(mins / 60);
        if (hrs < 24)
            return hrs + "h " + (mins % 60) + "m";
        var days = Math.floor(hrs / 24);
        return days + "d " + (hrs % 24) + "h";
    }

    // === Usage fetch ===
    Process {
        id: procUsage
        command: ["opentracker", "fetch", "opencode-go"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                root.rawJsonBuffer += data;
            }
        }
        stderr: SplitParser {
            onRead: line => console.warn("opentracker stderr:", line)
        }
        onExited: exitCode => {
            root.isLoading = false;
            if (exitCode === 0 && root.rawJsonBuffer.length > 0) {
                try {
                    var data = JSON.parse(root.rawJsonBuffer);
                    if (!Array.isArray(data))
                        data = [data];
                    root.providers = data;
                    root.hasError = false;
                    root.errorMessage = "";
                    root.lastUpdated = Qt.formatDateTime(new Date(), "hh:mm:ss");
                } catch (e) {
                    console.warn("opentracker: JSON parse error:", e);
                    root.hasError = true;
                    root.errorMessage = "Failed to parse opentracker output";
                }
            } else if (exitCode !== 0) {
                root.hasError = true;
                root.errorMessage = "opentracker exited with code " + exitCode;
            }
            root.rawJsonBuffer = "";
        }
    }

    function refresh(force) {
        if (procUsage.running)
            return;
        root.isLoading = true;
        root.rawJsonBuffer = "";
        if (force) {
            procUsage.command = ["opentracker", "fetch", "opencode-go", "--force"];
        } else {
            procUsage.command = ["opentracker", "fetch", "opencode-go"];
        }
        procUsage.running = true;
    }

    Timer {
        interval: root.refreshIntervalMs
        running: true
        repeat: true
        onTriggered: root.refresh(false)
    }

    Component.onCompleted: {
        root.refresh(false);
    }

    // === Bar pill (horizontal) ===
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "monitoring"
                size: Theme.iconSize - 6
                color: root.getUsageColor(root.highestPercent)
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: {
                    if (root.hasError && root.providers.length === 0)
                        return "ERR";
                    if (root.isLoading && root.providers.length === 0)
                        return "...";
                    if (!root.highestProvider)
                        return "N/A";
                    return root.highestName + " " + Math.round(root.highestPercent) + "%";
                }
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.getUsageColor(root.highestPercent)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // === Bar pill (vertical) ===
    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "monitoring"
                size: Theme.iconSize - 6
                color: root.getUsageColor(root.highestPercent)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: {
                    if (!root.highestProvider)
                        return "--";
                    return Math.round(root.highestPercent) + "%";
                }
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.getUsageColor(root.highestPercent)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // === Popout ===
    popoutWidth: 420
    popoutHeight: 0

    popoutContent: Component {
        PopoutComponent {
            id: popup
            headerText: "OpenTracker"
            detailsText: root.lastUpdated ? ("Updated " + root.lastUpdated) : ""
            showCloseButton: true

            headerActions: Component {
                Row {
                    spacing: Theme.spacingXS

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: refreshTap.pressed ? Theme.surfaceContainerHighest : refreshArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "refresh"
                            size: 16
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            TapHandler {
                                id: refreshTap
                                onTapped: root.refresh(true)
                            }
                        }
                    }
                }
            }

            Item {
                id: contentWrapper
                width: parent.width
                implicitHeight: mainCol.implicitHeight

                Column {
                    id: mainCol
                    width: parent.width
                    spacing: Theme.spacingS

                    // Error banner
                    StyledRect {
                        width: parent.width
                        height: errCol.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)
                        visible: root.hasError && root.providers.length === 0

                        Column {
                            id: errCol
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingXS

                            Row {
                                spacing: Theme.spacingS
                                DankIcon {
                                    name: "error"
                                    size: 18
                                    color: Theme.error
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: root.errorMessage
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.error
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Loading
                    StyledText {
                        visible: root.isLoading && root.providers.length === 0
                        text: "Fetching usage data..."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Provider cards
                    Repeater {
                        model: root.providers

                        StyledRect {
                            required property var modelData
                            required property int index

                            width: mainCol.width
                            height: providerCol.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh

                            Column {
                                id: providerCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingS

                                // Provider name + login
                                Row {
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: root.capitalizeFirst(modelData.provider)
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                    }


                                }

                                // Error state for this provider
                                Row {
                                    visible: !!modelData.error
                                    spacing: Theme.spacingXS

                                    DankIcon {
                                        name: "warning"
                                        size: 14
                                        color: Theme.error
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: modelData.error ? (modelData.error.message || "Error") : ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.error
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Rolling window
                                Column {
                                    width: parent.width
                                    spacing: 2
                                    visible: !!modelData.usage && !!modelData.usage.rolling

                                    Item {
                                        width: parent.width
                                        height: Math.max(primLabel.implicitHeight, primValue.implicitHeight)

                                        StyledText {
                                            id: primLabel
                                            anchors.left: parent.left
                                            text: "Session"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                        StyledText {
                                            id: primValue
                                            anchors.right: parent.right
                                            text: {
                                                if (!modelData.usage || !modelData.usage.rolling)
                                                    return "";
                                                var pct = Math.round(modelData.usage.rolling.usedPercent);
                                                var reset = root.formatTimeUntil(modelData.usage.rolling.resetsAt);
                                                return pct + "%" + (reset ? " \u00B7 " + reset : "");
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: root.getUsageColor(modelData.usage && modelData.usage.rolling ? modelData.usage.rolling.usedPercent : 0)
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 6
                                        radius: 3
                                        color: Theme.surfaceContainerHighest

                                        Rectangle {
                                            width: {
                                                var pct = modelData.usage && modelData.usage.rolling ? modelData.usage.rolling.usedPercent : 0;
                                                return Math.min(1, pct / 100) * parent.width;
                                            }
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.getUsageColor(modelData.usage && modelData.usage.rolling ? modelData.usage.rolling.usedPercent : 0)
                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }
                                }

                                // Weekly window
                                Column {
                                    width: parent.width
                                    spacing: 2
                                    visible: !!modelData.usage && !!modelData.usage.weekly

                                    Item {
                                        width: parent.width
                                        height: Math.max(secLabel.implicitHeight, secValue.implicitHeight)

                                        StyledText {
                                            id: secLabel
                                            anchors.left: parent.left
                                            text: "Weekly"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                        StyledText {
                                            id: secValue
                                            anchors.right: parent.right
                                            text: {
                                                if (!modelData.usage || !modelData.usage.weekly)
                                                    return "";
                                                var pct = Math.round(modelData.usage.weekly.usedPercent);
                                                var reset = root.formatTimeUntil(modelData.usage.weekly.resetsAt);
                                                return pct + "%" + (reset ? " \u00B7 " + reset : "");
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: root.getUsageColor(modelData.usage && modelData.usage.weekly ? modelData.usage.weekly.usedPercent : 0)
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 6
                                        radius: 3
                                        color: Theme.surfaceContainerHighest

                                        Rectangle {
                                            width: {
                                                var pct = modelData.usage && modelData.usage.weekly ? modelData.usage.weekly.usedPercent : 0;
                                                return Math.min(1, pct / 100) * parent.width;
                                            }
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.getUsageColor(modelData.usage && modelData.usage.weekly ? modelData.usage.weekly.usedPercent : 0)
                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }
                                }

                                // Monthly window
                                Column {
                                    width: parent.width
                                    spacing: 2
                                    visible: !!modelData.usage && !!modelData.usage.monthly

                                    Item {
                                        width: parent.width
                                        height: Math.max(terLabel.implicitHeight, terValue.implicitHeight)

                                        StyledText {
                                            id: terLabel
                                            anchors.left: parent.left
                                            text: "Monthly"
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                        StyledText {
                                            id: terValue
                                            anchors.right: parent.right
                                            text: {
                                                if (!modelData.usage || !modelData.usage.monthly)
                                                    return "";
                                                var pct = Math.round(modelData.usage.monthly.usedPercent);
                                                var reset = root.formatTimeUntil(modelData.usage.monthly.resetsAt);
                                                return pct + "%" + (reset ? " \u00B7 " + reset : "");
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: root.getUsageColor(modelData.usage && modelData.usage.monthly ? modelData.usage.monthly.usedPercent : 0)
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 6
                                        radius: 3
                                        color: Theme.surfaceContainerHighest

                                        Rectangle {
                                            width: {
                                                var pct = modelData.usage && modelData.usage.monthly ? modelData.usage.monthly.usedPercent : 0;
                                                return Math.min(1, pct / 100) * parent.width;
                                            }
                                            height: parent.height
                                            radius: parent.radius
                                            color: root.getUsageColor(modelData.usage && modelData.usage.monthly ? modelData.usage.monthly.usedPercent : 0)
                                        }
                                    }
                                }




                            }
                        }
                    }

                    // No providers
                    StyledText {
                        visible: root.providers.length === 0 && !root.hasError && !root.isLoading
                        text: "No providers found. Run 'opentracker login opencode-go' to configure."
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceVariantText
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
