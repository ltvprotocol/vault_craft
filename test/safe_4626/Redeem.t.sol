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

        // User deposits to get shares for redeem tests
        vm.startPrank(user);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(500 ether, user);
        vm.stopPrank();
    }

    // vault == 0
    function test_safeRedeem_RevertWhen_VaultIsZero() public {
        uint256 shares = 100 ether;
        uint256 minAssetsOut = 0;

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.InvalidVault.selector, address(0)));

        vm.prank(user);
        helper.safeRedeem(IERC4626(address(0)), shares, receiver, minAssetsOut);
    }

    // vault redeem reverts (insufficient shares)
    function test_safeRedeem_RevertWhen_InsufficientShares() public {
        uint256 shares = type(uint256).max;
        uint256 minAssetsOut = 0;

        // User tries to redeem more shares than they have
        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        vm.expectRevert(); // Vault will revert due to insufficient shares
        helper.safeRedeem(vault, shares, receiver, minAssetsOut);
        vm.stopPrank();
    }

    // no approve for vault
    function test_safeRedeem_RevertWhen_InsufficientAllowance() public {
        uint256 shares = 100 ether;
        uint256 minAssetsOut = 0;

        // User has shares but hasn't approved the helper
        vm.startPrank(user);
        vault.approve(address(helper), 0); // No allowance

        vm.expectRevert(); // Vault will revert due to insufficient allowance
        helper.safeRedeem(vault, shares, receiver, minAssetsOut);
        vm.stopPrank();
    }

    // vault assets > minAssetsOut
    function test_safeRedeem_Success_WhenAssetsExceedMinimum() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewRedeem(shares); // e.g., 100 ether
        uint256 minAssetsOut = 50 ether; // Less than expected

        uint256 userSharesBefore = vault.balanceOf(user);
        uint256 receiverAssetsBefore = asset.balanceOf(receiver);

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        uint256 assets = helper.safeRedeem(vault, shares, receiver, minAssetsOut);

        vm.stopPrank();

        assertEq(assets, expectedAssets, "Assets should match preview");
        assertGt(assets, minAssetsOut, "Assets should exceed minimum");
        assertEq(vault.balanceOf(user), userSharesBefore - shares, "User shares should decrease");
        assertEq(asset.balanceOf(receiver), receiverAssetsBefore + assets, "Receiver assets should increase");
    }

    // vault assets < minAssetsOut
    function test_safeRedeem_RevertWhen_AssetsBelowMinimum() public {
        uint256 shares = 100 ether;
        uint256 expectedAssetsNoSlippage = vault.previewRedeem(shares); // 100 ether
        uint256 minAssetsOut = expectedAssetsNoSlippage + 1; // More than expected

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(Safe4626Helper.SlippageExceeded.selector, expectedAssetsNoSlippage));
        helper.safeRedeem(vault, shares, receiver, minAssetsOut);
        vm.stopPrank();
    }

    // vault assets == minAssetsOut
    function test_safeRedeem_Success_WhenAssetsEqualMinimum() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewRedeem(shares); // e.g., 100 ether
        uint256 minAssetsOut = expectedAssets; // Exactly equal

        uint256 userSharesBefore = vault.balanceOf(user);
        uint256 receiverAssetsBefore = asset.balanceOf(receiver);

        vm.startPrank(user);
        vault.approve(address(helper), type(uint256).max);

        uint256 assets = helper.safeRedeem(vault, shares, receiver, minAssetsOut);

        vm.stopPrank();

        assertEq(assets, expectedAssets, "Assets should match preview");
        assertEq(assets, minAssetsOut, "Assets should equal minimum");
        assertEq(vault.balanceOf(user), userSharesBefore - shares, "User shares should decrease");
        assertEq(asset.balanceOf(receiver), receiverAssetsBefore + assets, "Receiver assets should increase");
    }
}
