#include "drivechain.h"
#include "core_io.h"

const size_t THIS_SIDECHAIN = 1;
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

std::optional<MinedBlock> CDrivechain::attempt_bmm(const CBlock& block, CAmount amount)
{
    std::string block_data = EncodeHexBlk(block);
    uint256 critical_hash = block.hashMerkleRoot;
    rust::Vec<Block> block_vec = this->drivechain->attempt_bmm(critical_hash.GetHex(), block_data, amount);
    if (block_vec.empty()) {
        return std::nullopt;
    } else {
        MinedBlock mined;
        mined.block = std::string(block_vec[0].data.begin(), block_vec[0].data.end());
        mined.nTime = block_vec[0].time;
        std::string main_block_hash = std::string(block_vec[0].main_block_hash.begin(), block_vec[0].main_block_hash.end());
        mined.hashMainchainBlock = uint256S(main_block_hash);
        return mined;
    }
}
