// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// Import required OpenZeppelin contracts
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title NOVA NFT Dividend Contract
/// @notice This is an NFT contract that supports ERC20 token dividends
contract NOVANFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ERC20 token contract for dividends
    IERC20 public dividendToken;
    // Incremental NFT ID
    uint256 private _currentTokenId = 0;
    // NFT metadata URI
    string private _baseTokenURI;
    // Dividend related state variables
    uint256 private _lastProcessedIndex;
    uint256 private _currentDistributionBalance;
    bool private _isDistributing;

    // Constants
    uint256 public constant TARGET_SUPPLY = 1493;
    uint256 public batchSize = 200;

    /// @notice Initialize NFT contract

    constructor()
        ERC721("NOVA_NFT", "NOVA")
        Ownable(msg.sender)
    {
        _baseTokenURI = "https://raw.githubusercontent.com/chro-dev/Nova_nft/refs/heads/main/metadata/";
        // Mint first batch in constructor
        // uint256 firstBatch = batchSize;
        // if (firstBatch > TARGET_SUPPLY) {
        //     firstBatch = TARGET_SUPPLY;
        // }
        // for (uint256 i = 0; i < firstBatch; i++) {
        //     _mintTo(nftRecipient);  // Mint to nftRecipient
        // }
    }

    function setBatchsize(uint256 _size)external onlyOwner{
        batchSize = _size;
    }

    /// @notice Batch mint remaining NFTs
    /// @param to Address to receive NFTs
    function batchMint(address to) external onlyOwner {
        uint256 currentSupply = totalSupply();
        require(currentSupply < TARGET_SUPPLY, "Minting completed");
        
        uint256 remaining = TARGET_SUPPLY - currentSupply;
        uint256 currentBatchSize = remaining > batchSize ? batchSize : remaining;
        
        for (uint256 i = 0; i < currentBatchSize; i++) {
            _mintTo(to);  // Mint to specified address
        }
    }

    /// @notice Return base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice Set base URI, only contract owner can call
    /// @param baseURI New base URI
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /// @notice Set ERC20 token address for dividends
    /// @param _dividendToken ERC20 token contract address
    function setDividendToken(address _dividendToken) external onlyOwner {
        require(_dividendToken != address(0), "Invalid Token address");
        dividendToken = IERC20(_dividendToken);
    }

    /// @notice Internal mint function
    /// @param to Address to receive NFT
    function _mintTo(address to) internal {
        _currentTokenId += 1;
        _safeMint(to, _currentTokenId);
    }

    /// @notice External mint function, only contract owner can call
    /// @param to Address to receive NFT
    /// @param quantity Number of NFTs to mint
    function mint(address to, uint256 quantity) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(quantity > 0, "Amount must be greater than 0");

        for (uint256 i = 0; i < quantity; i++) {
            _mintTo(to);
        }
    }

    /// @notice Start a new round of dividend distribution
    function startDistribution() external nonReentrant {
        require(!_isDistributing, "Distribution in progress");
        uint256 contractBalance = dividendToken.balanceOf(address(this));
        require(contractBalance > 0, "No token can be distributed");
        
        uint256 totalNFTs = totalSupply();
        require(totalNFTs > 0, "No NFTs");
        
        _currentDistributionBalance = contractBalance;
        _lastProcessedIndex = 0;
        _isDistributing = true;
    }

    /// @notice Process dividend distribution in batches
    function batchDistribute() external nonReentrant {
        require(_isDistributing, "Distribution not started");
        uint256 totalNFTs = totalSupply();
        require(_lastProcessedIndex < totalNFTs, "Distribution completed");

        uint256 amountPerNFT = _currentDistributionBalance / totalNFTs;
        require(amountPerNFT > 0, "Amount per NFT too small");

        uint256 endIndex = _lastProcessedIndex + batchSize;
        if (endIndex > totalNFTs) {
            endIndex = totalNFTs;
        }

        for (uint256 i = _lastProcessedIndex; i < endIndex; i++) {
            uint256 tokenId = tokenByIndex(i);
            address owner = ownerOf(tokenId);
            dividendToken.safeTransfer(owner, amountPerNFT);
        }

        if (endIndex == totalNFTs) {
            _isDistributing = false;
            _currentDistributionBalance = 0;
        }
        _lastProcessedIndex = endIndex;
    }

    /// @notice Query current dividend distribution progress
    function getDistributionProgress() external view returns (
        bool isDistributing,
        uint256 lastProcessedIndex,
        uint256 currentSupply
    ) {
        return (_isDistributing, _lastProcessedIndex, totalSupply());
    }

    /// @notice Emergency withdrawal of tokens from contract
    /// @param token Token address to withdraw
    /// @param amount Amount to withdraw, 0 means withdraw all
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(!_isDistributing, "Distribution in progress");
        require(token != address(0), "Invalid token address");
        
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        
        uint256 withdrawAmount = amount == 0 ? balance : amount;
        require(withdrawAmount <= balance, "Insufficient balance");
        
        tokenContract.safeTransfer(msg.sender, withdrawAmount);
    }

    /// @notice Change dividend token address and withdraw old tokens
    /// @param newToken New dividend token address
    /// @param withdrawOld Whether to withdraw old tokens to admin address
    function changeDividendToken(address newToken, bool withdrawOld) external onlyOwner {
        require(!_isDistributing, "Distribution in progress");
        require(newToken != address(0), "Invalid new token address");
        
        // If need to withdraw old tokens
        if (withdrawOld && address(dividendToken) != address(0)) {
            uint256 oldBalance = dividendToken.balanceOf(address(this));
            if (oldBalance > 0) {
                dividendToken.safeTransfer(msg.sender, oldBalance);
            }
        }
        
        dividendToken = IERC20(newToken);
    }
}