#include "rln_ui_backend.h"
#include "logos_sdk.h"   // generated umbrella: full LogosModules (modules() + .dynamic())

#include <nlohmann/json.hpp>
#include <QDateTime>
#include <string>

using nlohmann::json;

namespace {
// logos.test = RLN enabled (devnet logos.dev has RLN disabled). Verified via probe 2026-11-06.
const char* kNodeCfg = R"JSON({"logLevel":"ERROR","mode":"Core","preset":"logos.test","relay":true,"tcpPort":0,"discv5UdpPort":0,"entryNodes":["/dns4/node-01.do-ams3.logos.test.status.im/tcp/30303/p2p/16Uiu2HAmQ9X2xDfPG3uL77V9piYDhjq14JhKCtcmNYsTMKNqrKCj","/dns4/node-02.gc-us-central1-a.logos.test.status.im/tcp/30303/p2p/16Uiu2HAmUuXhUW9bdJpzN1kfDziFiUZo4bszTk66cvr7uuyCHXR7"]})JSON";

// lp replies sometimes wrap the payload as {"value": X}; tstr methods can come back as a JSON string
// that must be parsed again (seen in the probe). Normalise both into a usable json value.
json unwrap(const json& r) {
    json v = r;
    if (v.is_object() && v.contains("value")) v = v["value"];
    if (v.is_string()) { try { v = json::parse(v.get<std::string>()); } catch (...) {} }
    return v;
}
QString jstr(const json& v, const char* key, const QString& dflt = QString()) {
    if (v.is_object() && v.contains(key) && v[key].is_string())
        return QString::fromStdString(v[key].get<std::string>());
    return dflt;
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
    logos::CallError err;
    auto delivery = modules().dynamic("delivery_module");
    delivery.invoke("createNode", json::array({ std::string(kNodeCfg) }), &err, 45000); // adopt if already up
    delivery.invoke("start", json::array(), &err, 20000);
    m_nodeUp = true;
}

void RlnUiBackend::refresh() {
    logos::CallError err;
    auto delivery = modules().dynamic("delivery_module");
    auto rln = modules().dynamic("liblogos_rln_module");

    json cs = unwrap(delivery.invoke("getConnectionStatus", json::array(), &err, 10000));
    if (cs.is_string()) setDeliveryStatus(QString::fromStdString(cs.get<std::string>()));

    json rs = unwrap(delivery.invoke("rlnState", json::array(), &err, 10000));
    if (rs.is_object()) {
        setNodeRlnState(jstr(rs, "state", nodeRlnState()));
        const QString reg = jstr(rs, "registryId", registryId());
        if (!reg.isEmpty()) setRegistryId(reg);
        const QString rid = jstr(rs, "rlnIdentifier", rlnIdentifier());
        if (!rid.isEmpty()) setRlnIdentifier(rid);
        if (rs.contains("epochSizeSec") && rs["epochSizeSec"].is_number())
            setEpochSizeSec(rs["epochSizeSec"].get<int>());
    }

    if (registryId().isEmpty()) return;
    const std::string reg = registryId().toStdString();
    const std::string rid = rlnIdentifier().toStdString();

    json ms = unwrap(rln.invoke("get_membership_state", json::array({ reg, rid }), &err, 10000));
    setMembershipState(jstr(ms, "state", QStringLiteral("unknown")));

    json gm = unwrap(rln.invoke("get_memberships", json::array({ reg }), &err, 10000));
    if (gm.is_object() && gm.contains("memberships") && gm["memberships"].is_array())
        setMembershipCount(static_cast<int>(gm["memberships"].size()));

    const std::string ts = std::to_string(QDateTime::currentSecsSinceEpoch());
    json q = unwrap(rln.invoke("get_epoch_quota", json::array({ reg, rid, ts }), &err, 10000));
    if (q.is_object() && q.contains("rate_limit")) {
        setQuota(QStringLiteral("%1 / %2 this epoch")
                     .arg(q.value("remaining", 0)).arg(q.value("rate_limit", 0)));
    } else if (membershipCount() == 0) {
        setQuota(QStringLiteral("n/a until membership"));
    }
}

// --- membership actions (Epic 4): wired to the rln module; the register path needs a funded LEZ account ---
QString RlnUiBackend::unlockKeystore() {
    logos::CallError err;
    json r = modules().dynamic("liblogos_rln_module").invoke("unlock_keystore_auto", json::array(), &err, 15000);
    return err.code.empty() ? QString::fromStdString(r.dump()) : QString::fromStdString("error: " + err.code);
}
QString RlnUiBackend::provisionWallet() {
    logos::CallError err;
    json r = modules().dynamic("liblogos_rln_module").invoke("provision_wallet_home", json::array({ std::string("{}") }), &err, 20000);
    return err.code.empty() ? QString::fromStdString(r.dump()) : QString::fromStdString("error: " + err.code);
}
QString RlnUiBackend::registerMembership() {
    logos::CallError err;
    json r = modules().dynamic("liblogos_rln_module").invoke(
        "register_membership",
        json::array({ registryId().toStdString(), rlnIdentifier().toStdString(), std::string("{}") }),
        &err, 30000);
    return err.code.empty() ? QString::fromStdString(r.dump()) : QString::fromStdString("error: " + err.code);
}
