// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {GameToken} from "../src/GameToken.sol";
import {DeployScript} from "./Deploy.s.sol";

contract GameTokenScript is DeployScript {
    function mint(address to, uint256 amount) public {
        vm.startBroadcast();
        GameToken token = GameToken(getAddress(".GameToken"));
        token.mint(to, amount);
        vm.stopBroadcast();
    }
}