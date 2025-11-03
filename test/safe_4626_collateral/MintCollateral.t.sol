// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Safe4626CollateralHelper} from "src/Safe4626CollateralHelper.sol";
import {IERC4626Collateral} from "src/interfaces/IERC4626Collateral.sol";
import {MockERC4626CollateralVault} from "test/mocks/MockERC4626CollateralVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

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
        
        // Give user some tokens
        deal(address(asset), user, 1000 ether);
    }

    // vault == 0
    function test_safeMintCollateral_RevertWhen_VaultIsZero() public {
        uint256 shares = 100 ether;
        uint256 maxAssetsIn = type(uint256).max;

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626CollateralHelper.InvalidVault.selector,
            address(0)
        ));

        vm.prank(user);
        helper.safeMintCollateral(IERC4626Collateral(address(0)), shares, receiver, maxAssetsIn);
    }

    // safeTransferFrom - no money (insufficient balance)
    function test_safeMintCollateral_RevertWhen_InsufficientBalance() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMintCollateral(shares);  // e.g., 100 ether
        uint256 maxAssetsIn = type(uint256).max;

        // User has less than expected assets
        deal(address(asset), user, 10 ether);  // Less than expectedAssets

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);  // Approve enough

        vm.expectRevert();  // SafeERC20 transfer will revert
        helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // safeTransferFrom - insufficient allowance
    function test_safeMintCollateral_RevertWhen_InsufficientAllowance() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMintCollateral(shares);  // e.g., 100 ether
        uint256 maxAssetsIn = type(uint256).max;

        deal(address(asset), user, 1000 ether);  // Has enough balance

        vm.startPrank(user);
        asset.approve(address(helper), 50 ether);  // But approved less than needed

        vm.expectRevert();  // SafeERC20 transfer will revert
        helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // vault no asset
    function test_safeMintCollateral_RevertWhen_VaultHasNoAsset() public {
        uint256 shares = 100 ether;
        uint256 maxAssetsIn = type(uint256).max;

        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        MockERC4626CollateralVault emptyVault = MockERC4626CollateralVault(address(asset));

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626CollateralHelper.InvalidVault.selector,
            address(emptyVault)
        ));
        helper.safeMintCollateral(IERC4626Collateral(address(emptyVault)), shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // vault mint no money
    function test_safeMintCollateral_RevertWhen_VaultMintReverts() public {
        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        uint256 userBalance = asset.balanceOf(user);
        vm.expectRevert(abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector,
            user,
            userBalance,
            type(uint256).max
        ));
        helper.safeMintCollateral(vault, type(uint256).max, receiver, type(uint256).max);
        vm.stopPrank();
    }

    // vault assets < maxAssetsIn
    function test_safeMintCollateral_Success_WhenAssetsBelowMaximum() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMintCollateral(shares);  // e.g., 100 ether
        uint256 maxAssetsIn = 150 ether;  // More than expected

        uint256 userBalanceBefore = asset.balanceOf(user);

        vm.startPrank(user);
        asset.approve(address(helper), expectedAssets);

        uint256 assets = helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);

        vm.stopPrank();

        assertEq(assets, expectedAssets, "Assets should match preview");
        assertLt(assets, maxAssetsIn, "Assets should be below maximum");
        assertEq(vault.balanceOf(receiver), shares, "Receiver should have shares");
        assertEq(asset.balanceOf(user), userBalanceBefore - assets, "User assets should decrease");
    }

    // vault assets > maxAssetsIn
    function test_safeMintCollateral_RevertWhen_AssetsAboveMaximum() public {
        uint256 shares = 100 ether;
        uint256 expectedAssetsNoSlippage = vault.previewMintCollateral(shares);  // 100 ether
        uint256 maxAssetsIn = expectedAssetsNoSlippage - 1;  // Less than expected

        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626CollateralHelper.SlippageExceeded.selector,
            expectedAssetsNoSlippage
        ));
        helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // vault assets == maxAssetsIn
    function test_safeMintCollateral_Success_WhenAssetsEqualMaximum() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMintCollateral(shares);  // e.g., 100 ether
        uint256 maxAssetsIn = expectedAssets;  // Exactly equal

        uint256 userBalanceBefore = asset.balanceOf(user);

        vm.startPrank(user);
        asset.approve(address(helper), expectedAssets);

        uint256 assets = helper.safeMintCollateral(vault, shares, receiver, maxAssetsIn);

        vm.stopPrank();

        assertEq(assets, expectedAssets, "Assets should match preview");
        assertEq(assets, maxAssetsIn, "Assets should equal maximum");
        assertEq(vault.balanceOf(receiver), shares, "Receiver should have shares");
        assertEq(asset.balanceOf(user), userBalanceBefore - assets, "User assets should decrease");
    }
}

