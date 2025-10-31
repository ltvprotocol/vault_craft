// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Safe4626Helper} from "src/Safe4626Helper.sol";
import {IERC4626} from "src/interfaces/IERC4626.sol";
import {MockERC4626Vault} from "test/mocks/MockERC4626Vault.sol";
import {MockNoVault} from "test/mocks/MockNoVault.sol";
import {MockVaultDepositReverts} from "test/mocks/MockVaultDepositReverts.sol";
import {MockVaultWithSlippage} from "test/mocks/MockVaultWithSlippage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Safe4626HelperTest is Test {
    Safe4626Helper public helper;
    MockERC4626Vault public vault;
    ERC20Mock public asset;
    address public user;
    address public receiver;

    // Mock vaults for edge cases
    MockNoVault public vaultNoVault;
    MockVaultDepositReverts public vaultDepositReverts;
    MockVaultWithSlippage public vaultWithSlippage;

    function setUp() public {
        helper = new Safe4626Helper();
        asset = new ERC20Mock();
        vault = new MockERC4626Vault(address(asset));
        
        user = makeAddr("user");
        receiver = makeAddr("receiver");
        
        // Give user some tokens
        deal(address(asset), user, 1000 ether);
        
        // Deploy edge case vaults
        vaultNoVault = new MockNoVault();
        vaultDepositReverts = new MockVaultDepositReverts(address(asset));
        vaultWithSlippage = new MockVaultWithSlippage(address(asset));
    }

    // vault == 0
    function test_safeDeposit_RevertWhen_VaultIsZero() public {
        uint256 assets = 100 ether;
        uint256 minSharesOut = 0;

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626Helper.InvalidVault.selector,
            address(0)
        ));

        vm.prank(user);
        helper.safeDeposit(IERC4626(address(0)), assets, receiver, minSharesOut);
    }

    // safeTransferFrom - no money (insufficient balance)
    function test_safeDeposit_RevertWhen_InsufficientBalance() public {
        uint256 assets = 100 ether;
        uint256 minSharesOut = 0;

        // User has less than assets
        deal(address(asset), user, 10 ether);  // Less than 100 ether

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);  // Approve enough

        vm.expectRevert();  // SafeERC20 transfer will revert
        helper.safeDeposit(vault, assets, receiver, minSharesOut);
        vm.stopPrank();
    }

    // safeTransferFrom - insufficient allowance
    function test_safeDeposit_RevertWhen_InsufficientAllowance() public {
        uint256 assets = 100 ether;
        uint256 minSharesOut = 0;

        deal(address(asset), user, 1000 ether);  // Has enough balance

        vm.startPrank(user);
        asset.approve(address(helper), 50 ether);  // But approved less than needed

        vm.expectRevert();  // SafeERC20 transfer will revert
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

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626Helper.InvalidVault.selector,
            address(vaultNoVault)
        ));
        helper.safeDeposit(IERC4626(address(vaultNoVault)), assets, receiver, minSharesOut);
        vm.stopPrank();
    }

    // vault deposit no money
    function test_safeDeposit_RevertWhen_VaultDepositReverts() public {
        uint256 assets = 100 ether;
        uint256 minSharesOut = 0;

        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        vm.expectRevert("Deposit failed");
        helper.safeDeposit(vaultDepositReverts, assets, receiver, minSharesOut);
        vm.stopPrank();
    }

    // vault shares > minSharesOut
    function test_safeDeposit_Success_WhenSharesExceedMinimum() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewDeposit(assets);  // e.g., 100 ether
        uint256 minSharesOut = 50 ether;  // Less than expected

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
        uint256 expectedSharesNoSlippage = vaultWithSlippage.previewDeposit(assets);  // 100 ether
        uint256 actualShares = expectedSharesNoSlippage * 90 / 100;  // 90 ether with 10% slippage
        uint256 minSharesOut = 95 ether;  // More than actual shares

        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), assets);

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626Helper.SlippageExceeded.selector,
            actualShares
        ));
        helper.safeDeposit(vaultWithSlippage, assets, receiver, minSharesOut);
        vm.stopPrank();
    }

    // vault shares == minSharesOut
    function test_safeDeposit_Success_WhenSharesEqualMinimum() public {
        uint256 assets = 100 ether;
        uint256 expectedShares = vault.previewDeposit(assets);  // 100 ether
        uint256 minSharesOut = expectedShares;  // Exactly equal

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