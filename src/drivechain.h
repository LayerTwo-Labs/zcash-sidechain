#ifndef BITCOIN_DRIVECHAIN_H
#define BITCOIN_DRIVECHAIN_H

#include "amount.h"
#include "bridge.rs.h"
#include "primitives/block.h"
#include "uint256.h"
#include "fs.h"
#include "script/standard.h"
#include <memory>
#include <optional>

struct MinedBlock {
    std::string block;
    uint32_t nTime;
    uint256 hashMainBlock;
};

class CDrivechain
{
private:
    Drivechain* drivechain;

public:
    CDrivechain(fs::path datadir, std::string rpcuser, std::string rpcpassword);
    std::optional<CBlock> ConfirmBMM();
    void AttemptBMM(const CBlock& block, CAmount amount);
    bool IsConnected(const CBlockHeader& block);
    bool VerifyHeaderBMM(const CBlockHeader& block);
    bool VerifyBlockBMM(const CBlock& block);
    std::vector<CTxOut> GetCoinbaseOutputs();
    CTxOut GetCoinbaseDataOutput(const uint256& prevSideBlockHash);
    bool ConnectBlock(const CBlock& block, bool fJustCheck);
    bool DisconnectBlock(const CBlock& block, bool updateIndices);
    std::string FormatDepositAddress(const std::string& address);
    std::string GetNewMainchainAddress();
    bool IsOutpointSpent(const COutPoint& outpoint);
    size_t Flush();
};

uint160 ExtractMainAddressBytes(const std::string& address);

extern std::unique_ptr<CDrivechain> drivechain;
#endif // BITCOIN_DRIVECHAIN_H
