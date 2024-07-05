// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/PoolFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(
            address(poolToken),
            address(weth),
            "LTokenA",
            "LA"
        );

        // weth.mint(liquidityProvider, 200e18);
        // poolToken.mint(liquidityProvider, 200e18);

        // weth.mint(user, 10e18);
        // poolToken.mint(user, 10e18);
    }

    modifier deposit() {
        vm.startPrank(liquidityProvider);

        // ETH
        weth.mint(liquidityProvider, 1000e18);
        weth.approve(address(pool), 1000e18);
        // Link
        poolToken.mint(liquidityProvider, 1000e18);
        poolToken.approve(address(pool), 1000e18);

        pool.deposit(
            1000e18, // WETH
            1000e18, // Min TSWAP-Token
            1000e18, // Max Link
            uint64(block.timestamp)
        );
        vm.stopPrank();

        assertEq(pool.balanceOf(liquidityProvider), 1000e18); // started with 0
        assertEq(weth.balanceOf(liquidityProvider), 0); // started with 200
        assertEq(poolToken.balanceOf(liquidityProvider), 0); // started with 200

        // The pool should have 100 WETH and 100 Link
        assertEq(weth.balanceOf(address(pool)), 1000e18);
        assertEq(poolToken.balanceOf(address(pool)), 1000e18);
        _;
    }

    //https://faisalkhan.com/learn/payments-wiki/formulas-for-automated-market-makers-amms/
    function test_getOutputAmountBasedOnInput() public {
        // "For your 100e18 tokens X, we can give you 90.9090 tokens Y."
        uint256 inputAmount = 100e18;
        uint256 inputReserve = 1000e18;
        uint256 outputReserve = 1000e18;

        // dy = dx * y / (x + dx)
        uint256 outputAmount = pool.getOutputAmountBasedOnInput(
            inputAmount,
            inputReserve,
            outputReserve
        );
        //90.909090909090909090
        console.log("outputAmount", outputAmount);
    }

    // todo
    // Start here - revist math in getInputAmountBasedOnOutput
    // determine when to use getInputAmountBasedOnOutput vs getOutputAmountBasedOnInput
    // then move to getOutputAmountBasedOnInput
    // getOutput seems to be how much of said token needs to be removed from pool to keep K constant
    // getInput seems to be how much of said token needs to be added to pool to keep K constant
    // prompt next - why are ^ these two funcs inverses of each other
    // -
    //"To receive 100e18 tokens Y, you need to provide approximately 111.1111 tokens X."
    function test_getInputAmountBasedOnOutput() public {
        uint256 outputAmount = 100e18;
        uint256 inputReserve = 1000e18;
        uint256 outputReserve = 1000e18;

        // dy = dx * y / (x + dx)
        // getInputAmountBasedOnOutput solves for dx
        uint256 end = pool.getInputAmountBasedOnOutput(
            outputAmount,
            inputReserve,
            outputReserve
        );
        //111.111111111111111111
        console.log("outputAmount", end);
    }

    // // @audit output should be weth
    function test_sellPoolTokens() public deposit {
        uint256 desiredWethForPoolTokens = 100e18; //outputAmount

        uint256 poolTokensNeeded = pool.getInputAmountBasedOnOutput(
            desiredWethForPoolTokens,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );

        vm.startPrank(user);

        poolToken.mint(user, poolTokensNeeded);
        poolToken.approve(address(pool), poolTokensNeeded);

        // weth.mint(user, poolTokensNeeded);
        // weth.approve(address(pool), poolTokensNeeded);

        console.log("poolToken Balance Before: ", poolToken.balanceOf(user));
        console.log("weth Balance Before: ", weth.balanceOf(user));
        pool.sellPoolTokens(desiredWethForPoolTokens, 90909090909090909090);
        console.log("poolToken Balance After: ", poolToken.balanceOf(user));
        console.log("weth Balance After: ", weth.balanceOf(user));
        vm.stopPrank();

        assertEq(weth.balanceOf(user), 90909090909090909090);
        //111.111111111111111111
    }

    // Fuzz test where `outputAmount` is fuzzed by Foundry
    function testFuzzGetInputAmountBasedOnOutput(uint256 outputAmount) public {
        uint256 inputReserve = 1000e18;
        uint256 outputReserve = 1000e18;

        // To prevent unrealistic test cases and divide-by-zero errors
        vm.assume(outputAmount > 0 && outputAmount < outputReserve);

        // dy = dx * y / (x + dx)
        // getInputAmountBasedOnOutput solves for dx
        uint256 inputAmount = pool.getInputAmountBasedOnOutput(
            outputAmount,
            inputReserve,
            outputReserve
        );

        // Calculate expected dx to verify correctness of the function
        uint256 expectedInputAmount = (outputAmount * inputReserve) /
            (outputReserve - outputAmount);

        // Logging for debugging purposes
        console.log("Calculated inputAmount", inputAmount);
        console.log("Expected inputAmount", expectedInputAmount);

        // Assertion to ensure the calculation within the contract is correct
        assertEq(inputAmount, expectedInputAmount);
    }

    // --------------OLD TESTS----------------

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(
            poolToken,
            10e18,
            weth,
            expected,
            uint64(block.timestamp)
        );
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(
            poolToken,
            10e18,
            weth,
            expected,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(
            weth.balanceOf(liquidityProvider) +
                poolToken.balanceOf(liquidityProvider) >
                400e18
        );
    }
}
