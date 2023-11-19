#include "drivechain.h"
#include "bridge.rs.cc"
#include "uint256.h"
#include "core_io.h"
#include "utilstrencodings.h"
#include "logging.h"
#include "key_io.h"

const size_t THIS_SIDECHAIN = 5;

CDrivechain::CDrivechain(fs::path datadir, std::string mainHost, unsigned short mainPort, std::string rpcuser, std::string rpcpassword)
{
    std::string db_path = (datadir / "drivechain").string();
    LogPrintf("initializing drivechain: DB path = %s, THIS_SIDECHAIN = %d, main host = %s, main port = %s, RPC user = %s\n", 
        db_path, THIS_SIDECHAIN, mainHost, mainPort, rpcuser);

    try {

    this->drivechain = new_drivechain(
                           db_path,
                           THIS_SIDECHAIN,
                           mainHost,
                           mainPort,
                           rpcuser,
                           rpcpassword)
                           .into_raw();
    } 
    catch (const ::rust::Error& e) {
        LogPrintf("unable to initialize drivechain: %s\n", e.what());
        throw;
    }
}

uint256 CDrivechain::GetMainchainTip() {
    return uint256S(std::string(this->drivechain->get_mainchain_tip()));
}

std::optional<CBlock> CDrivechain::ConfirmBMM()
{
    if (this->drivechain->confirm_bmm() == BMMState::Succeded) {
        CBlock block = *this->block;
        this->block = std::nullopt;
        return block;
    } else {
        return std::nullopt;
    }
}

void CDrivechain::AttemptBMM(const CBlock& block, CAmount amount)
{
    uint256 critical_hash = block.GetHash();
    uint256 prev_main_block_hash = block.hashPrevMainBlock;
    this->drivechain->attempt_bundle_broadcast();
    this->drivechain->attempt_bmm(critical_hash.GetHex(), prev_main_block_hash.GetHex(), amount);
    this->block = block;
}

bool CDrivechain::IsConnected(const CBlockHeader& block)
{
    return this->drivechain->is_main_block_connected(block.hashPrevMainBlock.GetHex());
}

bool CDrivechain::VerifyBMM(const CBlockHeader& block)
{
    return this->drivechain->verify_bmm(block.hashPrevMainBlock.GetHex(), block.hashMerkleRoot.GetHex());
}

std::vector<CTxOut> CDrivechain::GetCoinbaseOutputs()
{
    KeyIO keyIO(Params());
    rust::Vec<Output> outputs = this->drivechain->get_deposit_outputs();

    std::vector<CTxOut> txouts;
    for (const Output& output : outputs) {
        std::string address(output.address);
        LogPrintf("deposit output: address = %s, amount = %d\n", address, output.amount);
        CTxDestination dest = keyIO.DecodeDestination(address);
        CScript scriptPubKey = GetScriptForDestination(dest);
        CTxOut txout(output.amount, scriptPubKey);
        txouts.push_back(txout);
    }
    return txouts;
}

bool CDrivechain::ConnectBlock(const CCoinsViewCache& view, const CBlock& block, bool fJustCheck) {
    KeyIO keyIO(Params());
    rust::Vec<Output> outputs;
    // Connect deposit outputs
    for (auto txout = block.vtx[0].vout.begin()+1; txout < block.vtx[0].vout.end(); ++txout) {
        CTxDestination dest;
        if (!ExtractDestination(txout->scriptPubKey, dest)) {
            LogPrintf("failed to extract destination\n");
            return false;
        }
        std::string address = keyIO.EncodeDestination(dest);
        Output out;
        out.address = address;
        out.amount = txout->nValue;
        outputs.push_back(out);
    }
    // connect withdrawal outputs and refunds
    rust::Vec<Withdrawal> withdrawals;
    rust::Vec<Refund> refunds;
    for (auto tx = block.vtx.begin()+1; tx < block.vtx.end(); ++tx) {
        for (int i = 0; i < tx->vout.size(); ++i) {
            const CTxOut& out = tx->vout[i];
            CTxDestination dest;
            if (!ExtractDestination(out.scriptPubKey, dest)) {
                LogPrintf("failed to extract destination\n");
                LogPrintf("script = %s\n", ScriptToAsmStr(out.scriptPubKey));
                return false;
            }
            if (std::holds_alternative<CWithdrawal>(dest)) {
                CWithdrawal wt = std::get<CWithdrawal>(dest);

                Withdrawal withdrawal;

                COutPoint outpoint(tx->GetHash(), i);
                CDataStream ssOutpoint(SER_NETWORK, PROTOCOL_VERSION);
                ssOutpoint << outpoint;
                std::vector outpointVch(ssOutpoint.begin(), ssOutpoint.end());

                withdrawal.outpoint = HexStr(outpointVch);
                withdrawal.main_address = HexStr(wt.mainAddress);
                withdrawal.main_fee = wt.mainFee;
                withdrawal.amount = out.nValue;

                withdrawals.push_back(withdrawal);
            }
        }
        for (int i = 0; i < tx->vin.size(); ++i) {
            const CTxIn& in = tx->vin[i];
            CDataStream ssOutpoint(SER_NETWORK, PROTOCOL_VERSION);
            ssOutpoint << in.prevout;
            std::vector outpointVch(ssOutpoint.begin(), ssOutpoint.end());
            Refund refund;
            refund.outpoint = HexStr(outpointVch);
            // NOTE: We know that refund amounts are correct, because
            // withdrawals are just regular UTXOs. Getting the actual amount
            // would require calling GetTransaction() which is potentially slow.
            //
            // Since "refund_amount_check" feature of the "drivechain-cpp" crate
            // is disabled the amount field will be ignored.
            refund.amount = 0;
            refunds.push_back(refund);
        }
    }
    return this->drivechain->connect_block(outputs, withdrawals, refunds, fJustCheck);
}

bool CDrivechain::DisconnectBlock(const CBlock& block, bool updateIndices) {
    LogPrintf("drivechain DisconnectBlock\n");
    const bool fJustCheck = !updateIndices;
    KeyIO keyIO(Params());
    rust::Vec<Output> outputs;
    for (auto txout = block.vtx[0].vout.begin()+1; txout < block.vtx[0].vout.end(); ++txout) {
        CTxDestination dest;
        if (!ExtractDestination(txout->scriptPubKey, dest)) {
            LogPrintf("failed to extract destination\n");
            return false;
        }
        std::string address = keyIO.EncodeDestination(dest);
        Output out;
        out.address = address;
        out.amount = txout->nValue;
        outputs.push_back(out);
    }
    rust::Vec<rust::String> withdrawals;
    rust::Vec<rust::String> refunds;
    // collect withdrawals and refund outpoints
    for (auto tx = block.vtx.begin()+1; tx < block.vtx.end(); ++tx) {
        for (int i = 0; i < tx->vout.size(); ++i) {
            const CTxOut& out = tx->vout[i];
            CTxDestination dest;
            if (!ExtractDestination(out.scriptPubKey, dest)) {
                LogPrintf("failed to extract destination\n");
                LogPrintf("script = %s\n", ScriptToAsmStr(out.scriptPubKey));
                return false;
            }
            if (std::holds_alternative<CWithdrawal>(dest)) {
                COutPoint outpoint(tx->GetHash(), i);
                CDataStream ssOutpoint(SER_NETWORK, PROTOCOL_VERSION);
                ssOutpoint << outpoint;
                std::vector outpointVec(ssOutpoint.begin(), ssOutpoint.end());
                withdrawals.push_back(HexStr(outpointVec));
            }
        }
        for (int i = 0; i < tx->vin.size(); ++i) {
            const CTxIn& in = tx->vin[i];
            CDataStream ssOutpoint(SER_NETWORK, PROTOCOL_VERSION);
            ssOutpoint << in.prevout;
            std::vector outpointVec(ssOutpoint.begin(), ssOutpoint.end());
            refunds.push_back(HexStr(outpointVec));
        }
    }
    return this->drivechain->disconnect_block(outputs, withdrawals, refunds, fJustCheck);
}

std::string CDrivechain::FormatDepositAddress(const std::string& address) {
    return std::string(this->drivechain->format_deposit_address(address));
}

uint160 ExtractMainAddressBytes(const std::string& address) {
    rust::Vec<unsigned char> addressVch = extract_mainchain_address_bytes(address);
    return uint160(std::vector(addressVch.begin(), addressVch.end()));
}

std::string CDrivechain::GetNewMainchainAddress() {
    return std::string(this->drivechain->get_new_mainchain_address());
}

std::string CDrivechain::CreateDeposit(std::string address, CAmount amount, CAmount fee) {
    return std::string(this->drivechain->create_deposit(address, amount, fee));
}

std::optional<uint256> CDrivechain::Generate() {
    rust::Vec<rust::String> hashes = this->drivechain->generate(1);
    if (hashes.size() == 1) {
        return uint256S(std::string(hashes[0]));
    } else {
        return std::nullopt;
    }
}

bool CDrivechain::IsOutpointSpent(const COutPoint& outpoint) {
    CDataStream ssOutpoint(SER_NETWORK, PROTOCOL_VERSION);
    ssOutpoint << outpoint;
    std::vector outpointVec(ssOutpoint.begin(), ssOutpoint.end());
    return this->drivechain->is_outpoint_spent(HexStr(outpointVec));
}

size_t CDrivechain::Flush() {
    return this->drivechain->flush();
}

std::unique_ptr<CDrivechain> drivechain;
