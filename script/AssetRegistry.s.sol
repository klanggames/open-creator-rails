// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {AssetRegistry} from "../src/AssetRegistry.sol";
import {GameToken} from "../src/GameToken.sol";
import {DeployScript} from "./Deploy.s.sol";

contract AssetRegistryScript is DeployScript {
    AssetRegistry public assetRegistry;
    GameToken public gameToken;

    function setUp() public {
        assetRegistry = AssetRegistry(getAddress(".AssetRegistry"));
        gameToken = GameToken(getAddress(".GameToken"));
    }

    function createAsset(string memory _assetId, uint256 _subscriptionPrice) public {
        vm.startBroadcast();
        address asset = assetRegistry.createAsset(keccak256(abi.encodePacked(_assetId)), _subscriptionPrice, address(gameToken));
        console.log(string.concat(_assetId, " Asset created: ", vm.toString(asset)));     
        vm.stopBroadcast();
    }

    function removeAsset(string memory _assetId) public {
        vm.startBroadcast();
        bool success = assetRegistry.removeAsset(keccak256(abi.encodePacked(_assetId)));
        require(success, "Failed to remove asset");
        console.log(string.concat(_assetId, " Asset removed"));
        vm.stopBroadcast();
    }
}