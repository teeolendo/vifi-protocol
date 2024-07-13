// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "v3-core/contracts/interfaces/IUniswapV3Factory.sol";

address constant SWAP_ROUTER_02 = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;
address constant VUSD = 0x4A3Da8048e721Fb9D8363DCef2527e3c89d2A351;
address constant VTTD = 0xbb92DED6b4Ef829f68F22Ec76E1B2154F5F8C6Ee;
address constant VRT = 0x9ce1ADd19cc36400c8678F202EBCB22C296bD1F5;
address constant VARQ = 0xa43835EAB54474e76331f8F59E6CE2910964893C;
address constant FACTORY = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
address constant VIRTUALIZER = 0xc63E8A090C866D0e19553c73be02175242d52e9e;
address constant MUSDC = 0x13D07539925924304cD8104E82C6BB7256487F23;


contract VexSwap {

    IVirt constant virt = IVirt(VIRTUALIZER);
    IVARQ private constant varq = IVARQ(VARQ);
    ISwapRouter02 private constant router = ISwapRouter02(SWAP_ROUTER_02);
    IERC20 private constant vUSD = IERC20(VUSD);
    IERC20 private constant vTTD = IERC20(VTTD);
    IERC20 private constant vRT = IERC20(VRT);
    IERC20 private constant mUSDC = IERC20(MUSDC);
    IUniswapV3Factory public constant uniswapFactory = IUniswapV3Factory(FACTORY);
    uint24 public constant FEE = 500; // Example fee tier (0.05%)
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
            fee: FEE,
            recipient: address(this),
            amountIn: vRT_bal,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        router.exactInputSingle(params);
        uint256 vTTD_bal = vTTD.balanceOf(address(this));
        vTTD.transfer(msg.sender, vTTD_bal);
        
    }

    function swapVexIn_RWA(uint256 amountIn) external {

        mUSDC.transferFrom(msg.sender, address(this), amountIn);
        mUSDC.approve(address(virt), amountIn);
        virt.wrap(amountIn);
        //VexSwap
        //vUSD.transferFrom(msg.sender, address(this), amountIn);
        varq.convertVUSDToTokens(amountIn, address(this));
        uint256 vRT_bal = vRT.balanceOf(address(this));
        vRT.approve(address(router), vRT_bal);

        ISwapRouter02.ExactInputSingleParams memory params = ISwapRouter02
            .ExactInputSingleParams({
            tokenIn: VRT,
            tokenOut: VTTD,
            fee: FEE,
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
        uint256 total_rate = priceBeforeFees + CB_burnrate;

        uint256 split_ratio = (priceAfterFees*1e18)/total_rate;

        return (amountOut * split_ratio)/ 1e18;
    }

    function getLiveRateIn(uint256 amountOut) external view returns (uint256 price) {

        // get parrallel rate
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapFactory.getPool(VRT, VTTD, FEE)
        );
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 priceBeforeFees = uint256(sqrtPriceX96)
            * uint256(sqrtPriceX96)
            * 1e18
            >> (96 * 2);

        // get VARQ burn rate and normalized
        uint256 CB_burnrate = varq.getBurnCBrate() * 1e16;

        // rate together
        uint256 total_rate = priceBeforeFees + CB_burnrate;

        return (amountOut * total_rate)/ 1e18;
    }

    function getLiveRateOut(uint256 amountOut) external view returns (uint256 price) {

        // get parrallel rate
        IUniswapV3Pool pool = IUniswapV3Pool(
            uniswapFactory.getPool(VRT, VTTD, FEE)
        );
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        uint256 priceBeforeFees = uint256(sqrtPriceX96)
            * uint256(sqrtPriceX96)
            * 1e18
            >> (96 * 2);

        // get VARQ burn rate and normalized
        uint256 CB_burnrate = varq.getBurnCBrate() * 1e16;

        // rate together
        uint256 total_rate = priceBeforeFees + CB_burnrate;

        return (amountOut * 1e18)/ total_rate;
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
            fee: FEE,
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

    function swapVexOut_RWA(uint256 amountOut) external {
        
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
            fee: FEE,
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
        //vUSD.transfer(msg.sender, vUSD_bal_exit);
        //convert to RWA
        virt.unwrap(vUSD_bal_exit);
        mUSDC.transfer(msg.sender, vUSD_bal_exit);

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
            fee: FEE,
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
            fee: FEE,
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

interface IVirt {
    function wrap(uint256 amount) external;
    function unwrap(uint256 amount) external;
}
