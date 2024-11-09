// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TaikoL1Test.sol";

contract TaikoL1TestGroup8 is TaikoL1Test {
    function getConfig() internal view override returns (TaikoData.Config memory) {
        return TaikoData.Config({
            chainId: taikoChainId,
            blockMaxProposals: 20,
            blockRingBufferSize: 25,
            maxBlocksToVerify: 16,
            blockMaxGasLimit: 240_000_000,
            livenessBond: 125e18,
            stateRootSyncInternal: 2,
            maxAnchorHeightOffset: 64,
            baseFeeConfig: LibSharedData.BaseFeeConfig({
                adjustmentQuotient: 8,
                sharingPctg: 75,
                gasIssuancePerSecond: 5_000_000,
                minGasExcess: 1_340_000_000, // correspond to 0.008847185 gwei basefee
                maxGasIssuancePerBlock: 600_000_000 // two minutes: 5_000_000 * 120
             }),
            ontakeForkHeight: 0 // or 1
         });
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. TaikoL1 is paused.
    // 3. Alice attempts to prove the block within the proving window.
    // 4. Alice tries to propose another block.
    // 5. TaikoL1 is unpaused.
    // 6. Alice attempts again to prove the first block within the proving window.
    // 7. Alice tries to propose another block.
    function test_taikoL1_group_8_case_1() external {
        mineOneBlockAndWrap(1000 seconds);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");

        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Pause TaikoL1");
        mineOneBlockAndWrap(10 seconds);
        vm.prank(taikoL1.owner());
        taikoL1.pause();

        console2.log("====== Alice proves the block first after L1 paused");

        bytes32 parentHash1 = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));
        proveBlock(
            Alice,
            meta,
            parentHash1,
            blockHash,
            stateRoot,
            meta.minTier,
            EssentialContract.INVALID_PAUSE_STATUS.selector
        );

        console2.log("====== Alice tries to propose another block after L1 paused");
        proposeBlock(Alice, EssentialContract.INVALID_PAUSE_STATUS.selector);

        console2.log("====== Unpause TaikoL1");
        mineOneBlockAndWrap(10 seconds);
        vm.prank(taikoL1.owner());
        taikoL1.unpause();

        console2.log("====== Alice proves the block first after L1 unpaused");
        proveBlock(Alice, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");
        console2.log("====== Alice tries to propose another block after L1 unpaused");
        proposeBlock(Alice, "");
    }

    // Test summary:
    // 1. Alice proposes a block,
    // 2. TaikoL1 proving is paused.
    // 3. Alice attempts to prove the block within the proving window.
    // 4. Alice tries to propose another block.
    // 5. TaikoL1 proving is unpaused.
    // 6. Alice attempts again to prove the first block within the proving window.
    // 7. Alice tries to propose another block.
    function test_taikoL1_group_8_case_2() external {
        mineOneBlockAndWrap(1000 seconds);
        giveEthAndTko(Alice, 10_000 ether, 1000 ether);

        console2.log("====== Alice propose a block");

        TaikoData.BlockMetadataV2 memory meta = proposeBlock(Alice, "");

        console2.log("====== Pause TaikoL1 proving");
        mineOneBlockAndWrap(10 seconds);
        vm.prank(taikoL1.owner());
        taikoL1.pauseProving(true);

        console2.log("====== Alice proves the block first after L1 proving paused");

        bytes32 parentHash1 = GENESIS_BLOCK_HASH;
        bytes32 blockHash = bytes32(uint256(10));
        bytes32 stateRoot = bytes32(uint256(11));
        proveBlock(
            Alice,
            meta,
            parentHash1,
            blockHash,
            stateRoot,
            meta.minTier,
            LibProving.L1_PROVING_PAUSED.selector
        );

        console2.log("====== Alice tries to propose another block after L1 proving paused");
        proposeBlock(Alice, "");

        console2.log("====== Unpause TaikoL1 proving");
        mineOneBlockAndWrap(10 seconds);
        vm.prank(taikoL1.owner());
        taikoL1.pauseProving(false);

        console2.log("====== Alice proves the block first after L1 proving unpaused");
        proveBlock(Alice, meta, parentHash1, blockHash, stateRoot, meta.minTier, "");
    }

    // Test summary:
    // 1. Gets a block that doesn't exist
    // 2. Gets a transition by ID & hash that doesn't exist.
    function test_taikoL1_group_8_case_3() external {
        vm.expectRevert(LibUtils.L1_INVALID_BLOCK_ID.selector);
        taikoL1.getBlockV2(2);

        vm.expectRevert(LibUtils.L1_TRANSITION_NOT_FOUND.selector);
        taikoL1.getTransition(0, 2);

        vm.expectRevert(LibUtils.L1_TRANSITION_NOT_FOUND.selector);
        taikoL1.getTransition(0, randBytes32());

        vm.expectRevert(LibUtils.L1_INVALID_BLOCK_ID.selector);
        taikoL1.getTransition(3, randBytes32());
    }
}
