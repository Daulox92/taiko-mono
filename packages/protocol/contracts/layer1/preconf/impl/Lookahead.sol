// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../shared/common/EssentialContract.sol";
import "../iface/ILookahead.sol";
import "../iface/IPreconfRegistry.sol";
import "../iface/IPreconfServiceManager.sol";
import "../libs/LibNames.sol";
import "../libs/LibEpoch.sol";
import "../libs/LibEIP4788.sol";

/// @title Lookahead
/// @custom:security-contact security@taiko.xyz
contract Lookahead is ILookahead, EssentialContract {
    using LibEpoch for uint256;

    uint256 public constant DISPUTE_PERIOD = 1 days;

    uint256 public immutable beaconGenesisTimestamp;
    address public immutable beaconBlockRootContract;

    struct Poster {
        address addr;
    }

    // Maps the epoch timestamp to the lookahead poster.
    // If the lookahead poster has been slashed, it maps to the 0-address.
    // Note: This may be optimised to re-use existing slots and reduce gas cost.
    mapping(uint256 epochTimestamp => Poster poster) internal posters;

    mapping(uint256 pointer => LookaheadEntry) internal lookahead;
    uint64 internal lookaheadTail;

    uint256[47] private __gap;

    error LookaheadIsNotRequired();
    error MissedDisputeWindow();
    error PreconferNotRegistered();
    error InvalidLookaheadPointer();
    error PosterAlreadySlashedOrLookaheadIsEmpty();
    error LookaheadEntryIsCorrect();

    modifier onlyFromPreconfer() {
        address registry = resolve(LibNames.B_PRECONF_REGISTRY, false);
        require(
            IPreconfRegistry(registry).getPreconferIndex(msg.sender) != 0, PreconferNotRegistered()
        );
        _;
    }

    modifier lockPreconferStake() {
        _;
        IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false)).lockStakeUntil(
            msg.sender, block.timestamp + DISPUTE_PERIOD
        );
    }

    constructor(uint256 _beaconGenesisTimestamp, address _beaconBlockRootContract) {
        beaconGenesisTimestamp = _beaconGenesisTimestamp;
        beaconBlockRootContract = _beaconBlockRootContract;
    }

    /// @notice Initializes the contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @inheritdoc ILookahead
    function forcePostLookahead(LookaheadParam[] calldata _lookaheadParams)
        external
        onlyFromPreconfer
        nonReentrant
    {
        // Lookahead must be missing
        uint256 epochTimestamp = block.timestamp.toEpochTimestamp(beaconGenesisTimestamp);

        if (_isLookaheadRequired(epochTimestamp)) {
            _postLookahead(epochTimestamp, _lookaheadParams);
        } else {
            revert LookaheadIsNotRequired();
        }
    }

    /// @inheritdoc ILookahead
    function postLookahead(LookaheadParam[] calldata _lookaheadParams)
        external
        onlyFromNamed(LibNames.B_PRECONF_SERVICE_MANAGER)
        nonReentrant
    {
        uint256 epochTimestamp = block.timestamp.toEpochTimestamp(beaconGenesisTimestamp);

        if (_isLookaheadRequired(epochTimestamp)) {
            _postLookahead(epochTimestamp, _lookaheadParams);
        } else {
            require(_lookaheadParams.length == 0, LookaheadIsNotRequired());
        }
    }

    function proveIncorrectLookahead(
        uint256 _lookaheadPointer,
        uint256 _slotTimestamp,
        bytes calldata _validatorBLSPubKey,
        LibEIP4788.InclusionProof calldata _validatorInclusionProof
    )
        external
    {
        uint256 epochTimestamp = _slotTimestamp.toEpochTimestamp(beaconGenesisTimestamp);
        require(block.timestamp > DISPUTE_PERIOD + _slotTimestamp, MissedDisputeWindow());

        Poster memory poster = _posterFor(epochTimestamp);
        require(poster.addr != address(0), PosterAlreadySlashedOrLookaheadIsEmpty());

        // Validate lookahead pointer
        LookaheadEntry memory entry = _entryAt(_lookaheadPointer);
        require(_slotTimestamp > entry.validSince, InvalidLookaheadPointer());
        require(_slotTimestamp <= entry.validUntil, InvalidLookaheadPointer());

        // We pull the preconfer present at the required slot timestamp in the lookahead.
        // If no preconfer is present for a slot, we simply use the 0-address to denote the
        // preconfer.
        address preconferInLookahead;
        if (_slotTimestamp == entry.validUntil && !entry.isFallback) {
            // The slot was dedicated to a specific preconfer
            preconferInLookahead = entry.preconfer;
        } else {
            // The slot was empty and it was the next preconfer who was expected to preconf in
            // advanced, OR
            // the slot was empty and the preconfer was expected to be the fallback preconfer for
            // the epoch.
            // We still use the zero address because technically the slot itself was empty in the
            // lookahead.
            // preconferInLookahead = address(0);
        }
        address preconferInRegistry = _getPreconferInRegistry(_validatorBLSPubKey, _slotTimestamp);
        require(preconferInRegistry != preconferInLookahead, LookaheadEntryIsCorrect());

        LibEIP4788.verifyValidator(
            _validatorBLSPubKey, _getBeaconBlockRoot(_slotTimestamp), _validatorInclusionProof
        );

        // If it is the current epoch's lookahead being proved incorrect then insert a fallback
        // preconfer for the next epoch.

        if (block.timestamp < epochTimestamp.nextEpoch()) {
            _insertFallbackPreconfer(epochTimestamp);
        }

        // Slash the poster
        _posterFor(epochTimestamp).addr = address(0);
        IPreconfServiceManager(resolve(LibNames.B_PRECONF_SERVICE_MANAGER, false)).slashOperator(
            poster.addr
        );
    }

    /// @inheritdoc ILookahead
    function isCurrentPreconfer(address addr) external view returns (bool) {
        //
    }

    function getPoster(uint256 _epochTimestamp) public view returns (address) { }

    function _postLookahead(
        uint256 _currentEpochTimestamp,
        LookaheadParam[] calldata _lookaheadParams
    )
        internal
        lockPreconferStake
    {
        uint256 nextEpochTimestamp;
        uint256 nextEpochEndTimestamp;

        unchecked {
            nextEpochTimestamp = _currentEpochTimestamp.nextEpoch();
            nextEpochEndTimestamp = nextEpochTimestamp.nextEpoch();
        }

        // The tail of the lookahead is tracked and connected to the first new lookahead entry so
        // that when no more preconfers are present in the remaining slots of the current epoch,
        // the next epoch's preconfer may start preconfing in advanced.
        //
        // --[]--[]--[p1]--[]--[]---|---[]--[]--[P2]--[]--[]
        //   1   2    3    4   5        6    7    8   9   10
        //         Epoch 1                     Epoch 2
        //
        // Here, P2 may start preconfing and proposing blocks from slot 4 itself
        //
    }

    /// @notice Retrieves the beacon block root for the block at the specified timestamp
    function _getBeaconBlockRoot(uint256 timestamp) private view returns (bytes32) {
        // At block N, we get the beacon block root for block N - 1. So, to get the block root of
        // the Nth block,
        // we query the root at block N + 1. If N + 1 is a missed slot, we keep querying until we
        // find a block N + x
        // that has the block root for Nth block.
        uint256 targetTimestamp = timestamp + LibEpoch.SECONDS_IN_SLOT;
        while (true) {
            (bool success, bytes memory result) =
                beaconBlockRootContract.staticcall(abi.encode(targetTimestamp));
            if (success && result.length > 0) {
                return abi.decode(result, (bytes32));
            }

            unchecked {
                targetTimestamp += LibEpoch.SECONDS_IN_SLOT;
            }
        }
        return bytes32(0);
    }

    function _getPreconferInRegistry(
        bytes calldata _validatorBLSPubKey,
        uint256 _slotTimestamp
    )
        private
        view
        returns (address)
    {
        address preconfRegistry = resolve(LibNames.B_PRECONF_REGISTRY, false);
        IPreconfRegistry.Validator memory validatorInRegistry =
            IPreconfRegistry(preconfRegistry).getValidator(_hashBLSPubKey(_validatorBLSPubKey));

        bool validatorStillProposing = _slotTimestamp >= validatorInRegistry.proposingSince
            && (
                validatorInRegistry.proposingUntil == 0
                    || _slotTimestamp < validatorInRegistry.proposingUntil
            );

        return validatorStillProposing ? validatorInRegistry.preconfer : address(0);
    }

    function _isLookaheadRequired(uint256 _epochTimestamp) private view returns (bool) {
        // If it's the first slot of current epoch, we don't need the lookahead since the offchain
        // node may not have access to it yet.
        unchecked {
            return block.timestamp != _epochTimestamp
                && _posterFor(_epochTimestamp.nextEpoch()).addr == address(0);
        }
    }

    function _entryAt(uint256 _pointer) private view returns (LookaheadEntry storage) {
        return lookahead[_pointer]; // TODO
    }

    function _posterFor(uint256 _epochTimestamp) private view returns (Poster storage) {
        return posters[_epochTimestamp];
    }

    function _hashBLSPubKey(bytes calldata _BLSPubKey) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes16(0), _BLSPubKey));
    }

    function _insertFallbackPreconfer(uint256 _epochTimestamp) private { }
}
