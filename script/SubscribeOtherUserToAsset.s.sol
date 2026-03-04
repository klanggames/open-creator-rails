// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Asset.sol";
import "../src/GameToken.sol";

contract SubscribeOtherUserToAsset is Script {
    function run() external {
        // Example CI command (with env vars):
        // RPC_URL=$RPC_URL \
        // PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY \
        // SUBSCRIBER_PRIVATE_KEY=$SUBSCRIBER_PRIVATE_KEY \
        // ASSET_ADDRESS=$ASSET_ADDRESS \
        // GAME_TOKEN_ADDRESS=$GAME_TOKEN_ADDRESS \
        // forge script script/SubscribeOtherUserToAsset.s.sol:SubscribeOtherUserToAsset \
        //   --rpc-url $RPC_URL --broadcast -vvv

        // Broadcaster / owner of GameToken (same deployer as in the deploy script)
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        // The other user who will be the actual subscriber
        uint256 subscriberKey = vm.envUint("SUBSCRIBER_PRIVATE_KEY");
        address subscriber = vm.addr(subscriberKey);

        // Already deployed contracts
        Asset gameAsset = Asset(vm.envAddress("ASSET_ADDRESS"));
        GameToken gameToken = GameToken(vm.envAddress("GAME_TOKEN_ADDRESS"));

        vm.startBroadcast(deployerKey);

        // Ensure the subscriber has enough GameTokens to pay for the subscription
        gameToken.mint(subscriber, 100e18);

        // Subscribe as the other user via permit so the indexer sees another SubscriptionAdded
        _subscribeViaPermit(gameToken, gameAsset, subscriberKey, subscriber, 10e18);

        vm.stopBroadcast();
    }

    function _subscribeViaPermit(
        GameToken gameToken,
        Asset gameAsset,
        uint256 userKey,
        address user,
        uint256 value
    ) internal {
        address subscriptionUser = user;
        address subscriptionSpender = address(gameAsset);
        uint256 subscriptionValue = value;
        uint256 deadline = block.timestamp + 1 hours;

        // Build EIP-2612 permit digest for GameToken
        bytes32 PERMIT_TYPEHASH = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                subscriptionUser,
                subscriptionSpender,
                subscriptionValue,
                gameToken.nonces(subscriptionUser),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                gameToken.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);

        bool subscribed = gameAsset.subscribe(
            subscriptionUser,
            subscriptionSpender,
            subscriptionValue,
            deadline,
            v,
            r,
            s
        );

        console.log("SubscriptionAdded (other user) emitted, success:", subscribed);
    }
}

