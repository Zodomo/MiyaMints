// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./MiyaAVFactory.sol";
import "../../lib/AlignmentVault/src/IAlignmentVault.sol";
import "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "../../lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";

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
    error TransferFailed();

    event Implementation(address indexed implementation);
    event Deployed(address indexed deployer, address indexed collection, address indexed aligned, bytes32 salt);
    event OwnershipChanged(address indexed _erc721m, address indexed _oldOwner, address indexed _newOwner);

    address public erc721MiyaImplementation;
    MiyaAVFactory public miyaAVFactory;
    mapping(address => bool) private _isMiyaMintsContract;

    constructor(address _owner, address _erc721MiyaImplementation, address _miyaAVImplementation) payable {
        _initializeOwner(_owner);
        erc721MiyaImplementation = _erc721MiyaImplementation;
        emit Implementation(_erc721MiyaImplementation);
        miyaAVFactory = new MiyaAVFactory(address(this), _miyaAVImplementation);
    }

    // Update implementation address for new clones
    // NOTE: Does not update implementation of prior clones
    function updateImplementation(address _erc721MiyaImplementation) external onlyOwner {
        if (_erc721MiyaImplementation == erc721MiyaImplementation) revert();
        erc721MiyaImplementation = _erc721MiyaImplementation;
        emit Implementation(_erc721MiyaImplementation);
    }

    // Helper functions to get vault info from MiyaAVFactory in MiyaMints
    function getVault(address _erc721, uint256 _vaultId) external view returns (address) {
        return miyaAVFactory.vaults(_erc721, _vaultId);
    }

    function getDefaultVault(address _erc721) external view returns (address) {
        return miyaAVFactory.defaultVault(_erc721);
    }

    function getVaultIds(address _erc721) external view returns (uint256[] memory) {
        return miyaAVFactory.getVaultIds(_erc721);
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
    ) external returns (address deployment) {
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
    ) external returns (address deployment) {
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

    // Align the NFTs in the default (initial) vault for a given collection
    function alignNfts(address _erc721, uint256[] memory _tokenIds) external payable onlyOwner {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.defaultVault(_erc721));
        vault.alignNfts{value: msg.value}(_tokenIds);
    }
    // Align the NFTs in a specific vault for a given collection

    function alignNfts(address _erc721, uint256 _vaultId, uint256[] memory _tokenIds) external payable onlyOwner {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.vaults(_erc721, _vaultId));
        vault.alignNfts{value: msg.value}(_tokenIds);
    }

    // Align the tokens in the default (initial) vault for a given collection
    function alignTokens(address _erc721, uint256 _amount) external payable onlyOwner {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.defaultVault(_erc721));
        vault.alignTokens{value: msg.value}(_amount);
    }
    // Align the tokens in a specific vault for a given collection

    function alignTokens(address _erc721, uint256 _vaultId, uint256 _amount) external payable onlyOwner {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.vaults(_erc721, _vaultId));
        vault.alignTokens{value: msg.value}(_amount);
    }

    // Align as many NFTs that can be afforded and then all remaining tokens in the default vault for a given collection
    function alignMaxLiquidity(address _erc721) external payable onlyOwner {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.defaultVault(_erc721));
        vault.alignMaxLiquidity{value: msg.value}();
    }
    // Align as many NFTs that can be afforded and then all remaining tokens in a specific vault for a given collection

    function alignMaxLiquidity(address _erc721, uint256 _vaultId) external payable onlyOwner {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.vaults(_erc721, _vaultId));
        vault.alignMaxLiquidity{value: msg.value}();
    }

    // Claim the yield in the default vault for a given collection
    function claimYield(address _erc721) external payable {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.defaultVault(_erc721));
        vault.claimYield{value: msg.value}(address(this));
    }
    // Claim the yield in a specific vault for a given collection

    function claimYield(address _erc721, uint256 _vaultId) external payable {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.vaults(_erc721, _vaultId));
        vault.claimYield{value: msg.value}(address(this));
    }

    // Rescue unrelated tokens from a collection's default vault
    function rescueERC20(address _erc721, address _token, address _to) external payable onlyOwner returns (uint256) {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.defaultVault(_erc721));
        return vault.rescueERC20{value: msg.value}(_token, _to);
    }
    // Rescue unrelated tokens from a specific collection vault

    function rescueERC20(address _erc721, uint256 _vaultId, address _token, address _to)
        external
        payable
        onlyOwner
        returns (uint256)
    {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.vaults(_erc721, _vaultId));
        return vault.rescueERC20{value: msg.value}(_token, _to);
    }

    // Rescue unrelated NFTs from a collection's default vault
    function rescueERC721(address _erc721, address _token, uint256 _tokenId, address _to) external payable onlyOwner {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.defaultVault(_erc721));
        vault.rescueERC721{value: msg.value}(_token, _to, _tokenId);
    }
    // Rescue unrelated NFTs from a specific collection vault

    function rescueERC721(address _erc721, uint256 _vaultId, address _token, uint256 _tokenId, address _to)
        external
        payable
        onlyOwner
    {
        IAlignmentVault vault = IAlignmentVault(miyaAVFactory.vaults(_erc721, _vaultId));
        vault.rescueERC721{value: msg.value}(_token, _to, _tokenId);
    }

    // Withdraw token of any kind, primarily needed for yield
    function withdrawTokens(address _erc20, uint256 _amount, address _to) external onlyOwner {
        bool success = IERC20(_erc20).transferFrom(address(this), _to, _amount);
        if (!success) revert TransferFailed();
    }
    // Batch withdraw tokens of any kind, primarily needed for yield

    function withdrawTokens(address[] memory _erc20, uint256[] memory _amount, address _to) external onlyOwner {
        if (_erc20.length != _amount.length) revert Invalid();
        for (uint256 i; i < _erc20.length;) {
            bool success = IERC20(_erc20[i]).transferFrom(address(this), _to, _amount[i]);
            if (!success) revert TransferFailed();
            unchecked {
                ++i;
            }
        }
    }

    // Withdraw NFTs of any kind
    function withdrawNfts(address _erc721, uint256 _tokenId, address _to) external onlyOwner {
        IERC721(_erc721).transferFrom(address(this), _to, _tokenId);
    }
    // Batch withdraw NFTs of any kind

    function withdrawNfts(address[] memory _erc721, uint256[][] memory _tokenIds, address _to) external onlyOwner {
        if (_erc721.length != _tokenIds.length) revert Invalid();
        for (uint256 i; i < _erc721.length;) {
            for (uint256 j; j < _tokenIds[i].length;) {
                IERC721(_erc721[i]).transferFrom(address(this), _to, _tokenIds[i][j]);
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
