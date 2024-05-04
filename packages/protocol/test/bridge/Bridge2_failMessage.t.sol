// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./Bridge2.t.sol";

contract TestToContract {
    function anotherFunc() external { }
}

contract BridgeTest2_failMessage is BridgeTest2 {
    function test_bridge2_failMessage_not_by_destOwner() public transactedBy(Carol) {
        IBridge.Message memory message;
        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;
        message.gasLimit = 1_000_000;
        message.fee = 1000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = Bob;

        vm.expectRevert(Bridge.B_PERMISSION_DENIED.selector);
        bridge.failMessage(message);
    }

    function test_bridge2_failMessage_by_destOwner__message_failed() public transactedBy(Alice) {
        TestToContract target = new TestToContract();

        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 1_000_000;
        message.fee = 5_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = address(target);
        message.data = abi.encodeCall(TestToContract.anotherFunc, ());

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        bridge.failMessage(message);

        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.RETRIABLE);

        bridge.failMessage(message);
        hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.FAILED);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        bridge.failMessage(message);
    }

    function test_bridge2_failMessage_by_destOwner__message_processed()
        public
        transactedBy(Alice)
    {
        IBridge.Message memory message;

        message.destChainId = uint64(block.chainid);
        message.srcChainId = remoteChainId;

        message.gasLimit = 0;
        message.fee = 1_000_000;
        message.value = 2 ether;
        message.destOwner = Alice;
        message.to = David;

        uint256 aliceBalance = Alice.balance;
        uint256 davidBalance = David.balance;

        bridge.processMessage(message, fakeProof);
        bytes32 hash = bridge.hashMessage(message);
        assertTrue(bridge.messageStatus(hash) == IBridge.Status.DONE);

        vm.expectRevert(Bridge.B_INVALID_STATUS.selector);
        bridge.failMessage(message);
    }
}
