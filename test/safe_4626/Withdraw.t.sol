// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Safe4626Helper} from "src/Safe4626Helper.sol";
import {IERC4626} from "src/interfaces/IERC4626.sol";
import {MockERC4626Vault} from "test/mocks/MockERC4626Vault.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

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

        // Give user some tokens and deposit to get shares
        deal(address(asset), user, 1000 ether);

        // User deposits to get shares for withdraw tests
        vm.startPrank(user);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(500 ether, user);
        vm.stopPrank();
    }

    // vault == 0
    function test_safeWithdraw_RevertWhen_VaultIsZero() public {
        uint256 assets = 100 ether;
        uint256 maxSharesOut = type(uint256).max;

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(0)));

        vm.prank(user);
        helper.safeWithdraw(IERC4626(address(0)), assets, receiver, maxSharesOut);
    }

    // vault withdraw reverts (insufficient shares)
    function test_safeWithdraw_RevertWhen_InsufficientShares() public {
        uint256 assets = type(uint256).max;
        uint256 maxSharesOut = type(uint256).max;

        // User tries to withdraw more than they have
        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        vm.expectRevert(); // Vault will revert due to insufficient shares
        helper.safeWithdraw(vault, assets, receiver, maxSharesOut);
        vm.stopPrank();
    }

    // no approve for vault
    function test_safeWithdraw_RevertWhen_InsufficientAllowance() public {
        uint256 assets = 100 ether;
        uint256 maxSharesOut = type(uint256).max;

        // User has shares but hasn't approved the helper
        vm.startPrank(user);
        vault.approve(address(helper), 0); // No allowance

        vm.expectRevert(); // Vault will revert due to insufficient allowance
        helper.safeWithdraw(vault, assets, receiver, maxSharesOut);
        vm.stopPrank();
    }

    // vault shares < maxSharesOut
    function test_safeWithdraw_Success_WhenSharesBelowMaximum() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewWithdraw(assets); // e.g., 100 ether
        uint256 maxSharesOut = 150 ether; // More than expected

        uint256 userSharesBefore = vault.balanceOf(user);
        uint256 receiverAssetsBefore = asset.balanceOf(receiver);

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        uint256 shares = helper.safeWithdraw(vault, assets, receiver, maxSharesOut);

        vm.stopPrank();

        assertEq(shares, expectedShares, "Shares should match preview");
        assertLt(shares, maxSharesOut, "Shares should be below maximum");
        assertEq(vault.balanceOf(user), userSharesBefore - shares, "User shares should decrease");
        assertEq(asset.balanceOf(receiver), receiverAssetsBefore + assets, "Receiver assets should increase");
    }

    // vault shares > maxSharesOut
    function test_safeWithdraw_RevertWhen_SharesAboveMaximum() public {
        uint256 assets = 100 ether;
        uint256 expectedSharesNoSlippage = vault.previewWithdraw(assets); // 100 ether
        uint256 maxSharesOut = expectedSharesNoSlippage - 1; // Less than expected

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.SlippageExceeded.selector, expectedSharesNoSlippage));
        helper.safeWithdraw(vault, assets, receiver, maxSharesOut);
        vm.stopPrank();
    }

    // vault shares == maxSharesOut
    function test_safeWithdraw_Success_WhenSharesEqualMaximum() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewWithdraw(assets); // e.g., 100 ether
        uint256 maxSharesOut = expectedShares; // Exactly equal

        uint256 userSharesBefore = vault.balanceOf(user);
        uint256 receiverAssetsBefore = asset.balanceOf(receiver);

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        uint256 shares = helper.safeWithdraw(vault, assets, receiver, maxSharesOut);

        vm.stopPrank();

        assertEq(shares, expectedShares, "Shares should match preview");
        assertEq(shares, maxSharesOut, "Shares should equal maximum");
        assertEq(vault.balanceOf(user), userSharesBefore - shares, "User shares should decrease");
        assertEq(asset.balanceOf(receiver), receiverAssetsBefore + assets, "Receiver assets should increase");
    }
}
