// ----------------------IMPLEMENTATION------------------------------

contract LiquidationOperator is IUniswapV2Callee {
    uint8 public constant health_factor_decimals = 18;

    // ---------- CONSTANTS / STATE ----------

    // Aave v2 LendingPool (Ethereum mainnet)
    ILendingPool public constant LENDING_POOL =
        ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69D1F);

    // Uniswap V2 factory & router
    IUniswapV2Factory public constant UNISWAP_FACTORY =
        IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IUniswapV2Router02 public constant UNISWAP_ROUTER =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    // Tokens
    IERC20 public constant USDT =
        IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7); // 6 decimals
    IERC20 public constant WBTC =
        IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599); // 8 decimals
    IWETH public constant WETH =
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Uniswap V2 pair: WBTC/USDT (we get it via factory)
    IUniswapV2Pair public immutable WBTC_USDT_PAIR;

    // Target user (from the tx in the lab)
    address public constant LIQUIDATION_USER =
        0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F;

    // Example amount to cover (from the reference tx, adjust if your lab uses a different setup)
    // 2,916,378.221684 USDT (with 6 decimals)
    uint256 public constant DEBT_TO_COVER_USDT = 2_916_378_221684;

    // ---------- HELPERS (already given) ----------

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    constructor() {
        // Initialize the WBTC/USDT pair from the factory
        IUniswapV2Pair pair = IUniswapV2Pair(
            UNISWAP_FACTORY.getPair(address(WBTC), address(USDT))
        );
        require(address(pair) != address(0), "WBTC/USDT pair not found");
        WBTC_USDT_PAIR = pair;
    }

    // allow contract to receive ETH when unwrapping WETH
    receive() external payable {}

    // required by the testing script, entry for your liquidation call
    function operate() external {
        // 0. security checks and initializing variables
        address caller = msg.sender;

        // 1. get the target user account data & make sure it is liquidatable
        (
            ,
            ,
            ,
            ,
            ,
            uint256 healthFactor
        ) = LENDING_POOL.getUserAccountData(LIQUIDATION_USER);

        require(
            healthFactor < 10 ** health_factor_decimals,
            "user not liquidatable"
        );

        // 2. call flash swap to liquidate the target user
        // We borrow USDT from the WBTC/USDT pair using a flash swap.

        uint256 amountToBorrow = DEBT_TO_COVER_USDT;

        // Figure out which token is token0 / token1 so we know where to put amountOut
        address token0 = WBTC_USDT_PAIR.token0();
        uint256 amount0Out = 0;
        uint256 amount1Out = 0;

        if (token0 == address(USDT)) {
            // USDT is token0
            amount0Out = amountToBorrow;
        } else {
            // USDT is token1
            amount1Out = amountToBorrow;
        }

        // We don't actually need to pass any special data; non-empty is enough to trigger the callback
        bytes memory data = abi.encode(caller);

        WBTC_USDT_PAIR.swap(
            amount0Out,
            amount1Out,
            address(this), // this contract receives the USDT
            data           // non-empty → triggers uniswapV2Call
        );

        // 3. Convert the profit into ETH and send back to sender
        // After uniswapV2Call has finished, the flash swap is fully repaid.
        // Any leftover WBTC in this contract is profit.

        uint256 wbtcProfit = WBTC.balanceOf(address(this));
        if (wbtcProfit > 0) {
            // Approve router to spend WBTC
            WBTC.approve(address(UNISWAP_ROUTER), wbtcProfit);

            // Swap WBTC → WETH, then router unwraps WETH -> ETH (swapExactTokensForETH)
            address;
            path[0] = address(WBTC);
            path[1] = UNISWAP_ROUTER.WETH();

            UNISWAP_ROUTER.swapExactTokensForETH(
                wbtcProfit,
                0,        // accept any amount of ETH (for lab purposes)
                path,
                caller,   // send ETH directly to the operator caller
                block.timestamp
            );
        }
    }

    // required by the swap
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata /* data */
    ) external override {
        // 2.0. security checks and initializing variables

        // Ensure only the correct pair can call us
        require(msg.sender == address(WBTC_USDT_PAIR), "invalid caller");
        // Ensure this contract initiated the flash swap
        require(sender == address(this), "invalid sender");

        // Determine how much USDT we borrowed
        address token0 = WBTC_USDT_PAIR.token0();
        uint256 usdtBorrowed;

        if (token0 == address(USDT)) {
            usdtBorrowed = amount0;
        } else {
            usdtBorrowed = amount1;
        }

        // 2.1 liquidate the target user on Aave

        // Approve Aave to pull the borrowed USDT
        USDT.approve(address(LENDING_POOL), usdtBorrowed);

        // We repay user’s USDT debt, receive WBTC as collateral
        LENDING_POOL.liquidationCall(
            address(WBTC),        // collateralAsset
            address(USDT),        // debtAsset
            LIQUIDATION_USER,     // borrower
            usdtBorrowed,         // debt to cover
            false                 // receive underlying WBTC, not aTokens
        );

        // Now this contract holds some WBTC (collateral from liquidation)
        uint256 wbtcBalance = WBTC.balanceOf(address(this));

        // 2.2 swap WBTC for other things or repay directly
        // Here we "repay directly" in WBTC using the pair's pricing.
        (uint112 reserve0, uint112 reserve1, ) = WBTC_USDT_PAIR.getReserves();

        uint256 reserveWBTC;
        uint256 reserveUSDT;

        if (token0 == address(WBTC)) {
            reserveWBTC = uint256(reserve0);
            reserveUSDT = uint256(reserve1);
        } else {
            reserveWBTC = uint256(reserve1);
            reserveUSDT = uint256(reserve0);
        }

        // Compute how much WBTC we must send back to "pay for" the borrowed USDT
        uint256 wbtcToRepay = getAmountIn(
            usdtBorrowed,   // amountOut in USDT
            reserveWBTC,    // reserveIn  (WBTC)
            reserveUSDT     // reserveOut (USDT)
        );

        require(wbtcBalance >= wbtcToRepay, "not enough WBTC to repay");

        // 2.3 repay
        // Send WBTC back to the pair. Once this function finishes,
        // Uniswap will check that the x*y=k invariant (with fees) holds.
        WBTC.transfer(address(WBTC_USDT_PAIR), wbtcToRepay);

        // Any leftover WBTC stays in this contract as profit,
        // to be converted to ETH in operate().
    }
}
