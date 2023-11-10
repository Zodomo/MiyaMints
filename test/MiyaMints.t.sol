// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {Test, console2} from "../lib/forge-std/src/Test.sol";
import {MiyaMints} from "../src/MiyaMints.sol";
import {ERC721Miya} from "../src/ERC721Miya.sol";
import {MiyaAV} from "../src/MiyaAV.sol";

interface IERC721Miya {
    function mint() external payable;
    function openMint() external;
}

contract MiyaMintsTest is Test {
    MiyaAV public miyaAv;
    ERC721Miya public erc721Miya;
    MiyaMints public miyaMints;

    function setUp() public {
        miyaAv = new MiyaAV();
        erc721Miya = new ERC721Miya();
        miyaMints = new MiyaMints(address(this), address(erc721Miya), address(miyaAv));
    }

    function testFullDeployment() public {
        address deployment = miyaMints.deployDeterministic(
            "Miya Test",
            "MIYA",
            "https://miyamaker.com/api/",
            "https://miyamaker.com/api/contract.json",
            420,
            777,
            1500,
            address(this),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5,
            0.01 ether,
            392,
            bytes32(hex'77777777777777')
        );
        address predicted = miyaMints.predictDeterministicAddress(hex'77777777777777');
        require(deployment == predicted, "deterministic address error");
        IERC721Miya erc721M = IERC721Miya(deployment);
        erc721M.openMint();
        erc721M.mint{ value: 0.01 ether }();
        miyaMints.alignMaxLiquidity(0x5Af0D9827E0c53E4799BB226655A1de152A425a5);
    }
}
