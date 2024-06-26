// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoData.sol";

/// @title LibData
/// @notice A library that offers helper functions.
/// @custom:security-contact security@taiko.xyz
library LibData {
    // = keccak256(abi.encode(new TaikoData.EthDeposit[](0)))
    bytes32 internal constant EMPTY_ETH_DEPOSIT_HASH =
        0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;

    function paramV1toV2(TaikoData.BlockParams memory _v1)
        internal
        pure
        returns (TaikoData.BlockParams2 memory)
    {
        return TaikoData.BlockParams2({
            coinbase: _v1.coinbase,
            extraData: _v1.extraData,
            parentMetaHash: _v1.parentMetaHash,
            l1StateBlockNumber: 0,
            timestamp: 0
        });
    }

    function metadataV2toV1(TaikoData.BlockMetadata2 memory _v2)
        internal
        pure
        returns (TaikoData.BlockMetadata memory)
    {
        return TaikoData.BlockMetadata({
            l1Hash: _v2.l1Hash,
            difficulty: _v2.difficulty,
            blobHash: _v2.blobHash,
            extraData: _v2.extraData,
            depositsHash: EMPTY_ETH_DEPOSIT_HASH,
            coinbase: _v2.coinbase,
            id: _v2.id,
            gasLimit: _v2.gasLimit,
            timestamp: _v2.timestamp,
            l1Height: _v2.l1Height,
            minTier: _v2.minTier,
            blobUsed: _v2.blobUsed,
            parentMetaHash: _v2.parentMetaHash,
            sender: _v2.proposer
        });
    }

    function metadataV1toV2(TaikoData.BlockMetadata memory _v1)
        internal
        pure
        returns (TaikoData.BlockMetadata2 memory)
    {
        return TaikoData.BlockMetadata2({
            l1Hash: _v1.l1Hash,
            difficulty: _v1.difficulty,
            blobHash: _v1.blobHash,
            extraData: _v1.extraData,
            coinbase: _v1.coinbase,
            id: _v1.id,
            gasLimit: _v1.gasLimit,
            timestamp: _v1.timestamp,
            l1Height: _v1.l1Height,
            minTier: _v1.minTier,
            blobUsed: _v1.blobUsed,
            parentMetaHash: _v1.parentMetaHash,
            proposer: _v1.sender,
            livenessBond: 0
        });
    }

    function hashMetadata(
        bool postFork,
        TaikoData.BlockMetadata2 memory _meta
    )
        internal
        pure
        returns (bytes32)
    {
        return postFork
            ? keccak256(abi.encode(_meta)) //
            : keccak256(abi.encode(metadataV2toV1(_meta)));
    }
}
