// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract SikaSwap is Ownable, ERC20 {
    struct AccountInfo {
        bool isLPPool;
        bool isLiquidityHolder;
        bool isBlackListed;
    }
    mapping(address => AccountInfo) public accountInfo;
    uint256 private constant TOTAL_SUPPLY = 127 * (1e6) * (1e18);
    uint256 public constant DENOMINATOR = 10000; // 100%
    uint256 public constant MAX_BUY_FEE_NUMERATOR = 400; // 4%
    uint256 public constant MAX_SELL_FEE_NUMERATOR = 400; // 4%

    uint256 public constant MAX_HOLD_AMOUNT = 4 * (1e6) * (1e18);
    uint256 public constant MAX_SELL_AMOUNT = 5 * (1e5) * (1e18);
    uint256 public maxBuyAmount = 4 * (1e6) * (1e18);

    // mainnet
    IFactory UNISWAP_FACTORY =
        IFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f); // UNISWAP_FACTORY
    address UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // uniswapRouter
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // wrapped ETH

    // Sepolia
    // IFactory constant UNISWAP_FACTORY =
    //     IFactory(0xB7f907f7A9eBC822a80BD25E224be42Ce0A698A0); // UNISWAP_FACTORY
    // address constant UNISWAP_V2_ROUTER = 0x425141165d3DE9FEC831896C016617a52363b687; // uniswapRouter
    // address constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // wrapped ETH

    address immutable public uniswapV2Pair; // liquidity pool address

    address public taxAddress;
    bool public blacklistAddRestrictedForever;

    bool public tradingEnabled = false;

    /// @notice Emitted when a liquidity pool pair is updated.
    event LPPairSet(address indexed pair, bool enabled);

    /// @notice Emitted when an account is marked or unmarked as a liquidity holder (treasury, staking, etc).
    event LiquidityHolderSet(address indexed account, bool flag);

    event BlacklistSet(address indexed account, bool flag);

    /// @notice Emitted (once) when blacklist add is restricted forever.
    event BlacklistAddRestrictedForever();

    event TaxAddressSet(address _taxAddress);
    event BuyFeePaid(address indexed from, address indexed to, uint256 amount);
    event SellFeePaid(address indexed from, address indexed to, uint256 amount);

    constructor(address _taxAddress) ERC20("SikaSwap", "$SIKA") Ownable(msg.sender) {
        uniswapV2Pair = UNISWAP_FACTORY.createPair(address(this), WETH);

        setLiquidityHolder(msg.sender, true);
        setLiquidityHolder(_taxAddress, true);
        setLiquidityHolder(UNISWAP_V2_ROUTER, true);
        setLiquidityHolder(uniswapV2Pair, true);
        setLpPair(uniswapV2Pair, true);
        setTaxAddress(_taxAddress);
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    // Setters with onlyOwner

    function setLpPair(address pair, bool enabled) public onlyOwner {
        accountInfo[pair].isLPPool = enabled;
        emit LPPairSet(pair, enabled);
    }

    function setLiquidityHolder(address account, bool flag) public onlyOwner {
        accountInfo[account].isLiquidityHolder = flag;
        emit LiquidityHolderSet(account, flag);
    }

    function setTaxAddress(address newTaxAddress) public onlyOwner {
        require(newTaxAddress != address(0), "Tax address cannot be zero");
        taxAddress = newTaxAddress;
        emit TaxAddressSet(newTaxAddress);
    }

    function restrictBlacklistAddForever() external onlyOwner {
        require(!blacklistAddRestrictedForever, "already set");
        blacklistAddRestrictedForever = true;
        emit BlacklistAddRestrictedForever();
    }

    // enable trading
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
    }

    function setBlacklisted(
        address account,
        bool isBlacklisted
    ) external onlyOwner {
        if (isBlacklisted) {
            require(
                !blacklistAddRestrictedForever,
                "Blacklist add restricted forever"
            );
        }
        accountInfo[account].isBlackListed = isBlacklisted;
        emit BlacklistSet(account, isBlacklisted);
    }

    function setMaxBuyAmount(uint256 amount) external onlyOwner {
        maxBuyAmount = amount;
    }

    function _hasLimits(
        AccountInfo memory fromInfo,
        AccountInfo memory toInfo
    ) internal pure returns (bool) {
        return (!fromInfo.isLiquidityHolder || !toInfo.isLiquidityHolder);
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        AccountInfo memory fromInfo = accountInfo[from];
        AccountInfo memory toInfo = accountInfo[to];
        // check blacklist
        require(
            !fromInfo.isBlackListed && !toInfo.isBlackListed,
            "Blacklisted"
        );
        super._update(from, to, amount);
        if (
            !_hasLimits(fromInfo, toInfo) ||
            (fromInfo.isLPPool && toInfo.isLPPool)
        ) {
            return;
        }

        uint256 taxFee = 0;

        if (fromInfo.isLPPool) {
            require(tradingEnabled, "Trading is not enabled!");
            taxFee = (amount * MAX_BUY_FEE_NUMERATOR) / DENOMINATOR;
            require(
                amount - taxFee <= maxBuyAmount,
                "Transfer amount exceeds the max buy amount"
            );
            emit BuyFeePaid(from, taxAddress, taxFee);
        } else if (toInfo.isLPPool) {
            require(tradingEnabled, "Trading is not enabled!");
            taxFee = (amount * MAX_SELL_FEE_NUMERATOR) / DENOMINATOR;
            require(
                amount - taxFee <= MAX_SELL_AMOUNT,
                "Transfer amount exceeds the max sell amount"
            );
            emit SellFeePaid(from, taxAddress, taxFee);
        }
        if (taxFee > 0) super._update(to, taxAddress, taxFee);

        // check max holding amount
        if (!toInfo.isLiquidityHolder) {
            require(
                balanceOf(to) <= MAX_HOLD_AMOUNT,
                "Transfer amount exceeds the max holding amount"
            );
        }
    }
}
