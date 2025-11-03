// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILowLevelVault} from "src/interfaces/ILowLevelVault.sol";
import {IstEth} from "src/interfaces/tokens/IstEth.sol";
import {IWhitelistRegistry} from "src/interfaces/IWhitelistRegistry.sol";

contract MockWhitelistRegistry is IWhitelistRegistry {
    function isAddressWhitelisted(address) external pure returns (bool) {
        return true;
    }
}

// forge-lint: disable-start
contract MockLowLevelVault is ILowLevelVault {
    IstEth constant STETH = IstEth(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

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

    IWhitelistRegistry public immutable _whitelistRegistry;

    constructor(address _collateralToken, address _borrowToken) {
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
        _whitelistRegistry = new MockWhitelistRegistry();
    }

    function previewLowLevelRebalanceShares(int256 deltaShares)
        public
        view
        returns (int256 deltaCollateral, int256 deltaBorrow)
    {
        if (deltaShares >= 0) {
            deltaCollateral = int256(STETH.getSharesByPooledEth(uint256(deltaShares * int256(TARGET_LTV_DIVIDER))));
        } else {
            deltaCollateral = -int256(STETH.getSharesByPooledEth(uint256(-deltaShares * int256(TARGET_LTV_DIVIDER))));
        }
        deltaBorrow = deltaShares * int256(TARGET_LTV_DIVIDEND);
    }

    function executeLowLevelRebalanceShares(int256 deltaShares)
        external
        returns (int256 deltaCollateral, int256 deltaBorrow)
    {
        (deltaCollateral, deltaBorrow) = previewLowLevelRebalanceShares(deltaShares);
        if (deltaShares >= 0) {
            collateralToken.transferFrom(msg.sender, address(this), uint256(deltaCollateral));
            _mint(msg.sender, uint256(deltaShares));
            borrowToken.transfer(msg.sender, uint256(deltaBorrow));
        } else {
            borrowToken.transferFrom(msg.sender, address(this), uint256(-deltaBorrow));
            _burn(msg.sender, uint256(-deltaShares));
            collateralToken.transfer(msg.sender, uint256(-deltaCollateral));
        }
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

    function _mint(address to, uint256 amount) public {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        totalSupply -= amount;
        balanceOf[from] -= amount;
        emit Transfer(from, address(0), amount);
    }

    function isWhitelistActivated() external pure returns (bool) {
        return true;
    }

    function whitelistRegistry() external view returns (address) {
        return address(_whitelistRegistry);
    }
}

// forge-lint: disable-end
