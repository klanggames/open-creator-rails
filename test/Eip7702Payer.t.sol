// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseTest} from "./Base.t.sol";
import {IAsset} from "../src/IAsset.sol";
import {IAssetRegistry} from "../src/IAssetRegistry.sol";

/// @dev Minimal stand-in for the EIP-7702 delegate behind Privy native gas sponsorship (Alchemy Modular Account v2).
///      Calls arrive from the ERC-4337 EntryPoint, so a paymaster pays the gas, and are executed from the
///      delegated EOA's own address.
contract Mock7702Account {
    struct Call {
        address target;
        bytes data;
    }

    address public immutable ENTRY_POINT;

    error NotEntryPoint();

    constructor(address entryPoint) {
        ENTRY_POINT = entryPoint;
    }

    function execute(Call[] calldata calls) external {
        if (msg.sender != ENTRY_POINT && msg.sender != address(this)) {
            revert NotEntryPoint();
        }

        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.call(calls[i].data);
            if (!success) {
                assembly {
                    revert(add(result, 0x20), mload(result))
                }
            }
        }
    }
}

/// @notice Privy native gas sponsorship: the payer is an EOA delegated via EIP-7702 and every call is sponsored
///         through the EntryPoint. Such an EOA has code, so tokens that verify permits via ERC-1271 for
///         code-bearing owners (USDC FiatToken v2.2) reject its ECDSA permit; the allowance path is the way in.
contract Eip7702PayerTest is BaseTest {
    address internal constant ENTRY_POINT = address(0x4337);

    function setUp() public override {
        super.setUp();

        Mock7702Account implementation = new Mock7702Account(ENTRY_POINT);
        vm.signAndAttachDelegation(address(implementation), key);
        // The delegation is applied by the next call, as by a type-4 transaction.
        vm.prank(signer);
        Mock7702Account(signer).execute(new Mock7702Account.Call[](0));

        assertEq(signer.code, abi.encodePacked(hex"ef0100", address(implementation)), "signer is 7702-delegated");
    }

    /// @dev Sponsored execution: the EntryPoint (not the user) sends the transaction.
    function _sponsored(Mock7702Account.Call[] memory calls) internal {
        vm.prank(ENTRY_POINT, ENTRY_POINT);
        Mock7702Account(signer).execute(calls);
    }

    function _sponsoredSubscribe(uint256 count) internal {
        Mock7702Account.Call[] memory calls = new Mock7702Account.Call[](2);
        calls[0] = Mock7702Account.Call(
            address(testToken), abi.encodeCall(testToken.approve, (address(asset), asset.getSubscriptionPrice(count)))
        );
        calls[1] = Mock7702Account.Call(
            address(asset), abi.encodeCall(IAsset.subscribeWithAllowance, (_subscriber, count, SUBSCRIPTION_PRICE))
        );
        _sponsored(calls);
    }

    function test_sponsoredApproveAndSubscribe() public {
        uint256 signerBalanceBefore = testToken.balanceOf(signer);

        _sponsoredSubscribe(3);

        assertTrue(asset.isSubscriptionActive(_subscriber));
        assertEq(asset.getSubscriptionExpiration(_subscriber), block.timestamp + 3 * SUBSCRIPTION_DURATION);
        assertEq(testToken.balanceOf(signer), signerBalanceBefore - 3 * SUBSCRIPTION_PRICE);
        assertEq(testToken.allowance(signer, address(asset)), 0);
    }

    function test_sponsoredSubscribeViaRegistry() public {
        uint256 signerBalanceBefore = testToken.balanceOf(signer);

        Mock7702Account.Call[] memory calls = new Mock7702Account.Call[](2);
        calls[0] = Mock7702Account.Call(
            address(testToken), abi.encodeCall(testToken.approve, (address(asset), asset.getSubscriptionPrice(2)))
        );
        calls[1] = Mock7702Account.Call(
            address(assetRegistry),
            abi.encodeCall(IAssetRegistry.subscribeWithAllowance, (ASSET_ID, _subscriber, 2, SUBSCRIPTION_PRICE))
        );
        _sponsored(calls);

        assertEq(testToken.balanceOf(signer), signerBalanceBefore - 2 * SUBSCRIPTION_PRICE);
        assertEq(testToken.balanceOf(address(assetRegistry)), 0);
    }

    function test_sponsoredCancel_refundsDelegatedEoa() public {
        // The delegated EOA keeps its key, so its ECDSA cancellation signature is still valid, and a sponsored
        // call reaches the asset with msg.sender == the EOA.
        _sponsoredSubscribe(3);
        uint256 endTimeBefore = asset.getSubscriptionExpiration(_subscriber);
        vm.warp(block.timestamp + 1);
        uint256 signerBalanceBefore = testToken.balanceOf(signer);

        Mock7702Account.Call[] memory calls = new Mock7702Account.Call[](1);
        calls[0] = Mock7702Account.Call(
            address(asset),
            abi.encodeCall(IAsset.cancelSubscription, (SUBSCRIBER_ID, getCancellationSignature(SUBSCRIBER_ID, signer)))
        );
        _sponsored(calls);

        // The current (paid, non-refundable) period runs to its end; the remaining two are refunded.
        assertEq(asset.getSubscriptionExpiration(_subscriber), endTimeBefore - 2 * SUBSCRIPTION_DURATION);
        assertEq(testToken.balanceOf(signer), signerBalanceBefore + 2 * SUBSCRIPTION_PRICE);
    }

    function test_ownerRevoke_refundsDelegatedEoa() public {
        uint256 signerBalanceBefore = testToken.balanceOf(signer);
        _sponsoredSubscribe(2);

        vm.prank(assetOwner);
        asset.revokeSubscription(_subscriber);

        assertEq(testToken.balanceOf(signer), signerBalanceBefore);
    }
}
