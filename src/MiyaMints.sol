// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./MiyaAVFactory.sol";
import "../lib/AlignmentVault/src/IAlignmentVault.sol";

interface IERC721MiyaInitialize {
    function initialize(
        string memory _name, // NFT collection name
        string memory _symbol, // NFT collection symbol/ticker
        string memory _baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory _contractURI, // Full Contract URI for NFT collection information
        uint40 _maxSupply, // Max mint supply
        uint16 _royalty, // Percentage of royalty fees in basis points (0 - 10000)
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        address _owner, // Collection owner
        address _alignedNft, // Address of aligned NFT collection mint funds are being dedicated to
        uint80 _price, // Standard mint price
        uint256 _vaultId // NFTX vault ID
    ) external;
    function disableInitializers() external;
}

contract MiyaMints is Ownable {
    error Invalid();

    event Implementation(address indexed implementation);
    event Deployed(address indexed deployer, address indexed collection, address indexed aligned, bytes32 salt);
    event OwnershipChanged(address indexed _erc721m, address indexed _oldOwner, address indexed _newOwner);

    address public erc721MiyaImplementation;
    MiyaAVFactory public miyaAVFactory;
    mapping(address => bool) private _isMiyaMintsContract;

    constructor(
        address _owner,
        address _erc721MiyaImplementation,
        address _miyaAVImplementation
    ) payable {
        _initializeOwner(_owner);
        erc721MiyaImplementation = _erc721MiyaImplementation;
        emit Implementation(_erc721MiyaImplementation);
        miyaAVFactory = new MiyaAVFactory(address(this), _miyaAVImplementation);
    }

    // Update implementation address for new clones
    // NOTE: Does not update implementation of prior clones
    function updateImplementation(address _erc721MiyaImplementation) external virtual onlyOwner {
        if (_erc721MiyaImplementation == erc721MiyaImplementation) revert();
        erc721MiyaImplementation = _erc721MiyaImplementation;
        emit Implementation(_erc721MiyaImplementation);
    }

    // Deploy ERC721Miya collection and fully initialize it
    function deploy(
        string memory _name, // NFT collection name
        string memory _symbol, // NFT collection symbol/ticker
        string memory _baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory _contractURI, // Full Contract URI for NFT collection information
        uint40 _maxSupply, // Max mint supply
        uint16 _royalty, // Percentage of royalty fees in basis points (0 - 10000)
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        address _owner, // Collection owner
        address _alignedNft, // Address of aligned NFT collection mint funds are being dedicated to
        uint80 _price, // Standard mint price
        uint256 _vaultId // NFTX vault ID
    ) external virtual returns (address deployment) {
        deployment = LibClone.clone(erc721MiyaImplementation);
        _isMiyaMintsContract[deployment] = true;
        IERC721MiyaInitialize(deployment).initialize(
            _name,
            _symbol,
            _baseURI,
            _contractURI,
            _maxSupply,
            _royalty,
            _allocation,
            _owner,
            _alignedNft,
            _price,
            _vaultId
        );
        IERC721MiyaInitialize(deployment).disableInitializers();
        emit Deployed(msg.sender, deployment, _alignedNft, 0);
    }

    // Deploy ERC721M collection to deterministic address
    function deployDeterministic(
        string memory _name, // NFT collection name
        string memory _symbol, // NFT collection symbol/ticker
        string memory _baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory _contractURI, // Full Contract URI for NFT collection information
        uint40 _maxSupply, // Max mint supply
        uint16 _royalty, // Percentage of royalty fees in basis points (0 - 10000)
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        address _owner, // Collection owner
        address _alignedNft, // Address of aligned NFT collection mint funds are being dedicated to
        uint80 _price, // Standard mint price
        uint256 _vaultId, // NFTX vault ID
        bytes32 _salt // Used to deterministically deploy to an address of choice
    ) external virtual returns (address deployment) {
        deployment = LibClone.cloneDeterministic(erc721MiyaImplementation, _salt);
        _isMiyaMintsContract[deployment] = true;
        IERC721MiyaInitialize(deployment).initialize(
            _name,
            _symbol,
            _baseURI,
            _contractURI,
            _maxSupply,
            _royalty,
            _allocation,
            _owner,
            _alignedNft,
            _price,
            _vaultId
        );
        IERC721MiyaInitialize(deployment).disableInitializers();
        emit Deployed(msg.sender, deployment, _alignedNft, _salt);
    }

    // Return initialization code hash of a clone of the current implementation
    function initCodeHash() external view returns (bytes32 hash) {
        hash = LibClone.initCodeHash(erc721MiyaImplementation);
    }

    // Predict address of deterministic clone of the current implementation
    function predictDeterministicAddress(bytes32 _salt) external view returns (address predicted) {
        predicted = LibClone.predictDeterministicAddress(erc721MiyaImplementation, _salt, address(this));
    }

    // Deploy vault if required, else return the already deployed vault
    function deployVault(address _erc721, uint256 _vaultId) external returns (address vault) {
        vault = miyaAVFactory.vaults(_erc721, _vaultId);
        if (vault == address(0)) {
            vault = miyaAVFactory.deploy(_erc721, _vaultId);
        }
    }

    // Allows deployed collections to update ownership status subgraph for frontend using events
    function ownershipChanged(address _oldOwner, address _newOwner) external {
        if (!_isMiyaMintsContract[msg.sender]) revert Invalid();
        emit OwnershipChanged(msg.sender, _oldOwner, _newOwner);
    }

    // TODO: Vault asset management controls
}
