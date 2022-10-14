#ifndef BITCOIN_DRIVECHAIN_H
#define BITCOIN_DRIVECHAIN_H

#include "amount.h"
#include "bridge.rs.h"
#include "primitives/block.h"
#include "uint256.h"
#include "fs.h"
#include "script/standard.h"
#include "coins.h"
#include <memory>
#include <optional>

class CDrivechain
{
private:
    Drivechain* drivechain;
    std::optional<CBlock> block;
public:
    CDrivechain(fs::path datadir, std::string mainHost, unsigned short mainPort, std::string rpcuser, std::string rpcpassword);
    uint256 GetMainchainTip();
    std::optional<CBlock> ConfirmBMM();
    void AttemptBMM(const CBlock& block, CAmount amount);
    bool IsConnected(const CBlockHeader& block);
    bool VerifyBMM(const CBlockHeader& block);
    std::vector<CTxOut> GetCoinbaseOutputs();
    bool ConnectBlock(const CCoinsViewCache& view, const CBlock& block, bool fJustCheck);
    bool DisconnectBlock(const CBlock& block, bool updateIndices);
    std::string FormatDepositAddress(const std::string& address);
    std::string GetNewMainchainAddress();
    std::string CreateDeposit(std::string address, CAmount amount, CAmount fee);
    std::optional<uint256> Generate();
    bool IsOutpointSpent(const COutPoint& outpoint);
    size_t Flush();
};

uint160 ExtractMainAddressBytes(const std::string& address);

extern std::unique_ptr<CDrivechain> drivechain;
#endif // BITCOIN_DRIVECHAIN_H
