//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";

// ----------------------INTERFACE------------------------------

// Aave
// https://docs.aave.com/developers/the-core-protocol/lendingpool/ilendingpool

interface ILendingPool {
    /**
     * Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
     * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
     *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of theliquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     **/
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    /**
     * Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralETH the total collateral in ETH of the user
     * @return totalDebtETH the total debt in ETH of the user
     * @return availableBorrowsETH the borrowing power left of the user
     * @return currentLiquidationThreshold the liquidation threshold of the user
     * @return ltv the loan to value of the user
     * @return healthFactor the current health factor of the user
     **/
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

// UniswapV2

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IERC20.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/Pair-ERC-20
interface IERC20 {
    // Returns the account balance of another account with address _owner.
    function balanceOf(address owner) external view returns (uint256);

    /**
     * Allows _spender to withdraw from your account multiple times, up to the _value amount.
     * If this function is called again it overwrites the current allowance with _value.
     * Lets msg.sender set their allowance for a spender.
     **/
    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT

    /**
     * Transfers _value amount of tokens to address _to, and MUST fire the Transfer event.
     * The function SHOULD throw if the message caller’s account balance does not have enough tokens to spend.
     * Lets msg.sender send pool tokens to an address.
     **/
    function transfer(address to, uint256 value) external returns (bool);
}

// https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IWETH.sol
interface IWETH is IERC20 {
    // Convert the wrapped token back to Ether.
    function withdraw(uint256) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Callee.sol
// The flash loan liquidator we plan to implement this time should be a UniswapV2 Callee
interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/factory
interface IUniswapV2Factory {
    // Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/pair
interface IUniswapV2Pair {
    /**Event
     * Swaps tokens
 

For regular swaps, data.length must be 0.
     * Also see [Flash Swaps](https://docs.uniswap.org/protocol/V2/concepts/core-concepts/flash-swaps).
     **/
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    /**
     * Returns the reserves of token0 and token1 used to price trades and distribute liquidity.
     * See Pricing[https://docs.uniswap.org/protocol/V2/concepts/advanced-topics/pricing].
     * Also returns the block.timestamp (mod 2**32) of the last block during which an interaction occured for the pair.
     **/
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
    // Returns the address of token0 and token1 that the pair contract trades.    
    function token0() external view returns (address);
    function token1() external view returns (address);
}


// This is the interface for the router which is alternatively used for 
// swapping WBTC to WETH and unwrapping WETH to ETH at the end of operate() function
// Uniswap V2 Router02 Interface
// https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol

/*
interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (
        uint amountA,
        uint amountB,
        uint liquidity
    );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
}

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (
        uint amountA,
        uint amountB,
        uint liquidity
    );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
}
*/


// ----------------------IMPLEMENTATION------------------------------

contract LiquidationOperator is IUniswapV2Callee {
    uint8 public constant health_factor_decimals = 18;

    // defined constants used in the contract including ERC-20 tokens, Uniswap Pairs, Aave lending pools, etc. */
    //    
    
    
    // Aave v2 main lending pool
    // checksummed Aave v2 LendingPool address on Ethereum mainnet
    ILendingPool public constant LENDING_POOL = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    
    // Uniswap V2 factory & router
    IUniswapV2Factory public constant UNISWAP_FACTORY =
        IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    
    
    /*
    IUniswapV2Router02 public constant UNISWAP_ROUTER =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
*/
        // Tokens

        // IERC20() wrapper transforms an address into an ERC-20 token interface

    IERC20 public constant USDT =
        IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7); // 6 decimals
    IERC20 public constant WBTC =
        IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599); // 8 decimals
    IWETH public constant WETH =
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);


        // Uniswap pair we use for flash swap: WBTC / USDT
    IUniswapV2Pair public immutable WBTC_USDT_PAIR; // SINCE IMUTABLE, WE WILL INITIALIZE IT IN CONSTRUCTOR

    IUniswapV2Pair public immutable WBTC_WETH_PAIR;

    // Liquidation target (borrower) from the original tx
    address public constant LIQUIDATION_USER =
        0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F;



    // Example amount to cover (from the reference tx, adjust if your lab uses a different setup)
    // 2,916,378.221684 USDT (with 6 decimals)
    uint256 public constant DEBT_TO_COVER_USDT = 2_916_378_221684;

    


    

    

    // some helper function, it is totally fine if you can finish the lab without using these function
    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
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
       
        // Solve $(x + \Delta x_{eff})(y- \Delta y) = xy$ for $\Delta y$ 

        uint256 amountInWithFee = amountIn * 997; 
        uint256 numerator = amountInWithFee * reserveOut; 
        uint256 denominator = reserveIn * 1000 + amountInWithFee; 
        amountOut = numerator / denominator; 
    }

    // some helper function, it is totally fine if you can finish the lab without using these function
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
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

        // Solve $(x + \Delta x_{eff})(y- \Delta y) = xy$ for $\Delta x$ 


        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1; // This is just rounding up
    }

    constructor() {
        // Initialize the WBTC/USDT pair from the factory
        // Here we use a tmp variable pair so we can first check for address(0) 
        //and not assign it directly to an imutable variable WBTC_USDT_PAIR. 
        // TODO: ask if this is indeed necessary or some gpt bullshit

        // Tukaj nam geetPair() vrne type address, ki ga moramo pretvoriti v IUniswapV2Pair 
        //z uporabo IUniswapV2Pair()

        IUniswapV2Pair pair = IUniswapV2Pair(
            UNISWAP_FACTORY.getPair(address(WBTC), address(USDT))
        );
        require(address(pair) != address(0), "WBTC/USDT pair not found"); //If pair does not exist getPair returns address(0)
        WBTC_USDT_PAIR = pair;

        
        
        IUniswapV2Pair pair2 = IUniswapV2Pair(
            UNISWAP_FACTORY.getPair(address(WBTC), address(WETH))
        );
        require(address(pair2) != address(0), "WBTC/WETH pair not found"); //If pair does not exist getPair returns address(0)
        WBTC_WETH_PAIR = pair2;
        
    }

    // Closed TODO: add a `receive` function so that you can withdraw your WETH

    // Since ETH is the native token, the contract needs to be able to accept ETH deposits. 
    // require a receive function that serves this purpose alone
    
    receive() external payable {}
    // END TODO

    // required by the testing script, entry for your liquidation call
    function operate() external {
        // Closed TODO: implement your liquidation logic

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
            "Target user is not liquidatable"
        );

        // 2. call flash swap to liquidate the target user
        // based on https://etherscan.io/tx/0xac7df37a43fab1b130318bbb761861b8357650db2e2c6493b73d6da3d9581077
        // we know that the target user borrowed USDT with WBTC as collateral
        // we should borrow USDT, liquidate the target user and get the WBTC, then swap WBTC to repay uniswap
        // (please feel free to develop other workflows as long as they liquidate the target user successfully)
        
        // Cap borrow to available USDT liquidity in the pair to avoid INSUFFICIENT_LIQUIDITY
        (uint112 reserve0, uint112 reserve1, ) = WBTC_USDT_PAIR.getReserves();
        address token0WBTC_USDT_Pair = WBTC_USDT_PAIR.token0();
        uint256 reserveUSDT = token0WBTC_USDT_Pair == address(USDT)
            ? uint256(reserve0)
            : uint256(reserve1);

        uint256 amountToBorrowUSDT = DEBT_TO_COVER_USDT; // 2,916,378.221684 USDT (with 6 decimals)
        // Leave headroom: cap to ~33% of available USDT liquidity to avoid extreme slippage
        uint256 maxBorrow = reserveUSDT / 3;
        if (amountToBorrowUSDT > maxBorrow) {
            amountToBorrowUSDT = maxBorrow;
        }

        require(amountToBorrowUSDT > 0, "Not enough USDT liquidity to borrow");

        // Figure out which token is token0 / token1 so we know where to put amountOut
        uint256 amount0Out = 0;
        uint256 amount1Out = 0;

        if (token0WBTC_USDT_Pair == address(USDT)) {
            amount0Out = amountToBorrowUSDT;
        } else {
            amount1Out = amountToBorrowUSDT;
        }
        
        // We borrow USDT from the WBTC/USDT pair using a flash swap.

        // non-empty data triggers flash swap callback
        WBTC_USDT_PAIR.swap(
            amount0Out,
            amount1Out,
            address(this),
            abi.encode(uint256(1))
        );

        
        



        // 3. Convert the profit into ETH and send back to sender
        // According to gpt this part is ussually done via Uniswap Router as bellow. 
        // Here we hardcode it directly for WBTC -> WETH swap

        /*
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
        */

        



        uint256 wbtcProfit = WBTC.balanceOf(address(this));
        if (wbtcProfit > 0) {
            address token0WBTC_WETH_Pair = WBTC_WETH_PAIR.token0();

            (uint112 reserve0, uint112 reserve1, ) = WBTC_WETH_PAIR
                .getReserves();
            
            // TODO : Vprasi a je res treba z if stavkom to delat al je praksa 
            // da se nekje online odčita vrstni red paira in uporabi tisto?
            if (token0WBTC_WETH_Pair == address(WBTC)) {
                // WBTC is token0
                uint256 wethOut = getAmountOut(
                    wbtcProfit,
                    reserve0,
                    reserve1
                );
                if (wethOut == 0) {
                    revert("Not enough WBTC profit to swap");
                }

                // Approve WBTC_WETH_PAIR to spend WBTC
                WBTC.transfer(address(WBTC_WETH_PAIR), wbtcProfit);

                // Swap WBTC → WETH
                WBTC_WETH_PAIR.swap(0, wethOut, address(this), new bytes(0));

                // unwrap all WETH held (covers this swap and any residual)
                uint256 wethBalance = WETH.balanceOf(address(this));
                if (wethBalance > 0) {
                    WETH.withdraw(wethBalance); // unwrap WETH to ETH
                }

            } else {
                // WBTC is token1
                uint256 wethOut = getAmountOut(
                    wbtcProfit,
                    reserve1,
                    reserve0
                );
                if (wethOut == 0) {
                    revert("Not enough WBTC profit to swap");
                }

                // Approve WBTC_WETH_PAIR to spend WBTC
                WBTC.transfer(address(WBTC_WETH_PAIR), wbtcProfit);

                // Swap WBTC → WETH
                WBTC_WETH_PAIR.swap(wethOut, 0, address(this), new bytes(0));

                // unwrap all WETH held (covers this swap and any residual)
                uint256 wethBalance = WETH.balanceOf(address(this));
                if (wethBalance > 0) {
                    WETH.withdraw(wethBalance); // unwrap WETH to ETH
                }


            }

            // forward all ETH balance to the caller
            uint256 ethBalance = address(this).balance;
            if (ethBalance > 0) {
                (bool sent, ) = payable(msg.sender).call{value: ethBalance}("");
                require(sent, "ETH transfer to caller failed");
            }
        }



        // END TODO
    }

    // required by the swap
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,    
        bytes calldata /* data */
    ) external override {
        // Closed TODO: implement your liquidation logic

        // Persist the original operate() caller if you ever want to use it here. Currently commented out since not used.
        // address callerFromOperate = abi.decode(data, (address));

        // 2.0. security checks and initializing variables
        // Ensure only the correct pair can call us (msg.sender is who is runign the smart contract function and in this case it should be the pair contract since we are doing a flash swap from there and are now in the callback function)
        require(msg.sender == address(WBTC_USDT_PAIR), "invalid caller");

        // Ensure this contract initiated the flash swap (sender is the address that initiated the flash swap, which should be this contract)
        require(sender == address(this), "invalid sender");

        // Determine how much USDT we borrowed
        address token0WBTC_USDT_Pair = WBTC_USDT_PAIR.token0();
        uint256 usdtBorrowed;

        if (token0WBTC_USDT_Pair == address(USDT)) {
            usdtBorrowed = amount0;
        } else {
            usdtBorrowed = amount1;
        }

        // 2.1 liquidate the target user
        
        // Approve Aave to pull the borrowed USDT
        //Difference between approve and transfer is that approve allows another address to spend tokens on your behalf, while transfer moves tokens directly from your account to another address. Here we want Aave to pull the USDT from our contract, so we use approve.
        USDT.approve(address(LENDING_POOL), 0); // reset to 0 first for USDT safety
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

        if (token0WBTC_USDT_Pair == address(WBTC)) {
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
        
        // END TODO
    }
}
