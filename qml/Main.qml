// rln_ui view — backend:module pattern. NO direct core access: the view reads its backend
// replica (logos.module("rln_ui")) and calls its slots via logos.watch. All delivery/RLN
// interaction lives in the C++ backend (src/RlnBackend.*).
import QtQuick 2.15
import QtQuick.Layouts 1.15
import Logos.Controls
import Logos.Theme

Rectangle {
    id: root
    objectName: "rlnRoot"
    width: 420; height: 760
    color: Theme.palette.background

    readonly property var backend: logos.module("rln_ui")
    property bool ready: false
    property string actionNote: ""

    readonly property int cardW: Math.min(width - 2 * Theme.spacing.xlarge, 560)
    function shorten(s) { return (s && s.length > 16) ? (s.slice(0, 8) + "…" + s.slice(-6)) : (s || "—") }

    // convenience readers (guard against a not-yet-ready backend)
    readonly property string nodeRln:    ready && backend ? backend.nodeRlnState   : "unknown"
    readonly property string delivery:   ready && backend ? backend.deliveryStatus : "starting"
    readonly property string member:     ready && backend ? backend.membershipState: "unknown"
    readonly property int    memberCount:ready && backend ? backend.membershipCount : 0
    readonly property string quota:      ready && backend ? backend.quota           : "—"
    readonly property string registry:   ready && backend ? backend.registryId      : ""
    readonly property string identity:   ready && backend ? backend.rlnIdentifier   : ""
    readonly property int    epoch:      ready && backend ? backend.epochSizeSec     : 0
    readonly property bool   hasMembership: memberCount > 0 || member === "active"

    function begin() { if (root.ready) root.backend.start() }
    Connections {
        target: logos
        function onViewModuleReadyChanged(name, isReady) {
            if (name !== "rln_ui") return
            root.ready = isReady && root.backend !== null
            root.begin()
        }
    }
    Component.onCompleted: {
        root.ready = root.backend !== null && logos.isViewModuleReady("rln_ui")
        root.begin()
    }

    LogosScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ColumnLayout {
            width: root.cardW
            x: Math.max(Theme.spacing.xlarge, (root.width - width) / 2)
            y: Theme.spacing.xlarge
            spacing: Theme.spacing.large

            // Header
            RowLayout {
                Layout.fillWidth: true; spacing: Theme.spacing.small
                ColumnLayout {
                    spacing: 0
                    LogosText { text: "RLN membership"; font.pixelSize: Theme.typography.panelTitleText; font.weight: Theme.typography.weightBold }
                    LogosText { text: "Rate-limit membership for sending over Logos Messaging"
                        color: Theme.palette.textSecondary; font.pixelSize: Theme.typography.secondaryText
                        wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
                Item { Layout.fillWidth: true }
                LogosBadge {
                    Layout.alignment: Qt.AlignVCenter
                    text:  root.nodeRln === "Ready" ? "RLN Ready" : ("RLN " + root.nodeRln)
                    color: root.nodeRln === "Ready" ? Theme.palette.success : Theme.palette.textSecondary
                }
            }

            // Status card
            Rectangle {
                Layout.fillWidth: true; radius: Theme.spacing.radiusSmall
                color: Theme.palette.surface; border.color: Theme.palette.border; border.width: 1
                Layout.preferredHeight: statusCol.implicitHeight + 2 * Theme.spacing.medium
                ColumnLayout {
                    id: statusCol
                    anchors.fill: parent; anchors.margins: Theme.spacing.medium; spacing: Theme.spacing.small
                    RowLayout {
                        Layout.fillWidth: true
                        LogosText { text: "Membership"; color: Theme.palette.textSecondary; Layout.fillWidth: true }
                        LogosBadge {
                            text:  root.hasMembership ? "Active" : root.member === "pending" ? "Pending" : root.member === "failed" ? "Failed" : "None"
                            color: root.hasMembership ? Theme.palette.success : root.member === "pending" ? Theme.palette.warning : root.member === "failed" ? Theme.palette.error : Theme.palette.textTertiary
                        }
                    }
                    Row { KV { k: "Memberships"; v: root.memberCount } }
                    Row { KV { k: "Epoch quota"; v: root.quota } }
                    Row { KV { k: "Epoch window"; v: root.epoch > 0 ? (root.epoch + "s") : "—" } }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.palette.border; opacity: 0.6 }
                    Row { KV { k: "Fleet / registry"; v: root.shorten(root.registry) } }
                    Row { KV { k: "RLN identity"; v: root.shorten(root.identity) } }
                    Row { KV { k: "Node RLN"; v: root.nodeRln } }
                    Row { KV { k: "Delivery"; v: root.delivery } }
                }
            }

            // Set up a membership (staged actions via the backend's slots)
            ColumnLayout {
                Layout.fillWidth: true; spacing: Theme.spacing.medium; visible: !root.hasMembership
                LogosText { text: "Set up a membership"; font.weight: Theme.typography.weightBold }
                LogosText {
                    text: "A membership lets this node send on the testnet. It needs a funded account on the LEZ registry; that chain path is still being wired, so the last step may not complete yet."
                    color: Theme.palette.textTertiary; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true
                }
                LogosButton { Layout.fillWidth: true; variant: LogosButton.Variant.Secondary; text: "1. Unlock keystore"; enabled: root.ready
                    onClicked: logos.watch(root.backend.unlockKeystore(), function(v){ root.actionNote = "Unlock: " + v }, function(e){ root.actionNote = "Unlock error: " + e }) }
                LogosButton { Layout.fillWidth: true; variant: LogosButton.Variant.Secondary; text: "2. Provision wallet"; enabled: root.ready
                    onClicked: logos.watch(root.backend.provisionWallet(), function(v){ root.actionNote = "Provision: " + v }, function(e){ root.actionNote = "Provision error: " + e }) }
                LogosButton { Layout.fillWidth: true; variant: LogosButton.Variant.Primary; text: "3. Register membership"; enabled: root.ready && root.registry.length > 0
                    onClicked: logos.watch(root.backend.registerMembership(), function(v){ root.actionNote = "Register: " + v }, function(e){ root.actionNote = "Register error: " + e }) }
                LogosText { text: root.actionNote; visible: root.actionNote.length > 0; color: Theme.palette.textSecondary; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
        }
    }

    component KV: RowLayout {
        property string k
        property var v
        width: root.cardW - 2 * Theme.spacing.medium
        LogosText { text: parent.k; color: Theme.palette.textSecondary; Layout.fillWidth: true }
        LogosText { text: String(parent.v); color: Theme.palette.text }
    }
}
