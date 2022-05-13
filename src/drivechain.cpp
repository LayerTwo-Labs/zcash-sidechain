#include "drivechain.h"
#include "core_io.h"
#include "utilstrencodings.h"
#include "logging.h"
#include "key_io.h"

const size_t THIS_SIDECHAIN = 0;
const std::string KEY_HASH = "f0d112bd2156dd4d17c1ddb80f15dde4773edcfa72b9dc8465f4f4f1dbbe2ca3";

CDrivechain::CDrivechain(fs::path datadir, std::string rpcuser, std::string rpcpassword)
{
    std::string db_path = (datadir / "drivechain").string();
    this->drivechain = new_drivechain(
                           db_path,
                           THIS_SIDECHAIN,
                           KEY_HASH,
                           rpcuser,
                           rpcpassword)
                           .into_raw();
}

std::optional<CBlock> CDrivechain::ConfirmBMM()
{
    rust::Vec<Block> block_vec = this->drivechain->confirm_bmm();
    if (block_vec.empty()) {
        return std::nullopt;
    } else {
        MinedBlock mined;
        mined.block = std::string(block_vec[0].data.begin(), block_vec[0].data.end());
        mined.nTime = block_vec[0].time;
        std::string main_block_hash = std::string(block_vec[0].main_block_hash.begin(), block_vec[0].main_block_hash.end());
        mined.hashMainBlock = uint256S(main_block_hash);

        CBlock block;
        if (DecodeHexBlk(block, mined.block)) {
            block.hashMainBlock = mined.hashMainBlock;
            return block;
        } else {
            return std::nullopt;
        }
    }
}

void CDrivechain::AttemptBMM(const CBlock& block, CAmount amount)
{
    std::string block_data = EncodeHexBlk(block);
    uint256 critical_hash = block.hashMerkleRoot;
    this->drivechain->attempt_bmm(critical_hash.GetHex(), block_data, amount);
}

CTxOut CDrivechain::GetCoinbaseDataOutput(const uint256& prevSideBlockHash)
{
    rust::Vec<unsigned char> coinbase_data = this->drivechain->get_coinbase_data(prevSideBlockHash.GetHex());
    CTxOut dataOut;
    dataOut.nValue = 0;
    dataOut.scriptPubKey = CScript(OP_RETURN) + CScript(&*coinbase_data.begin(), &*coinbase_data.end());
    return dataOut;
}

bool CDrivechain::VerifyHeaderBMM(const CBlockHeader& block)
{
    return this->drivechain->verify_header_bmm(block.hashMainBlock.GetHex(), block.hashMerkleRoot.GetHex());
}

bool CDrivechain::VerifyBlockBMM(const CBlock& block)
{
    CScript dataScript = block.vtx[0].vout[0].scriptPubKey;
    std::string coinbaseData = HexStr(dataScript.begin()+1, dataScript.end());
    return this->drivechain->verify_block_bmm(block.hashMainBlock.GetHex(), block.hashMerkleRoot.GetHex(), coinbaseData);
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

bool CDrivechain::ConnectBlock(const CBlock& block, bool fJustCheck) {
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
    if (!this->drivechain->connect_deposit_outputs(outputs, fJustCheck)) {
        LogPrintf("failed to connect deposit outputs\n");
        return false;
    }
    rust::Vec<Withdrawal> withdrawals;
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
                std::vector outpointVec(ssOutpoint.begin(), ssOutpoint.end());
                withdrawal.outpoint = HexStr(outpointVec);;

                CDataStream ssWTData(SER_NETWORK, PROTOCOL_VERSION);
                ssWTData << wt.wtData;
                std::vector wtDataVec(ssWTData.begin(), ssWTData.end());
                withdrawal.withdrawal_data = HexStr(wtDataVec);
                withdrawal.amount = out.nValue;

                withdrawals.push_back(withdrawal);
            }
        }
    }
    if (!fJustCheck) {
        if (!this->drivechain->connect_withdrawals(withdrawals)) {
            return false;
        }
    }
    return true;
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
    return this->drivechain->disconnect_deposit_outputs(outputs, fJustCheck);
}

std::string CDrivechain::FormatDepositAddress(const std::string& address) {
    return std::string(this->drivechain->format_deposit_address(address));
}

CWithdrawal CDrivechain::CreateWithdrawalDestination(const CKeyID& refundDest, const std::string& mainDest, const CAmount& mainFee) {
    rust::Vec<unsigned char> rustVch = get_withdrawal_data(mainDest, mainFee);
    std::vector<unsigned char> vch(rustVch.begin(), rustVch.end());
    wt_blob wtData(vch);
    return CWithdrawal(refundDest, wtData);
}

bool CDrivechain::Flush() {
    return this->drivechain->flush();
}

// Collect withdrawals
// Mark withdrawals as spent when bundle is created
// Mark withdrawals as unspent when bundle fails
// Refund
// 1. Select unspent withdrawals
// 2. Create change for withdrawals
