// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "../../lib/solady/src/tokens/ERC721.sol";
import "../../lib/solady/src/utils/LibString.sol";

contract TestNFT is ERC721 {
    using LibString for uint256;

    error Invalid();

    string private _name;
    string private _symbol;
    string private _baseURI;
    uint256 public totalSupply;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) {
        _name = name_;
        _symbol = symbol_;
        _baseURI = baseURI_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
    function baseURI() public view returns (string memory) {
        return _baseURI;
    }
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        if (!_exists(_tokenId)) revert Invalid();
        string memory baseURI_ = baseURI();
        return (bytes(baseURI_).length > 0 ? string(abi.encodePacked(baseURI_, _tokenId.toString())) : "");
    }

    function mint() public {
        _mint(msg.sender, ++totalSupply);
    }
    function mint(uint256 _amount) public {
        for (uint256 i; i < _amount;) {
            unchecked {
                _mint(msg.sender, ++totalSupply);
                ++i;
            }
        }
    }

    function burn(uint256 _tokenId) public {
        if (ownerOf(_tokenId) != msg.sender) revert Invalid();
        _burn(_tokenId);
    }
}