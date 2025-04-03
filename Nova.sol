// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// 导入所需的 OpenZeppelin 合约
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title NOVA NFT 分红合约
/// @notice 这是一个支持 ERC20 代币分红的 NFT 合约
contract NOVANFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // 用于分红的 ERC20 代币合约
    IERC20 public dividendToken;
    // NFT 的递增 ID
    uint256 private _currentTokenId = 0;
    // NFT 元数据 URI
    string private _baseTokenURI;
    // 分红相关的状态变量
    uint256 private _lastProcessedIndex;
    uint256 private _currentDistributionBalance;
    bool private _isDistributing;

    // 常量定义
    uint256 public constant TARGET_SUPPLY = 1493;
    uint256 public batchSize = 300;

    /// @notice 初始化 NFT 合约并铸造初始代币
    /// @param initialOwner 初始所有者地址（合约拥有者）
    /// @param nftRecipient 接收初始铸造 NFT 的地址
    constructor(address initialOwner, address nftRecipient)
        ERC721("NOVA_NFT", "NOVA")
        Ownable(initialOwner)
    {
        _baseTokenURI = "https://raw.githubusercontent.com/chro-dev/Nova_nft/refs/heads/main/metadata/";
        // 在构造函数中先铸造第一批
        uint256 firstBatch = batchSize;
        if (firstBatch > TARGET_SUPPLY) {
            firstBatch = TARGET_SUPPLY;
        }
        for (uint256 i = 0; i < firstBatch; i++) {
            _mintTo(nftRecipient);  // 铸造给 nftRecipient
        }
    }

    /// @notice 批量铸造剩余的 NFT
    /// @param to 接收 NFT 的地址
    function batchMint(address to) external onlyOwner {
        uint256 currentSupply = totalSupply();
        require(currentSupply < TARGET_SUPPLY, "Minting completed");
        
        uint256 remaining = TARGET_SUPPLY - currentSupply;
        uint256 currentBatchSize = remaining > batchSize ? batchSize : remaining;
        
        for (uint256 i = 0; i < currentBatchSize; i++) {
            _mintTo(to);  // 铸造给指定的地址 to
        }
    }

    /// @notice 返回基础 URI
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice 设置基础 URI，只有合约所有者可以调用
    /// @param baseURI 新的基础 URI
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    /// @notice 设置用于分红的 ERC20 代币地址
    /// @param _dividendToken ERC20 代币合约地址
    function setDividendToken(address _dividendToken) external onlyOwner {
        require(_dividendToken != address(0), "Invalid Token address");
        dividendToken = IERC20(_dividendToken);
    }

    /// @notice 内部铸造函数
    /// @param to 接收 NFT 的地址
    function _mintTo(address to) internal {
        _currentTokenId += 1;
        _safeMint(to, _currentTokenId);
    }

    /// @notice 外部铸造函数，只有合约所有者可以调用
    /// @param to 接收 NFT 的地址
    /// @param quantity 要铸造的数量
    function mint(address to, uint256 quantity) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(quantity > 0, "Amount must be greater than 0");

        for (uint256 i = 0; i < quantity; i++) {
            _mintTo(to);
        }
    }

    /// @notice 开始一轮新的分红
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

    /// @notice 分批处理分红
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

    /// @notice 查询当前分红进度
    function getDistributionProgress() external view returns (
        bool isDistributing,
        uint256 lastProcessedIndex,
        uint256 currentSupply
    ) {
        return (_isDistributing, _lastProcessedIndex, totalSupply());
    }

    /// @notice 紧急提取合约中的代币
    /// @param token 要提取的代币地址
    /// @param amount 提取数量，0 表示全部提取
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

    /// @notice 修改分红代币地址并提取旧代币
    /// @param newToken 新的分红代币地址
    /// @param withdrawOld 是否提取旧代币到管理员地址
    function changeDividendToken(address newToken, bool withdrawOld) external onlyOwner {
        require(!_isDistributing, "Distribution in progress");
        require(newToken != address(0), "Invalid new token address");
        
        // 如果需要提取旧代币
        if (withdrawOld && address(dividendToken) != address(0)) {
            uint256 oldBalance = dividendToken.balanceOf(address(this));
            if (oldBalance > 0) {
                dividendToken.safeTransfer(msg.sender, oldBalance);
            }
        }
        
        dividendToken = IERC20(newToken);
    }
}