// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./PreconfSlasherBase.sol";

contract TestPreconfSlasher_InvalidEOP is PreconfSlasherBase {
    // Slashing
    // ------------------------------------------------------------------------------------------------

    function test_slashesWhenAnotherBlockIsProposedAfterEOP()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        // The preconfed block is in the middle of the batch i.e it cannot be an EOP

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // Slash the commitment
        uint256 slashedAmount = _slashInvalidEOP(commitment, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().invalidEOP);
    }

    function test_slashesWhenAnotherBatchIsProposedAfterEOP()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // Insert an extra batch after the preconfed batch
        _insertNextBatch(2, preconferSlotTimestamp);

        // Slash the commitment
        uint256 slashedAmount = _slashInvalidEOP(commitment, preconfedBlockHeader);

        // Correct slashing amount is returned
        assertEq(slashedAmount, preconfSlasher.getSlashAmount().invalidEOP);
    }

    // Reverts
    // ------------------------------------------------------------------------------------------------

    function test_revertsWhenPreconfedBlockHeaderIsInvalid()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;
        preconfedBlockHeader.nonce = 0x0000000000000001;

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // Mess up the preconfed block header
        preconfedBlockHeader.nonce = 0x0000000000000002;

        // Attempt to slash reverts
        _slashInvalidEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.InvalidBlockHeader.selector
        );
    }

    function test_revertsWhenEOPIsFalse()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP false
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, false);

        // Attempt to slash reverts
        _slashInvalidEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.NotEndOfPreconfirmation.selector
        );
    }

    function test_revertsWhenBatchInfoIsInvalid()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // Mess up the batch info
        _cachedBatchInfo.lastBlockId = 0;

        // Attempt to slash reverts
        _slashInvalidEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.InvalidBatchInfo.selector
        );
    }

    function test_revertsWhenBatchMetadataIsInvalid()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.MIDDLE_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // Mess up the batch metadata
        _cachedBatchMetadata.prover = address(1);

        // Attempt to slash reverts
        _slashInvalidEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.InvalidBatchMetadata.selector
        );
    }

    function test_revertsWhenNextBatchMetadataIsInvalid()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // Insert an extra batch after the preconfed batch
        _insertNextBatch(2, preconferSlotTimestamp);

        // Mess up the next batch metadata
        _cachedNextBatchMetadata.proposedAt = 0;

        // Attempt to slash reverts
        _slashInvalidEOP(
            commitment, preconfedBlockHeader, IPreconfSlasher.InvalidBatchMetadata.selector
        );
    }

    function test_revertsWhenNotAnInvalidEOP_Case1()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.END_OF_BATCH, preconfSigner)
    {
        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // No extra batch is proposed in the preconfing window
        _insertNextBatch(2, preconferSlotTimestamp + 1);

        // Attempt to slash reverts
        _slashInvalidEOP(
            commitment,
            preconfedBlockHeader,
            IPreconfSlasher.NextBatchProposedInNextPreconfWindow.selector
        );
    }

    function test_revertsWhenNotAnInvalidEOP_Case2()
        external
        transactBy(urc)
        InsertBatchAndTransition(BlockPosition.NEXT_BATCH, preconfSigner)
    {
        // Block is not in the batch

        LibBlockHeader.BlockHeader memory preconfedBlockHeader = actualBlockHeader;

        // Build a commitment on the preconfed block header with EOP true
        ISlasher.Commitment memory commitment =
            _buildPreconfirmationCommitment(preconfedBlockHeader, true);

        // Attempt to slash reverts
        _slashInvalidEOP(commitment, preconfedBlockHeader, IPreconfSlasher.BlockNotInBatch.selector);
    }
}
