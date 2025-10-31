// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Safe4626CollateralHelper} from "../src/Safe4626CollateralHelper.sol";
import {MockERC4626CollateralVault} from "./mocks/MockERC4626CollateralVault.sol";
import {IERC4626Collateral} from "../src/interfaces/IERC4626Collateral.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Safe4626CollateralHelperTest is Test {
    Safe4626CollateralHelper public helper;
    MockERC4626CollateralVault public vault;
    address public user = makeAddr("user");
    address public receiver = makeAddr("receiver");
    address public owner = makeAddr("owner");    
    ERC20Mock public mockAsset;

    uint256 public constant INITIAL_AMOUNT = 1000e18;
    uint256 public constant SLIPPAGE_TOLERANCE = 5; // 5%

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function setUp() public {
        helper = new Safe4626CollateralHelper();
        mockAsset = new ERC20Mock();
        vault = new MockERC4626CollateralVault(address(mockAsset));

        // Give user some initial balance
        vm.deal(user, 100 ether);
    }

    // ============ safeDepositCollateral Tests ============

    function test_safeDepositCollateral_Success() public {
        uint256 assets = 100e18;
        uint256 expectedShares = vault.previewDepositCollateral(assets);
        uint256 minSharesOut = expectedShares * (100 - SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(helper), receiver, assets, expectedShares);

        uint256 shares = helper.safeDepositCollateral(vault, assets, receiver, minSharesOut);

        assertEq(shares, expectedShares);
        assertEq(vault.balanceOf(receiver), expectedShares);
        assertGe(shares, minSharesOut);
    }

    function test_safeDepositCollateral_SlippageExceeded() public {
        uint256 assets = 100e18;
        uint256 expectedShares = vault.previewDepositCollateral(assets);
        uint256 minSharesOut = expectedShares + 1; // Set higher than expected

        // Expect the function to revert due to slippage
        vm.expectRevert();
        helper.safeDepositCollateral(vault, assets, receiver, minSharesOut);
    }

    function test_safeDepositCollateral_InvalidVault() public {
        uint256 assets = 100e18;
        uint256 minSharesOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(0)));

        helper.safeDepositCollateral(IERC4626Collateral(address(0)), assets, receiver, minSharesOut);
    }

    function test_safeDepositCollateral_VaultReverts() public {
        uint256 assets = 100e18;
        uint256 minSharesOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(vault)));
        helper.safeDepositCollateral(vault, assets, receiver, minSharesOut);
    }

    // ============ safeMintCollateral Tests ============

    function test_safeMintCollateral_Success() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewMintCollateral(shares);
        uint256 maxAssetsIn = expectedAssets * (100 + SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(helper), receiver, expectedAssets, shares);

        uint256 assets = helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);

        assertEq(assets, expectedAssets);
        assertEq(vault.balanceOf(receiver), shares);
        assertLe(assets, maxAssetsIn);
    }

    function test_safeMintCollateral_SlippageExceeded() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewMintCollateral(shares);
        uint256 maxAssetsIn = expectedAssets - 1; // Set lower than expected

        vm.expectRevert(
            abi.encodeWithSelector(
                Safe4626CollateralHelper.SlippageExceeded.selector,
                expectedAssets // actual
            )
        );

        helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);
    }

    function test_safeMintCollateral_InvalidVault() public {
        uint256 shares = 100e18;
        uint256 maxAssetsIn = 100e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(0)));

        helper.safeMintCollateral(IERC4626Collateral(address(0)), shares, receiver, maxAssetsIn);
    }

    function test_safeMintCollateral_VaultReverts() public {
        uint256 shares = 100e18;
        uint256 maxAssetsIn = 100e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(vault)));
        helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);
    }

    // ============ safeWithdrawCollateral Tests ============

    function test_safeWithdrawCollateral_Success() public {
        // First deposit some assets to have shares to withdraw
        uint256 depositAssets = 100e18;
        uint256 depositShares = vault.depositCollateral(depositAssets, owner);

        uint256 withdrawAssets = 50e18;
        uint256 expectedShares = vault.previewWithdrawCollateral(withdrawAssets);
        uint256 maxSharesOut = expectedShares * (100 + SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(helper), receiver, owner, withdrawAssets, expectedShares);

        uint256 shares = helper.safeWithdrawCollateral(vault, withdrawAssets, receiver, owner, maxSharesOut);

        assertEq(shares, expectedShares);
        assertEq(vault.balanceOf(owner), depositShares - expectedShares);
        assertLe(shares, maxSharesOut);
    }

    function test_safeWithdrawCollateral_SlippageExceeded() public {
        // First deposit some assets
        uint256 depositAssets = 100e18;
        vault.depositCollateral(depositAssets, owner);

        uint256 withdrawAssets = 50e18;
        uint256 expectedShares = vault.previewWithdrawCollateral(withdrawAssets);
        uint256 maxSharesOut = expectedShares - 1; // Set lower than expected

        vm.expectRevert(
            abi.encodeWithSelector(
                Safe4626CollateralHelper.SlippageExceeded.selector,
                expectedShares // actual
            )
        );

        helper.safeWithdrawCollateral(vault, withdrawAssets, receiver, owner, maxSharesOut);
    }

    function test_safeWithdrawCollateral_InvalidVault() public {
        uint256 withdrawAssets = 50e18;
        uint256 maxSharesOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(0)));

        helper.safeWithdrawCollateral(IERC4626Collateral(address(0)), withdrawAssets, receiver, owner, maxSharesOut);
    }

    function test_safeWithdrawCollateral_VaultReverts() public {
        uint256 withdrawAssets = 50e18;
        uint256 maxSharesOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(vault)));
        helper.safeWithdrawCollateral(vault, withdrawAssets, receiver, owner, maxSharesOut);
    }

    // ============ safeRedeemCollateral Tests ============

    function test_safeRedeemCollateral_Success() public {
        // First deposit some assets to have shares to redeem
        uint256 depositAssets = 100e18;
        uint256 depositShares = vault.depositCollateral(depositAssets, owner);

        uint256 redeemShares = 50e18;
        uint256 expectedAssets = vault.previewRedeemCollateral(redeemShares);
        uint256 minAssetsOut = expectedAssets * (100 - SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(helper), receiver, owner, expectedAssets, redeemShares);

        uint256 assets = helper.safeRedeemCollateral(vault, redeemShares, receiver, owner, minAssetsOut);

        assertEq(assets, expectedAssets);
        assertEq(vault.balanceOf(owner), depositShares - redeemShares);
        assertGe(assets, minAssetsOut);
    }

    function test_safeRedeemCollateral_SlippageExceeded() public {
        // First deposit some assets
        uint256 depositAssets = 100e18;
        vault.depositCollateral(depositAssets, owner);

        uint256 redeemShares = 50e18;
        uint256 expectedAssets = vault.previewRedeemCollateral(redeemShares);
        uint256 minAssetsOut = expectedAssets + 1; // Set higher than expected

        // Expect the function to revert due to slippage
        vm.expectRevert();
        helper.safeRedeemCollateral(vault, redeemShares, receiver, owner, minAssetsOut);
    }

    function test_safeRedeemCollateral_InvalidVault() public {
        uint256 redeemShares = 50e18;
        uint256 minAssetsOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(0)));

        helper.safeRedeemCollateral(IERC4626Collateral(address(0)), redeemShares, receiver, owner, minAssetsOut);
    }

    function test_safeRedeemCollateral_VaultReverts() public {
        uint256 redeemShares = 50e18;
        uint256 minAssetsOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(vault)));
        helper.safeRedeemCollateral(vault, redeemShares, receiver, owner, minAssetsOut);
    }

    // ============ Edge Cases ============

    function test_safeDepositCollateral_ZeroAmount() public {
        uint256 assets = 0;
        uint256 minSharesOut = 0;

        uint256 shares = helper.safeDepositCollateral(vault, assets, receiver, minSharesOut);
        assertEq(shares, 0);
        assertEq(vault.balanceOf(receiver), 0);
    }

    function test_safeMintCollateral_ZeroAmount() public {
        uint256 shares = 0;
        uint256 maxAssetsIn = 0;

        uint256 assets = helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);
        assertEq(assets, 0);
        assertEq(vault.balanceOf(receiver), 0);
    }

    function test_safeWithdrawCollateral_ZeroAmount() public {
        // First deposit some assets
        vault.depositCollateral(100e18, owner);

        uint256 withdrawAssets = 0;
        uint256 maxSharesOut = 0;

        uint256 shares = helper.safeWithdrawCollateral(vault, withdrawAssets, receiver, owner, maxSharesOut);
        assertEq(shares, 0);
    }

    function test_safeRedeemCollateral_ZeroAmount() public {
        // First deposit some assets
        vault.depositCollateral(100e18, owner);

        uint256 redeemShares = 0;
        uint256 minAssetsOut = 0;

        uint256 assets = helper.safeRedeemCollateral(vault, redeemShares, receiver, owner, minAssetsOut);
        assertEq(assets, 0);
    }

    // ============ Integration Tests ============

    function test_FullDepositWithdrawCycle() public {
        // Deposit
        uint256 depositAssets = 100e18;
        uint256 depositShares = helper.safeDepositCollateral(vault, depositAssets, owner, depositAssets * 95 / 100);

        assertEq(vault.balanceOf(owner), depositShares);

        // Withdraw
        uint256 withdrawAssets = 50e18;
        uint256 withdrawShares =
            helper.safeWithdrawCollateral(vault, withdrawAssets, receiver, owner, withdrawAssets * 105 / 100);

        assertEq(vault.balanceOf(owner), depositShares - withdrawShares);
    }

    function test_FullMintRedeemCycle() public {
        // Mint
        uint256 mintShares = 100e18;
        helper.safeMintCollateral(vault, mintShares, owner, mintShares * 105 / 100);

        assertEq(vault.balanceOf(owner), mintShares);

        // Redeem
        uint256 redeemShares = 50e18;
        helper.safeRedeemCollateral(vault, redeemShares, receiver, owner, redeemShares * 95 / 100);

        assertEq(vault.balanceOf(owner), mintShares - redeemShares);
    }
}
