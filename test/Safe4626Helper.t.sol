// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Safe4626Helper} from "../src/Safe4626Helper.sol";
import {MockERC4626Vault} from "./mocks/MockERC4626Vault.sol";
import {IERC4626} from "../src/interfaces/IERC4626.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Safe4626HelperTest is Test {
    Safe4626Helper public helper;
    MockERC4626Vault public vault;
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
        helper = new Safe4626Helper();

        // Deploy mock asset token
        mockAsset = new ERC20Mock();
        vault = new MockERC4626Vault(address(mockAsset));

        // Give user some initial balance
        uint256 amount = 10000 ether;
        vm.deal(user, amount);
        deal(address(mockAsset), user, amount);
        vault.mintFreeTokens(user, amount);
        deal(address(mockAsset), address(vault), amount);
        vm.startPrank(user);
        mockAsset.approve(address(helper), amount);
        mockAsset.approve(address(vault), amount);
        vault.approve(address(helper), amount);
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
        mockAsset.approve(address(helper), 0);

        vm.expectRevert();
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
                expectedAssets // actual
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
        mockAsset.approve(address(helper), 0);

        vm.expectRevert();
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
                expectedShares // actual
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

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(vault)));
        helper.safeWithdraw(vault, withdrawAssets, receiver, owner, maxSharesOut);
    }

    // ============ safeRedeem Tests ============

    function test_safeRedeem_Success() public {
        uint256 redeemShares = 50e18;
        uint256 expectedAssets = vault.previewRedeem(redeemShares);
        uint256 minAssetsOut = expectedAssets * (100 - SLIPPAGE_TOLERANCE) / 100;

        vm.expectEmit(true, true, true, true);
        emit Withdraw(address(helper), receiver, user, expectedAssets, redeemShares);

        uint256 assets = helper.safeRedeem(vault, redeemShares, receiver, user, minAssetsOut);

        assertEq(assets, expectedAssets);
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

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(vault)));
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
}
