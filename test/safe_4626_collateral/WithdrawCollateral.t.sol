// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Safe4626CollateralHelper} from "src/Safe4626CollateralHelper.sol";
import {IERC4626Collateral} from "src/interfaces/IERC4626Collateral.sol";
import {MockERC4626CollateralVault} from "test/mocks/MockERC4626CollateralVault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Safe4626CollateralHelperTest is Test {
    Safe4626CollateralHelper public helper;
    MockERC4626CollateralVault public vault;
    ERC20Mock public asset;
    address public user;
    address public receiver;

    function setUp() public {
        helper = new Safe4626CollateralHelper();
        asset = new ERC20Mock();
        vault = new MockERC4626CollateralVault(address(asset));

        user = makeAddr("user");
        receiver = makeAddr("receiver");

        // Give user some tokens and deposit to get shares
        deal(address(asset), user, 1000 ether);

        // User deposits to get shares for withdraw tests
        vm.startPrank(user);
        asset.approve(address(vault), type(uint256).max);
        vault.depositCollateral(500 ether, user);
        vm.stopPrank();
    }

    // vault == 0
    function test_safeWithdrawCollateral_RevertWhen_VaultIsZero() public {
        uint256 assets = 100 ether;
        uint256 maxSharesIn = type(uint256).max;

        vm.expectRevert(abi.encodeWithSelector(Safe4626CollateralHelper.InvalidVault.selector, address(0)));

        vm.prank(user);
        helper.safeWithdrawCollateral(IERC4626Collateral(address(0)), assets, receiver, maxSharesIn);
    }

    // vault withdraw reverts (insufficient shares)
    function test_safeWithdrawCollateral_RevertWhen_InsufficientShares() public {
        uint256 assets = type(uint256).max;
        uint256 maxSharesIn = type(uint256).max;

        // User tries to withdraw more than they have
        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        vm.expectRevert(); // Vault will revert due to insufficient shares
        helper.safeWithdrawCollateral(vault, assets, receiver, maxSharesIn);
        vm.stopPrank();
    }

    // no approve for vault
    function test_safeWithdrawCollateral_RevertWhen_InsufficientAllowance() public {
        uint256 assets = 100 ether;
        uint256 maxSharesIn = type(uint256).max;

        // User has shares but hasn't approved the helper
        vm.startPrank(user);
        vault.approve(address(helper), 0); // No allowance

        vm.expectRevert(); // Vault will revert due to insufficient allowance
        helper.safeWithdrawCollateral(vault, assets, receiver, maxSharesIn);
        vm.stopPrank();
    }

    // vault shares < maxSharesIn
    function test_safeWithdrawCollateral_Success_WhenSharesBelowMaximum() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewWithdrawCollateral(assets); // e.g., 100 ether
        uint256 maxSharesIn = 150 ether; // More than expected

        uint256 userSharesBefore = vault.balanceOf(user);
        uint256 receiverAssetsBefore = asset.balanceOf(receiver);

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        uint256 shares = helper.safeWithdrawCollateral(vault, assets, receiver, maxSharesIn);

        vm.stopPrank();

        assertEq(shares, expectedShares, "Shares should match preview");
        assertLt(shares, maxSharesIn, "Shares should be below maximum");
        assertEq(vault.balanceOf(user), userSharesBefore - shares, "User shares should decrease");
        assertEq(asset.balanceOf(receiver), receiverAssetsBefore + assets, "Receiver assets should increase");
    }

    // vault shares > maxSharesIn
    function test_safeWithdrawCollateral_RevertWhen_SharesAboveMaximum() public {
        uint256 assets = 100 ether;
        uint256 expectedSharesNoSlippage = vault.previewWithdrawCollateral(assets); // 100 ether
        uint256 maxSharesIn = expectedSharesNoSlippage - 1; // Less than expected

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(Safe4626CollateralHelper.SlippageExceeded.selector, expectedSharesNoSlippage)
        );
        helper.safeWithdrawCollateral(vault, assets, receiver, maxSharesIn);
        vm.stopPrank();
    }

    // vault shares == maxSharesIn
    function test_safeWithdrawCollateral_Success_WhenSharesEqualMaximum() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewWithdrawCollateral(assets); // e.g., 100 ether
        uint256 maxSharesIn = expectedShares; // Exactly equal

        uint256 userSharesBefore = vault.balanceOf(user);
        uint256 receiverAssetsBefore = asset.balanceOf(receiver);

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        uint256 shares = helper.safeWithdrawCollateral(vault, assets, receiver, maxSharesIn);

        vm.stopPrank();

        assertEq(shares, expectedShares, "Shares should match preview");
        assertEq(shares, maxSharesIn, "Shares should equal maximum");
        assertEq(vault.balanceOf(user), userSharesBefore - shares, "User shares should decrease");
        assertEq(asset.balanceOf(receiver), receiverAssetsBefore + assets, "Receiver assets should increase");
    }
}
