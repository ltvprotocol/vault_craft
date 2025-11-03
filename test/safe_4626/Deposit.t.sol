// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Safe4626Helper} from "src/Safe4626Helper.sol";
import {IERC4626} from "src/interfaces/IERC4626.sol";
import {MockERC4626Vault} from "test/mocks/MockERC4626Vault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract Safe4626HelperTest is Test {
    Safe4626Helper public helper;
    MockERC4626Vault public vault;
    ERC20Mock public asset;
    address public user;
    address public receiver;

    function setUp() public {
        helper = new Safe4626Helper();
        asset = new ERC20Mock();
        vault = new MockERC4626Vault(address(asset));

        user = makeAddr("user");
        receiver = makeAddr("receiver");

        // Give user some tokens
        deal(address(asset), user, 1000 ether);
    }

    // vault == 0
    function test_safeDeposit_RevertWhen_VaultIsZero() public {
        uint256 assets = 100 ether;
        uint256 minSharesOut = 0;

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(0)));

        vm.prank(user);
        helper.safeDeposit(IERC4626(address(0)), assets, receiver, minSharesOut);
    }

    // safeTransferFrom - no money (insufficient balance)
    function test_safeDeposit_RevertWhen_InsufficientBalance() public {
        uint256 assets = 100 ether;
        uint256 minSharesOut = 0;

        // User has less than assets
        deal(address(asset), user, 10 ether); // Less than 100 ether

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max); // Approve enough

        vm.expectRevert(); // SafeERC20 transfer will revert
        helper.safeDeposit(vault, assets, receiver, minSharesOut);
        vm.stopPrank();
    }

    // safeTransferFrom - insufficient allowance
    function test_safeDeposit_RevertWhen_InsufficientAllowance() public {
        uint256 assets = 100 ether;
        uint256 minSharesOut = 0;

        deal(address(asset), user, 1000 ether); // Has enough balance

        vm.startPrank(user);
        asset.approve(address(helper), 50 ether); // But approved less than needed

        vm.expectRevert(); // SafeERC20 transfer will revert
        helper.safeDeposit(vault, assets, receiver, minSharesOut);
        vm.stopPrank();
    }

    // vault no asset
    function test_safeDeposit_RevertWhen_VaultHasNoAsset() public {
        uint256 assets = 100 ether;
        uint256 minSharesOut = 0;

        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        MockERC4626Vault emptyVault = MockERC4626Vault(address(asset));

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(emptyVault)));
        helper.safeDeposit(IERC4626(address(emptyVault)), assets, receiver, minSharesOut);
        vm.stopPrank();
    }

    // vault deposit no money
    function test_safeDeposit_RevertWhen_VaultDepositReverts() public {
        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        uint256 userBalance = asset.balanceOf(user);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, userBalance, type(uint256).max)
        );
        helper.safeDeposit(vault, type(uint256).max, receiver, type(uint256).max);
        vm.stopPrank();
    }

    // vault shares > minSharesOut
    function test_safeDeposit_Success_WhenSharesExceedMinimum() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewDeposit(assets); // e.g., 100 ether
        uint256 minSharesOut = 50 ether; // Less than expected

        uint256 userBalanceBefore = asset.balanceOf(user);

        vm.startPrank(user);
        asset.approve(address(helper), assets);

        uint256 shares = helper.safeDeposit(vault, assets, receiver, minSharesOut);

        vm.stopPrank();

        assertEq(shares, expectedShares, "Shares should match preview");
        assertGt(shares, minSharesOut, "Shares should exceed minimum");
        assertEq(vault.balanceOf(receiver), expectedShares, "Receiver should have shares");
        assertEq(asset.balanceOf(user), userBalanceBefore - assets, "User assets should decrease");
    }

    // vault shares < minSharesOut
    function test_safeDeposit_RevertWhen_SharesBelowMinimum() public {
        uint256 assets = 100 ether;
        uint256 expectedSharesNoSlippage = vault.previewDeposit(assets); // 100 ether
        uint256 minSharesOut = expectedSharesNoSlippage + 1;

        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.SlippageExceeded.selector, expectedSharesNoSlippage));
        helper.safeDeposit(vault, assets, receiver, minSharesOut);
        vm.stopPrank();
    }

    // vault shares == minSharesOut
    function test_safeDeposit_Success_WhenSharesEqualMinimum() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewDeposit(assets); // 100 ether
        uint256 minSharesOut = expectedShares; // Exactly equal

        uint256 userBalanceBefore = asset.balanceOf(user);

        vm.startPrank(user);
        asset.approve(address(helper), assets);

        uint256 shares = helper.safeDeposit(vault, assets, receiver, minSharesOut);

        vm.stopPrank();

        assertEq(shares, expectedShares, "Shares should match preview");
        assertEq(shares, minSharesOut, "Shares should equal minimum");
        assertEq(vault.balanceOf(receiver), expectedShares, "Receiver should have shares");
        assertEq(asset.balanceOf(user), userBalanceBefore - assets, "User assets should decrease");
    }
}
