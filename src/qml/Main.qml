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
    readonly property int cardW: Math.min(width - 2 * Theme.spacing.xlarge, 560)
    function shorten(s) { return (s && s.length > 16) ? (s.slice(0, 8) + "…" + s.slice(-6)) : (s || "—") }
    function fmt(s) {
        var str = String(s || "").replace(/[^0-9]/g, "")
        return str.length ? str.replace(/\B(?=(\d{3})+(?!\d))/g, ",") : "0"
    }

    // convenience readers (guard against a not-yet-ready backend)
    readonly property string nodeRln:    ready && backend ? backend.nodeRlnState   : "unknown"
    readonly property string delivery:   ready && backend ? backend.deliveryStatus : "starting"
    readonly property string member:     ready && backend ? backend.membershipState: "unknown"
    readonly property int    memberCount:ready && backend ? backend.membershipCount : 0
    readonly property string quota:      ready && backend ? backend.quota           : "—"
    readonly property string registry:   ready && backend ? backend.registryId      : ""
    readonly property string identity:   ready && backend ? backend.rlnIdentifier   : ""
    readonly property int    epoch:      ready && backend ? backend.epochSizeSec     : 0
    readonly property string payer:      ready && backend ? backend.payerAccountB58 : ""
    readonly property string balance:    ready && backend ? backend.payerBalance    : ""
    readonly property string fundTarget: ready && backend ? backend.fundTargetUnits : ""
    readonly property string wallet:     ready && backend ? backend.walletState     : "pending"
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

            // Fund the payer to get a membership — informational, no action buttons. The node derives
            // a payer account on LEZ; the user funds it (no faucet, bridge from the Logos Blockchain);
            // the node registers its OWN membership once it sees the funds.
            ColumnLayout {
                Layout.fillWidth: true; spacing: Theme.spacing.medium; visible: !root.hasMembership
                LogosText { text: "Get a membership"; font.weight: Theme.typography.weightBold }
                LogosText {
                    text: "This node pays for its own RLN membership from a payer account on the LEZ chain. Fund that account and the node registers itself automatically — nothing to click here."
                    color: Theme.palette.textTertiary; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true
                }

                LogosText { text: "Payer account"; color: Theme.palette.textSecondary; font.pixelSize: 12 }
                LogosTextField {
                    Layout.fillWidth: true; readOnly: true
                    text: root.payer.length > 0 ? root.payer : "deriving…"
                }

                LogosText {
                    text: "Fund ~" + root.fmt(root.fundTarget || "250000000") + " units (min " + root.fmt("182800000") + ") by bridging from the Logos Blockchain."
                    color: Theme.palette.text; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true; radius: Theme.spacing.radiusSmall
                    color: Theme.palette.surface; border.color: Theme.palette.border; border.width: 1
                    Layout.preferredHeight: balCol.implicitHeight + 2 * Theme.spacing.small
                    ColumnLayout {
                        id: balCol; anchors.fill: parent; anchors.margins: Theme.spacing.small; spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            LogosText { text: "Payer balance"; color: Theme.palette.textSecondary; Layout.fillWidth: true }
                            LogosText { text: root.fmt(root.balance || "0"); color: Theme.palette.text }
                        }
                        LogosText {
                            text: (root.wallet === "ready" ? "Wallet ready. " : "") + "Polling until the payer is funded; the node then registers itself."
                            color: Theme.palette.textTertiary; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                    }
                }
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
