// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseTest} from "./Base.t.sol";
import {Asset} from "../src/Asset.sol";
import {IAsset} from "../src/IAsset.sol";
import {TestToken} from "../src/TestToken.sol";
import {SignatureChecker} from "lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";

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

/// @dev Checks permits like USDC (FiatToken v2.2): ECDSA for an owner without code, ERC-1271 for one with code.
contract Erc1271PermitToken is TestToken {
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
        override
    {
        if (block.timestamp > deadline) {
            revert ERC2612ExpiredSignature(deadline);
        }

        bytes32 hash =
            _hashTypedDataV4(keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline)));

        if (!SignatureChecker.isValidSignatureNow(owner, hash, abi.encodePacked(r, s, v))) {
            revert ERC2612InvalidSigner(address(0), owner);
        }

        _approve(owner, spender, value);
    }
}

/// @notice Privy native gas sponsorship: the payer is an EOA delegated via EIP-7702 and every call is sponsored
///         through the EntryPoint. Such an EOA has code, so tokens that verify permits via ERC-1271 for
///         code-bearing owners (USDC FiatToken v2.2) reject its ECDSA permit; the allowance path is the way in.
contract Eip7702PayerTest is BaseTest {
    address internal constant ENTRY_POINT = address(0x4337);

    function _newToken() internal override returns (TestToken) {
        return new Erc1271PermitToken();
    }

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

    function test_sponsoredPermitSubscribe_reverts() public {
        // The delegated EOA's ECDSA permit is checked via ERC-1271 and rejected, so `subscribe` cannot be used.
        uint256 value = asset.getSubscriptionPrice(1);
        (uint8 v, bytes32 r, bytes32 s) = getPermit(signer, address(asset), value, block.timestamp);

        Mock7702Account.Call[] memory calls = new Mock7702Account.Call[](1);
        calls[0] = Mock7702Account.Call(
            address(asset),
            abi.encodeCall(IAsset.subscribe, (_subscriber, signer, address(asset), 1, block.timestamp, v, r, s))
        );

        vm.expectRevert(Asset.PermitFailed.selector);
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
