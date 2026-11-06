#include "rln_ui_backend.h"
#include "logos_sdk.h"   // generated umbrella: LogosModules (modules().delivery_module / .liblogos_rln_module)

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

namespace {
// logos.test = RLN enabled (devnet logos.dev has RLN disabled). Verified via probe 2026-11-06.
const char* kNodeCfg = R"JSON({"logLevel":"ERROR","mode":"Core","preset":"logos.test","relay":true,"tcpPort":0,"discv5UdpPort":0,"entryNodes":["/dns4/node-01.do-ams3.logos.test.status.im/tcp/30303/p2p/16Uiu2HAmQ9X2xDfPG3uL77V9piYDhjq14JhKCtcmNYsTMKNqrKCj","/dns4/node-02.gc-us-central1-a.logos.test.status.im/tcp/30303/p2p/16Uiu2HAmUuXhUW9bdJpzN1kfDziFiUZo4bszTk66cvr7uuyCHXR7"]})JSON";

QJsonObject parseObj(const QString& s) {
    const QJsonDocument d = QJsonDocument::fromJson(s.toUtf8());
    return d.isObject() ? d.object() : QJsonObject();
}
}

void RlnUiBackend::onContextReady() { start(); }

void RlnUiBackend::start() {
    if (!m_nodeUp) bringUpNode();
    if (!m_timer) {
        m_timer = new QTimer(this);
        QObject::connect(m_timer, &QTimer::timeout, this, [this] { refresh(); });
        m_timer->start(2000);
    }
    refresh();
}

void RlnUiBackend::bringUpNode() {
    modules().delivery_module.createNode(QString::fromUtf8(kNodeCfg));  // adopt if already up
    modules().delivery_module.start();
    m_nodeUp = true;
}

void RlnUiBackend::refresh() {
    DeliveryModule& delivery = modules().delivery_module;
    LiblogosRlnModule& rln = modules().liblogos_rln_module;

    const LogosResult cs = delivery.getConnectionStatus();
    if (cs.success) setDeliveryStatus(cs.getString());

    const LogosResult rs = delivery.rlnState();
    if (rs.success) {
        const QString st = rs.getString("state");
        if (!st.isEmpty()) setNodeRlnState(st);
        const QString reg = rs.getString("registryId");
        if (!reg.isEmpty()) setRegistryId(reg);
        const QString rid = rs.getString("rlnIdentifier");
        if (!rid.isEmpty()) setRlnIdentifier(rid);
        const int es = rs.getInt("epochSizeSec");
        if (es > 0) setEpochSizeSec(es);
    }

    if (registryId().isEmpty()) return;
    const QString reg = registryId();
    const QString rid = rlnIdentifier();

    const QJsonObject ms = parseObj(rln.get_membership_state(reg, rid));
    setMembershipState(ms.value("state").toString(QStringLiteral("unknown")));

    const QJsonObject gm = parseObj(rln.get_memberships(reg));
    setMembershipCount(gm.value("memberships").toArray().size());

    const QString ts = QString::number(QDateTime::currentSecsSinceEpoch());
    const LogosResult q = rln.get_epoch_quota(reg, rid, ts);
    if (q.success)
        setQuota(QStringLiteral("%1 / %2 this epoch").arg(q.getInt("remaining")).arg(q.getInt("rate_limit")));
    else if (membershipCount() == 0)
        setQuota(QStringLiteral("n/a until membership"));
}

// --- membership actions: wired to the rln module; the register path needs a funded LEZ account ---
QString RlnUiBackend::unlockKeystore() {
    logos::CallError err;
    const QString r = modules().liblogos_rln_module.unlock_keystore_auto(&err);
    return err.ok() ? r : QStringLiteral("error: %1").arg(QString::fromStdString(err.message));
}
QString RlnUiBackend::provisionWallet() {
    logos::CallError err;
    const QString r = modules().liblogos_rln_module.provision_wallet_home(QStringLiteral("{}"), &err);
    return err.ok() ? r : QStringLiteral("error: %1").arg(QString::fromStdString(err.message));
}
QString RlnUiBackend::registerMembership() {
    logos::CallError err;
    const QString r = modules().liblogos_rln_module.register_membership(
        registryId(), rlnIdentifier(), QStringLiteral("{}"), &err);
    return err.ok() ? r : QStringLiteral("error: %1").arg(QString::fromStdString(err.message));
}
