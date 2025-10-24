// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILowLevelVault} from "src/interfaces/ILowLevelVault.sol";

contract MockLowLevelVault is ILowLevelVault {
    IERC20 immutable collateralToken;
    IERC20 immutable borrowToken;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public constant name = "Mock LTV Vault";
    string public constant symbol = "mLTV";
    uint8 public constant decimals = 18;

    uint256 constant TARGET_LTV_DIVIDEND = 3;
    uint256 constant TARGET_LTV_DIVIDER = 4;
    uint256 constant SHARES_MINTED_FOR_COLLATERAL = 10;

    constructor(address _collateralToken, address _borrowToken) {
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
    }

    function previewLowLevelRebalanceShares(int256 deltaShares)
        public
        view
        returns (int256 deltaCollateral, int256 deltaBorrow)
    {
        if (deltaShares < 0) {
            return (0, 0);
        }

        deltaCollateral = int256((uint256(deltaShares) * TARGET_LTV_DIVIDER) / SHARES_MINTED_FOR_COLLATERAL);
        uint256 deltaBorrowInCollateral = (uint256(deltaCollateral) * TARGET_LTV_DIVIDEND) / TARGET_LTV_DIVIDER;

        deltaBorrow = getDeltaBorrow(deltaBorrowInCollateral);
    }

    function getDeltaBorrow(uint256 _deltaBorrowInCollateral) internal view virtual returns (int256) {
        return int256(_deltaBorrowInCollateral);
    }

    function executeLowLevelRebalanceShares(int256 deltaShares)
        external
        returns (int256 deltaCollateral, int256 deltaBorrow)
    {
        if (deltaShares < 0) {
            return (0, 0);
        }

        (deltaCollateral, deltaBorrow) = previewLowLevelRebalanceShares(deltaShares);

        require(deltaCollateral > 0 && deltaBorrow > 0, "No rebalance available now!");

        collateralToken.transferFrom(msg.sender, address(this), uint256(deltaCollateral));
        _mint(msg.sender, uint256(deltaShares));
        borrowToken.transfer(msg.sender, uint256(deltaBorrow));
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
}
