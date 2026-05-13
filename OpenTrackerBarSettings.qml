import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "openTrackerBar"

    StyledText {
        width: parent.width
        text: "OpenTracker"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Monitor OpenCode.ai usage via opentracker CLI. Tracks session, weekly and monthly rate windows."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // --- Refresh Interval ---

    StyledText {
        width: parent.width
        text: "Refresh Interval"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    DankDropdown {
        id: refreshDropdown
        text: "Refresh Interval"
        description: "How often to fetch usage data via opentracker"
        currentValue: root.loadValue("refreshInterval", "120000")
        options: ["60000", "120000", "300000", "900000", "1800000"]
        dropdownWidth: 180
        onValueChanged: function (value) {
            root.saveValue("refreshInterval", value);
        }
    }

    StyledText {
        width: parent.width
        leftPadding: Theme.spacingM
        text: {
            var v = refreshDropdown.currentValue;
            if (v === "60000")
                return "Refreshes every 1 minute";
            if (v === "120000")
                return "Refreshes every 2 minutes";
            if (v === "300000")
                return "Refreshes every 5 minutes";
            if (v === "900000")
                return "Refreshes every 15 minutes";
            if (v === "1800000")
                return "Refreshes every 30 minutes";
            return "";
        }
        font.pixelSize: Theme.fontSizeSmall
        font.italic: true
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outline
        opacity: 0.3
    }

    // --- Setup ---

    StyledText {
        width: parent.width
        text: "Setup"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS
        leftPadding: Theme.spacingM
        bottomPadding: Theme.spacingL

        Repeater {
            model: [
                "1. Install opentracker: yay -S opentracker-cli",
                "2. Run: opentracker login opencode-go",
                "3. Log in to opencode.ai in your browser",
                "4. Export cookies (Netscape format) to ~/.config/opentracker/opencode-cookies.txt",
                "5. Run: opentracker fetch opencode-go (first run will ask for workspace ID)"
            ]

            StyledText {
                required property string modelData
                text: modelData
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width - Theme.spacingM
                wrapMode: Text.WordWrap
            }
        }
    }
}
