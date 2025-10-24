// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IwstEth} from "src/interfaces/tokens/IwstEth.sol";
import {FlashLoanMintHelperWSTETHandWETH} from "src/FlashLoanMintHelperWSTETHandWETH.sol";
import {MockLowLevelVault} from "test/mocks/MockLowLevelVault.sol";

contract FlashLoanMintHelperWSTETHandWETHTest is Test {
    FlashLoanMintHelperWSTETHandWETH public helper;
    MockLowLevelVault public vault;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    address public user;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        user = makeAddr("user");

        vault = new MockLowLevelVault(wstETH, WETH);
        helper = new FlashLoanMintHelperWSTETHandWETH(address(vault));

        deal(WETH, address(vault), 100000000 ether);
        deal(wstETH, user, 100000000 ether);
    }

    function test_MintSmallAmount() public {
        uint256 sharesToMint = 1 ether;

        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        uint256 userSharesBefore = vault.balanceOf(user);

        IERC20(wstETH).approve(address(helper), netWstEth);
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();

        uint256 userSharesAfter = vault.balanceOf(user);

        assertEq(userSharesAfter - userSharesBefore, sharesToMint, "Should mint correct number of shares");
    }

    function test_MintMediumAmount() public {
        uint256 sharesToMint = 10 ether;

        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        uint256 userSharesBefore = vault.balanceOf(user);

        IERC20(wstETH).approve(address(helper), netWstEth);
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();

        uint256 userSharesAfter = vault.balanceOf(user);

        assertEq(userSharesAfter - userSharesBefore, sharesToMint, "Should mint correct number of shares");
    }

    function test_MintLargeAmount() public {
        uint256 sharesToMint = 100 ether;

        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        uint256 userSharesBefore = vault.balanceOf(user);

        IERC20(wstETH).approve(address(helper), netWstEth);
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();

        uint256 userSharesAfter = vault.balanceOf(user);

        assertEq(userSharesAfter - userSharesBefore, sharesToMint, "Should mint correct number of shares");
    }

    function test_MintVerySmallAmount() public {
        uint256 sharesToMint = 0.1 ether;

        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        uint256 userSharesBefore = vault.balanceOf(user);

        IERC20(wstETH).approve(address(helper), netWstEth);
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();

        uint256 userSharesAfter = vault.balanceOf(user);

        assertEq(userSharesAfter - userSharesBefore, sharesToMint, "Should mint correct number of shares");
    }

    function test_MintPrecisionAmount() public {
        uint256 sharesToMint = 1.5 ether;

        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        uint256 userSharesBefore = vault.balanceOf(user);

        IERC20(wstETH).approve(address(helper), netWstEth);
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();

        uint256 userSharesAfter = vault.balanceOf(user);

        assertEq(userSharesAfter - userSharesBefore, sharesToMint, "Should mint correct number of shares");
    }

    // Fuzzing tests
    function testFuzz_MintShares(uint256 sharesToMint) public {
        // Bound to reasonable values to avoid overflow and ensure vault has enough liquidity
        sharesToMint = bound(sharesToMint, 0.01 ether, 1000 ether);

        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        uint256 userSharesBefore = vault.balanceOf(user);

        IERC20(wstETH).approve(address(helper), netWstEth);
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();

        uint256 userSharesAfter = vault.balanceOf(user);

        assertEq(userSharesAfter - userSharesBefore, sharesToMint, "Should mint correct number of shares");
    }

    function testFuzz_PreviewAccuracy(uint256 sharesToMint) public view {
        // Bound to reasonable values
        sharesToMint = bound(sharesToMint, 0.01 ether, 100 ether);

        (uint256 netWstEth, uint256 flashAmount) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        // Test that preview returns reasonable values
        assertGt(netWstEth, 0, "netWstEth should be positive");
        assertGt(flashAmount, 0, "flashAmount should be positive");
        assertLt(netWstEth, sharesToMint * 1e18, "netWstEth should be less than shares amount (capital efficiency)");
        assertLt(flashAmount, sharesToMint * 1e18, "flashAmount should be reasonable");
    }

    function testFuzz_MultipleMints(uint256 numMints, uint256 baseAmount) public {
        // Bound to reasonable values
        numMints = bound(numMints, 2, 10);
        baseAmount = bound(baseAmount, 0.1 ether, 10 ether);

        uint256 totalSharesMinted = 0;

        for (uint256 i = 0; i < numMints; i++) {
            uint256 sharesToMint = baseAmount + (i * 0.1 ether); // Vary amounts slightly

            (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

            vm.startPrank(user);
            uint256 userSharesBefore = vault.balanceOf(user);

            IERC20(wstETH).approve(address(helper), netWstEth);
            helper.mintSharesWithFlashLoan(sharesToMint);
            vm.stopPrank();

            uint256 userSharesAfter = vault.balanceOf(user);
            assertEq(userSharesAfter - userSharesBefore, sharesToMint, "Should mint correct number of shares");

            totalSharesMinted += sharesToMint;
        }

        assertEq(vault.balanceOf(user), totalSharesMinted, "Total shares should match sum of individual mints");
    }

    // Edge case tests
    function test_MinimumAmount() public {
        uint256 sharesToMint = 0.001 ether;

        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        uint256 userSharesBefore = vault.balanceOf(user);

        IERC20(wstETH).approve(address(helper), netWstEth);
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();

        uint256 userSharesAfter = vault.balanceOf(user);
        assertEq(userSharesAfter - userSharesBefore, sharesToMint, "Should mint correct number of shares");
    }

    function test_NoTokensLeftInHelper() public {
        uint256 sharesToMint = 0.99999999 ether;
        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        IERC20(wstETH).approve(address(helper), netWstEth);
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();

        // Verify helper doesn't hold any tokens after execution
        assertEq(IERC20(WETH).balanceOf(address(helper)), 0, "Helper should not hold WETH");
        // stETH may have up to 1 wei remaining due to rounding in rebasing calculations
        assertLe(IERC20(stETH).balanceOf(address(helper)), 1, "Helper should not hold more than 1 wei stETH");
        assertEq(IERC20(wstETH).balanceOf(address(helper)), 0, "Helper should not hold wstETH");
        assertEq(address(helper).balance, 0, "Helper should not hold ETH");
    }

    function test_RevertOnInsufficientApproval() public {
        uint256 sharesToMint = 10 ether;
        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(user);
        // Approve less than needed
        IERC20(wstETH).approve(address(helper), netWstEth - 1);

        vm.expectRevert();
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();
    }

    function test_RevertOnInsufficientBalance() public {
        address poorUser = makeAddr("poorUser");
        uint256 sharesToMint = 10 ether;

        (uint256 netWstEth,) = helper.previewMintSharesWithFlashLoan(sharesToMint);

        vm.startPrank(poorUser);
        IERC20(wstETH).approve(address(helper), netWstEth);

        vm.expectRevert();
        helper.mintSharesWithFlashLoan(sharesToMint);
        vm.stopPrank();
    }
}
