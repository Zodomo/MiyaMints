// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "../lib/AlignmentVault/src/AlignmentVaultFactory.sol";

interface IMiyaAV {
    function vaultId() external view returns (uint256);
}

contract MiyaAVFactory is AlignmentVaultFactory {
    event Deployed(address indexed vault, address indexed erc721, uint256 indexed vaultId, bytes32 salt);

    // ERC721 address => MiyaAV address
    mapping(address => mapping(uint256 => address)) public vaults;

    constructor(address _owner, address _implementation) AlignmentVaultFactory(_owner, _implementation) { }

    /**
     * @notice Deploys a new AlignmentVault and fully initializes it.
     * @param _erc721 Address of the ERC721 token associated with the vault.
     * @param _vaultId NFTX Vault ID associated with _erc721
     * @return deployment Address of the newly deployed AlignmentVault.
     */
    function deploy(address _erc721, uint256 _vaultId) external override returns (address deployment) {
        deployment = LibClone.clone(implementation);
        IAVInitialize(deployment).initialize(_erc721, owner(), _vaultId);
        IAVInitialize(deployment).disableInitializers();
        if (_vaultId == 0) _vaultId = IMiyaAV(deployment).vaultId();
        vaults[_erc721][_vaultId] = deployment;
        emit Deployed(deployment, _erc721, _vaultId, 0);
    }

    /**
     * @notice Deploys a new AlignmentVault to a deterministic address based on the provided salt.
     * @param _erc721 Address of the ERC721 token associated with the vault.
     * @param _vaultId NFTX Vault ID associated with _erc721
     * @param _salt A unique salt to determine the address.
     * @return deployment Address of the newly deployed AlignmentVault.
     */
    function deployDeterministic(
        address _erc721,
        uint256 _vaultId,
        bytes32 _salt
    ) external override returns (address deployment) {
        deployment = LibClone.cloneDeterministic(implementation, _salt);
        IAVInitialize(deployment).initialize(_erc721, owner(), _vaultId);
        IAVInitialize(deployment).disableInitializers();
        if (_vaultId == 0) _vaultId = IMiyaAV(deployment).vaultId();
        vaults[_erc721][_vaultId] = deployment;
        emit Deployed(deployment, _erc721, _vaultId, _salt);
    }
}