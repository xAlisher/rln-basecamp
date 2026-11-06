#include "rln_ui_backend.h"
#include "logos_sdk.h"   // generated umbrella: LogosModules (modules().delivery_module / .liblogos_rln_module / .liblogos_lez_rln_module)

#include <QByteArray>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <vector>

namespace {
// logos.test = RLN enabled (devnet logos.dev has RLN disabled). Verified via probe 2026-11-06.
const char* kNodeCfg = R"JSON({"logLevel":"ERROR","mode":"Core","preset":"logos.test","relay":true,"tcpPort":0,"discv5UdpPort":0,"entryNodes":["/dns4/node-01.do-ams3.logos.test.status.im/tcp/30303/p2p/16Uiu2HAmQ9X2xDfPG3uL77V9piYDhjq14JhKCtcmNYsTMKNqrKCj","/dns4/node-02.gc-us-central1-a.logos.test.status.im/tcp/30303/p2p/16Uiu2HAmUuXhUW9bdJpzN1kfDziFiUZo4bszTk66cvr7uuyCHXR7"]})JSON";

// Fund target from the official guide (Testnet v0.3.1): suggested 250,000,000; minimum 182,800,000.
const char* kFundTargetSuggested = "250000000";

QJsonObject parseObj(const QString& s) {
    const QJsonDocument d = QJsonDocument::fromJson(s.toUtf8());
    return d.isObject() ? d.object() : QJsonObject();
}

// Base58 (Bitcoin alphabet), matching the guide's python: one leading '1' per leading zero BYTE.
// Verified vector: 5742382a0a0c4e64078f84541e9562110a46fc9ae575daf7fdef9c900d759b0e
//                  -> 6sd2zxevgjWxdFzsqBQQAcFp9ikktmCQUzCjEcJwcknR
QString base58(const QByteArray& input) {
    static const char* ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    int zeros = 0;
    while (zeros < input.size() && static_cast<unsigned char>(input[zeros]) == 0) ++zeros;

    std::vector<unsigned char> b58(static_cast<size_t>(input.size()) * 138 / 100 + 1, 0);
    int length = 0;
    for (int i = zeros; i < input.size(); ++i) {
        int carry = static_cast<unsigned char>(input[i]);
        int j = 0;
        for (auto it = b58.rbegin(); (carry != 0 || j < length) && it != b58.rend(); ++it, ++j) {
            carry += 256 * (*it);
            *it = static_cast<unsigned char>(carry % 58);
            carry /= 58;
        }
        length = j;
    }
    size_t skip = b58.size() - static_cast<size_t>(length);
    QString out(zeros, QLatin1Char('1'));
    for (size_t i = skip; i < b58.size(); ++i) out.append(QLatin1Char(ALPHABET[b58[i]]));
    return out;
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
    LiblogosLezRlnModule& lez = modules().liblogos_lez_rln_module;

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

    // --- payer account funding model (liblogos_lez_rln_module) ---
    // The node derives a payer account on LEZ; the user funds it (no faucet; bridge from the Logos
    // Blockchain); the node registers its OWN membership once it sees the funds. Informational only.
    const QJsonObject ws = parseObj(lez.wallet_status());
    const QString payer = ws.value("payer").toString();
    if (!payer.isEmpty() && payer != payerAccount()) {
        setPayerAccount(payer);
        setPayerAccountB58(base58(QByteArray::fromHex(payer.toUtf8())));
    }
    const QString wstate = ws.value("state").toString();
    if (!wstate.isEmpty()) setWalletState(wstate);
    if (!payer.isEmpty()) {
        const QString balRaw = lez.get_native_balance(payer);
        if (!balRaw.isEmpty()) {
            // Live module returns {"account":hex,"balance":"<decimal>"}; older contract returned a bare
            // decimal string. Handle both.
            const QJsonObject bo = parseObj(balRaw);
            setPayerBalance(bo.contains(QStringLiteral("balance"))
                                ? bo.value(QStringLiteral("balance")).toString()
                                : balRaw.trimmed());
        }
    }
    if (fundTargetUnits().isEmpty()) setFundTargetUnits(QString::fromUtf8(kFundTargetSuggested));

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
