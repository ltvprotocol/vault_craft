// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Safe4626Helper} from "src/Safe4626Helper.sol";
import {IERC4626} from "src/interfaces/IERC4626.sol";
import {MockERC4626Vault} from "test/mocks/MockERC4626Vault.sol";
import {MockNoVault} from "test/mocks/MockNoVault.sol";
import {MockVaultMintReverts} from "test/mocks/MockVaultMintReverts.sol";
import {MockVaultMintSlippage} from "test/mocks/MockVaultMintSlippage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Safe4626HelperMintTest is Test {
    Safe4626Helper public helper;
    MockERC4626Vault public vault;
    ERC20Mock public asset;
    address public user;
    address public receiver;

    // Mock vaults for edge cases
    MockNoVault public vaultNoVault;
    MockVaultMintReverts public vaultMintReverts;
    MockVaultMintSlippage public vaultMintSlippage;

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
        vaultMintReverts = new MockVaultMintReverts(address(asset));
        vaultMintSlippage = new MockVaultMintSlippage(address(asset));
    }

    // vault == 0
    function test_safeMint_RevertWhen_VaultIsZero() public {
        uint256 shares = 100 ether;
        uint256 maxAssetsIn = type(uint256).max;

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626Helper.InvalidVault.selector,
            address(0)
        ));

        vm.prank(user);
        helper.safeMint(IERC4626(address(0)), shares, receiver, maxAssetsIn);
    }

    // safeTransferFrom - no money (insufficient balance)
    function test_safeMint_RevertWhen_InsufficientBalance() public {
        uint256 shares = 100 ether;
        uint256 maxAssetsIn = type(uint256).max;

        // User has less than expected assets (vault is empty, so 1:1 ratio, needs 100 ether)
        deal(address(asset), user, 10 ether);  // Less than needed

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);  // Approve enough

        vm.expectRevert();  // SafeERC20 transfer will revert
        helper.safeMint(vault, shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // safeTransferFrom - insufficient allowance
    function test_safeMint_RevertWhen_InsufficientAllowance() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMint(shares);  // e.g., 100 ether (1:1 when empty)
        uint256 maxAssetsIn = type(uint256).max;

        deal(address(asset), user, 1000 ether);  // Has enough balance

        vm.startPrank(user);
        asset.approve(address(helper), 50 ether);  // But approved less than needed (50 < 100)

        vm.expectRevert();  // SafeERC20 transfer will revert
        helper.safeMint(vault, shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // vault no asset
    function test_safeMint_RevertWhen_VaultHasNoAsset() public {
        uint256 shares = 100 ether;
        uint256 maxAssetsIn = type(uint256).max;

        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626Helper.InvalidVault.selector,
            address(vaultNoVault)
        ));
        helper.safeMint(IERC4626(address(vaultNoVault)), shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // vault mint no money
    function test_safeMint_RevertWhen_VaultMintReverts() public {
        uint256 shares = 100 ether;
        uint256 maxAssetsIn = type(uint256).max;

        deal(address(asset), user, 1000 ether);

        vm.startPrank(user);
        asset.approve(address(helper), type(uint256).max);

        vm.expectRevert("Mint failed");
        helper.safeMint(vaultMintReverts, shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // vault assets < maxAssetsIn
    function test_safeMint_Success_WhenAssetsBelowMaximum() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMint(shares);  // e.g., 100 ether
        uint256 maxAssetsIn = 150 ether;  // More than expected

        uint256 userBalanceBefore = asset.balanceOf(user);

        vm.startPrank(user);
        asset.approve(address(helper), expectedAssets);

        uint256 assets = helper.safeMint(vault, shares, receiver, maxAssetsIn);

        vm.stopPrank();

        assertEq(assets, expectedAssets, "Assets should match preview");
        assertLt(assets, maxAssetsIn, "Assets should be below maximum");
        assertEq(vault.balanceOf(receiver), shares, "Receiver should have shares");
        assertEq(asset.balanceOf(user), userBalanceBefore - assets, "User assets should decrease");
    }

    // vault assets > maxAssetsIn
    function test_safeMint_RevertWhen_AssetsAboveMaximum() public {
        uint256 shares = 100 ether;
        uint256 previewAssets = vaultMintSlippage.previewMint(shares);  // e.g., 100 ether (no slippage in preview)
        // With slippage, mint() will require more assets than previewMint suggests
        // If preview shows 100, but mint() needs 110 due to slippage (10% more)
        uint256 actualAssets = previewAssets * 110 / 100;  // 110 ether with 10% slippage
        uint256 maxAssetsIn = 105 ether;  // Less than actual assets (105 < 110)

        deal(address(asset), user, 1000 ether);

        deal(address(asset), address(helper), actualAssets - previewAssets);

        vm.startPrank(address(helper));
        asset.approve(address(vaultMintSlippage), actualAssets*10);
        vm.stopPrank();

        vm.startPrank(user);
        // Approve enough for safeMint to transfer previewAssets
        asset.approve(address(helper), actualAssets*10);

        vm.expectRevert(abi.encodeWithSelector(
            Safe4626Helper.SlippageExceeded.selector,
            actualAssets
        ));
        helper.safeMint(vaultMintSlippage, shares, receiver, maxAssetsIn);
        vm.stopPrank();
    }

    // vault assets == maxAssetsIn
    function test_safeMint_Success_WhenAssetsEqualMaximum() public {
        uint256 shares = 100 ether;
        uint256 expectedAssets = vault.previewMint(shares);  // e.g., 100 ether
        uint256 maxAssetsIn = expectedAssets;  // Exactly equal

        uint256 userBalanceBefore = asset.balanceOf(user);

        vm.startPrank(user);
        asset.approve(address(helper), expectedAssets);

        uint256 assets = helper.safeMint(vault, shares, receiver, maxAssetsIn);

        vm.stopPrank();

        assertEq(assets, expectedAssets, "Assets should match preview");
        assertEq(assets, maxAssetsIn, "Assets should equal maximum");
        assertEq(vault.balanceOf(receiver), shares, "Receiver should have shares");
        assertEq(asset.balanceOf(user), userBalanceBefore - assets, "User assets should decrease");
    }
}

