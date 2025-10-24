// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Safe4626Helper} from "../src/Safe4626Helper.sol";
import {MockERC4626Vault} from "./mocks/MockERC4626Vault.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";

contract Safe4626HelperTest is Test {
    Safe4626Helper public helper;
    MockERC4626Vault public vault;
    address public user = makeAddr("user");
    address public receiver = makeAddr("receiver");
    address public owner = makeAddr("owner");

    uint256 public constant INITIAL_AMOUNT = 1000e18;
    uint256 public constant SLIPPAGE_TOLERANCE = 5; // 5%

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function setUp() public {
        helper = new Safe4626Helper();

        // Deploy mock asset token
        address mockAsset = makeAddr("mockAsset");
        vault = new MockERC4626Vault(mockAsset);

        // Give user some initial balance
        vm.deal(user, 100 ether);
    }

    // ============ safeDeposit Tests ============

    function test_safeDeposit_Success() public {
        uint256 assets = 100e18;
        uint256 expectedShares = vault.previewDeposit(assets);
        uint256 minSharesOut = expectedShares * (100 - SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(helper), receiver, assets, expectedShares);

        uint256 shares = helper.safeDeposit(vault, assets, receiver, minSharesOut);

        assertEq(shares, expectedShares);
        assertEq(vault.balanceOf(receiver), expectedShares);
        assertGe(shares, minSharesOut);
    }

    function test_safeDeposit_SlippageExceeded() public {
        uint256 assets = 100e18;
        uint256 expectedShares = vault.previewDeposit(assets);
        uint256 minSharesOut = expectedShares + 1; // Set higher than expected

        // Expect the function to revert due to slippage
        vm.expectRevert();
        helper.safeDeposit(vault, assets, receiver, minSharesOut);
    }

    function test_safeDeposit_InvalidVault() public {
        uint256 assets = 100e18;
        uint256 minSharesOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(0)));

        helper.safeDeposit(IERC4626(address(0)), assets, receiver, minSharesOut);
    }

    function test_safeDeposit_VaultReverts() public {
        uint256 assets = 100e18;
        uint256 minSharesOut = 50e18;

        vault.setShouldRevert(true, "Vault error");

        vm.expectRevert("Vault error");
        helper.safeDeposit(vault, assets, receiver, minSharesOut);
    }

    // ============ safeMint Tests ============

    function test_safeMint_Success() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewMint(shares);
        uint256 maxAssetsIn = expectedAssets * (100 + SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(helper), receiver, expectedAssets, shares);

        uint256 assets = helper.safeMint(vault, shares, receiver, maxAssetsIn);

        assertEq(assets, expectedAssets);
        assertEq(vault.balanceOf(receiver), shares);
        assertLe(assets, maxAssetsIn);
    }

    function test_safeMint_SlippageExceeded() public {
        uint256 shares = 100e18;
        uint256 expectedAssets = vault.previewMint(shares);
        uint256 maxAssetsIn = expectedAssets - 1; // Set lower than expected

        vm.expectRevert(
            abi.encodeWithSelector(
                Safe4626Helper.SlippageExceeded.selector,
                maxAssetsIn, // expected
                expectedAssets, // actual
                maxAssetsIn // minRequired
            )
        );

        helper.safeMint(vault, shares, receiver, maxAssetsIn);
    }

    function test_safeMint_InvalidVault() public {
        uint256 shares = 100e18;
        uint256 maxAssetsIn = 100e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(0)));

        helper.safeMint(IERC4626(address(0)), shares, receiver, maxAssetsIn);
    }

    function test_safeMint_VaultReverts() public {
        uint256 shares = 100e18;
        uint256 maxAssetsIn = 100e18;

        vault.setShouldRevert(true, "Vault error");

        vm.expectRevert("Vault error");
        helper.safeMint(vault, shares, receiver, maxAssetsIn);
    }

    // ============ safeWithdraw Tests ============

    function test_safeWithdraw_Success() public {
        // First deposit some assets to have shares to withdraw
        uint256 depositAssets = 100e18;
        uint256 depositShares = vault.deposit(depositAssets, owner);

        uint256 withdrawAssets = 50e18;
        uint256 expectedShares = vault.previewWithdraw(withdrawAssets);
        uint256 maxSharesOut = expectedShares * (100 + SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(helper), receiver, owner, withdrawAssets, expectedShares);

        uint256 shares = helper.safeWithdraw(vault, withdrawAssets, receiver, owner, maxSharesOut);

        assertEq(shares, expectedShares);
        assertEq(vault.balanceOf(owner), depositShares - expectedShares);
        assertLe(shares, maxSharesOut);
    }

    function test_safeWithdraw_SlippageExceeded() public {
        // First deposit some assets
        uint256 depositAssets = 100e18;
        vault.deposit(depositAssets, owner);

        uint256 withdrawAssets = 50e18;
        uint256 expectedShares = vault.previewWithdraw(withdrawAssets);
        uint256 maxSharesOut = expectedShares - 1; // Set lower than expected

        vm.expectRevert(
            abi.encodeWithSelector(
                Safe4626Helper.SlippageExceeded.selector,
                maxSharesOut, // expected
                expectedShares, // actual
                maxSharesOut // minRequired
            )
        );

        helper.safeWithdraw(vault, withdrawAssets, receiver, owner, maxSharesOut);
    }

    function test_safeWithdraw_InvalidVault() public {
        uint256 withdrawAssets = 50e18;
        uint256 maxSharesOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(0)));

        helper.safeWithdraw(IERC4626(address(0)), withdrawAssets, receiver, owner, maxSharesOut);
    }

    function test_safeWithdraw_VaultReverts() public {
        uint256 withdrawAssets = 50e18;
        uint256 maxSharesOut = 50e18;

        vault.setShouldRevert(true, "Vault error");

        vm.expectRevert("Vault error");
        helper.safeWithdraw(vault, withdrawAssets, receiver, owner, maxSharesOut);
    }

    // ============ safeRedeem Tests ============

    function test_safeRedeem_Success() public {
        // First deposit some assets to have shares to redeem
        uint256 depositAssets = 100e18;
        uint256 depositShares = vault.deposit(depositAssets, owner);

        uint256 redeemShares = 50e18;
        uint256 expectedAssets = vault.previewRedeem(redeemShares);
        uint256 minAssetsOut = expectedAssets * (100 - SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(helper), receiver, owner, expectedAssets, redeemShares);

        uint256 assets = helper.safeRedeem(vault, redeemShares, receiver, owner, minAssetsOut);

        assertEq(assets, expectedAssets);
        assertEq(vault.balanceOf(owner), depositShares - redeemShares);
        assertGe(assets, minAssetsOut);
    }

    function test_safeRedeem_SlippageExceeded() public {
        // First deposit some assets
        uint256 depositAssets = 100e18;
        vault.deposit(depositAssets, owner);

        uint256 redeemShares = 50e18;
        uint256 expectedAssets = vault.previewRedeem(redeemShares);
        uint256 minAssetsOut = expectedAssets + 1; // Set higher than expected

        // Expect the function to revert due to slippage
        vm.expectRevert();
        helper.safeRedeem(vault, redeemShares, receiver, owner, minAssetsOut);
    }

    function test_safeRedeem_InvalidVault() public {
        uint256 redeemShares = 50e18;
        uint256 minAssetsOut = 50e18;

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(0)));

        helper.safeRedeem(IERC4626(address(0)), redeemShares, receiver, owner, minAssetsOut);
    }

    function test_safeRedeem_VaultReverts() public {
        uint256 redeemShares = 50e18;
        uint256 minAssetsOut = 50e18;

        vault.setShouldRevert(true, "Vault error");

        vm.expectRevert("Vault error");
        helper.safeRedeem(vault, redeemShares, receiver, owner, minAssetsOut);
    }

    // ============ Edge Cases ============

    function test_safeDeposit_ZeroAmount() public {
        uint256 assets = 0;
        uint256 minSharesOut = 0;

        uint256 shares = helper.safeDeposit(vault, assets, receiver, minSharesOut);
        assertEq(shares, 0);
        assertEq(vault.balanceOf(receiver), 0);
    }

    function test_safeMint_ZeroAmount() public {
        uint256 shares = 0;
        uint256 maxAssetsIn = 0;

        uint256 assets = helper.safeMint(vault, shares, receiver, maxAssetsIn);
        assertEq(assets, 0);
        assertEq(vault.balanceOf(receiver), 0);
    }

    function test_safeWithdraw_ZeroAmount() public {
        // First deposit some assets
        vault.deposit(100e18, owner);

        uint256 withdrawAssets = 0;
        uint256 maxSharesOut = 0;

        uint256 shares = helper.safeWithdraw(vault, withdrawAssets, receiver, owner, maxSharesOut);
        assertEq(shares, 0);
    }

    function test_safeRedeem_ZeroAmount() public {
        // First deposit some assets
        vault.deposit(100e18, owner);

        uint256 redeemShares = 0;
        uint256 minAssetsOut = 0;

        uint256 assets = helper.safeRedeem(vault, redeemShares, receiver, owner, minAssetsOut);
        assertEq(assets, 0);
    }

    function test_safeDeposit_ExchangeRateChange() public {
        // Set exchange rate to 2:1 (2 assets = 1 share)
        vault.setExchangeRate(2e18);

        uint256 assets = 100e18;
        uint256 expectedShares = 50e18; // 100 / 2
        uint256 minSharesOut = expectedShares * 95 / 100;

        uint256 shares = helper.safeDeposit(vault, assets, receiver, minSharesOut);
        assertEq(shares, expectedShares);
    }

    function test_safeMint_ExchangeRateChange() public {
        // Set exchange rate to 2:1 (2 assets = 1 share)
        vault.setExchangeRate(2e18);

        uint256 shares = 50e18;
        uint256 expectedAssets = 100e18; // 50 * 2
        uint256 maxAssetsIn = expectedAssets * 105 / 100;

        uint256 assets = helper.safeMint(vault, shares, receiver, maxAssetsIn);
        assertEq(assets, expectedAssets);
    }
}
