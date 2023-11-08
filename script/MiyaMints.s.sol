// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {Script, console2} from "../lib/forge-std/src/Script.sol";

contract MiyaMintsScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
    }
}
