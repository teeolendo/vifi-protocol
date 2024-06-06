// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

address constant SWAP_ROUTER_02 = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
address constant VUSD = 0xFcde9E29C280c3efCC0297c2CCE67B6810f15B67;
address constant VTTD = 0x9eCA688094720Ab7fd5d74530b07ECA182590221;
address constant VRT = 0x9874fe5f4736C755E4b9A3FF77977a23A6f93C7f;
address constant VARQ = 0x73F19409B2bC99cC3933D742e2A2f2449a6d3266;
address constant FACTORY = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;


contract VexSwap {

    IVARQ private constant varq = IVARQ(VARQ);
    ISwapRouter02 private constant router = ISwapRouter02(SWAP_ROUTER_02);
    IERC20 private constant vUSD = IERC20(VUSD);
    IERC20 private constant vTTD = IERC20(VTTD);
    IERC20 private constant vRT = IERC20(VRT);
    IUniswapV3Factory public constant uniswapFactory = IUniswapV3Factory(FACTORY);
    uint24 public constant FEE = 3000; // Example fee tier (0.3%)
    address public constant tokenIn = VRT; // VRT
    address public constant tokenOut = VTTD; // VTTD

    function swapVexIn(uint256 amountIn) external {

        vUSD.transferFrom(msg.sender, address(this), amountIn);
        varq.convertVUSDToTokens(amountIn, address(this));
        uint256 vRT_bal = vRT.balanceOf(address(this));
        vRT.approve(address(router), vRT_bal);

        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
            tokenIn: VRT,
            tokenOut: VTTD,
            fee: 3000,
            recipient: address(this),
            amountIn: vRT_bal,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        router.exactInputSingle(params);
        uint256 vTTD_bal = vTTD.balanceOf(address(this));
        vTTD.transfer(msg.sender, vTTD_bal);
        
    }

    function getPriceV2() external view returns (uint256 price) {
        // get parrallel rate
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapFactory.getPool(VRT, VTTD, FEE)
        );
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 priceBeforeFees = uint256(sqrtPriceX96)
            * uint256(sqrtPriceX96)
            * 1e18
            >> (96 * 2);
        uint256 priceAfterFees = priceBeforeFees * (10000 - FEE) / 10000;

        // get VARQ burn rate and normalized
        uint256 CB_burnrate = varq.getBurnCBrate() * 1e16;

        // rate together
        uint256 total_rate = priceAfterFees + CB_burnrate;

        return total_rate;
    }

    function getParallelRatio() external view returns (uint256 price) {
        // get parrallel rate
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapFactory.getPool(VRT, VTTD, FEE)
        );
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 priceBeforeFees = uint256(sqrtPriceX96)
            * uint256(sqrtPriceX96)
            * 1e18
            >> (96 * 2);
        uint256 priceAfterFees = priceBeforeFees * (10000 - FEE) / 10000;

        // get VARQ burn rate and normalized
        uint256 CB_burnrate = varq.getBurnCBrate() * 1e16;

        // rate together
        uint256 total_rate = priceAfterFees + CB_burnrate;

        return (priceAfterFees*1e18/total_rate);
    }

    function getSplit(uint256 amountOut) external view returns (uint256 price) {
        // get parrallel rate
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapFactory.getPool(VRT, VTTD, FEE)
        );
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 priceBeforeFees = uint256(sqrtPriceX96)
            * uint256(sqrtPriceX96)
            * 1e18
            >> (96 * 2);
        uint256 priceAfterFees = priceBeforeFees * (10000 - FEE) / 10000;

        // get VARQ burn rate and normalized
        uint256 CB_burnrate = varq.getBurnCBrate() * 1e16;

        // rate together
        uint256 total_rate = priceAfterFees + CB_burnrate;

        uint256 split_ratio = (priceAfterFees*1e18)/total_rate;

        return (amountOut * split_ratio)/ 1e18;
    }

    function swapVexOut(uint256 amountOut) external {
        
        // get vTTD in
        vTTD.transferFrom(msg.sender, address(this), amountOut);

        // get parrallel rate
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapFactory.getPool(VRT, VTTD, FEE)
        );
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 priceBeforeFees = uint256(sqrtPriceX96)
            * uint256(sqrtPriceX96)
            * 1e18
            >> (96 * 2);
        //uint256 priceAfterFees = priceBeforeFees * (10000 - FEE) / 10000;

        // get VARQ burn rate and normalized
        uint256 CB_burnrate = varq.getBurnCBrate() * 1e16;

        // rate together
        uint256 total_rate = priceBeforeFees + CB_burnrate;

        uint256 split_ratio = (priceBeforeFees*1e18)/total_rate;

        uint256 amt_of_vTTD_to_swap_for_vRT = (amountOut * split_ratio)/ 1e18;

        vTTD.approve(address(router), amt_of_vTTD_to_swap_for_vRT);

        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
            tokenIn: VTTD,
            tokenOut: VRT,
            fee: 3000,
            recipient: address(this),
            amountIn: amt_of_vTTD_to_swap_for_vRT,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        router.exactInputSingle(params);
        uint256 vRT_bal = vRT.balanceOf(address(this));
        varq.convertTokensToVUSD(vRT_bal, address(this));
        // all converted

        // check balances
        uint256 vRT_bal_exit = vRT.balanceOf(address(this));
        uint256 vTTD_bal_exit = vTTD.balanceOf(address(this));

        if (vRT_bal_exit > 0) {
            vRT.transfer(msg.sender, vRT_bal_exit);
        }

        if (vTTD_bal_exit > 0) {
            vTTD.transfer(msg.sender, vTTD_bal_exit);
        }

        uint256 vUSD_bal_exit = vUSD.balanceOf(address(this));
        vUSD.transfer(msg.sender, vUSD_bal_exit);

    }


    function swapExactInputSingleHop(uint256 amountIn, uint256 amountOutMin)
        external
    {
        vRT.transferFrom(msg.sender, address(this), amountIn);
        vRT.approve(address(router), amountIn);

        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
            tokenIn: VRT,
            tokenOut: VTTD,
            fee: 3000,
            recipient: msg.sender,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        router.exactInputSingle(params);
    }

    function swapExactOutputSingleHop(uint256 amountOut, uint256 amountInMax)
        external
    {
        vRT.transferFrom(msg.sender, address(this), amountInMax);
        vRT.approve(address(router), amountInMax);

        ISwapRouter02.ExactOutputSingleParams memory params = ISwapRouter02
            .ExactOutputSingleParams({
            tokenIn: VRT,
            tokenOut: VTTD,
            fee: 3000,
            recipient: msg.sender,
            amountOut: amountOut,
            amountInMaximum: amountInMax,
            sqrtPriceLimitX96: 0
        });

        uint256 amountIn = router.exactOutputSingle(params);

        if (amountIn < amountInMax) {
            vRT.approve(address(router), 0);
            vRT.transfer(msg.sender, amountInMax - amountIn);
        }
    }
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        returns (uint256 amountIn);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount)
        external
        returns (bool);
}

interface IVARQ {
    function convertVUSDToTokens(uint256 vUSDAmount, address destination) external;
    function convertTokensToVUSD(uint256 vRTAmount, address destination) external;
    function getBurnCBrate() external view returns (uint256);
}
