// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Token is ERC20 {
    using SafeERC20 for IERC20;

    address public pair;

    error Forbidden();

    constructor() ERC20("MO", "MO") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }

    function decimals() public view virtual override returns (uint8) {
        return 4;
    }

    function setPair(address _pair) public {
        if (pair != address(0)) revert Forbidden();
        pair = _pair;
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        _updateReward(from);
        _updateReward(to);
        super._update(from, to, value);
    }

    address public vault;
    address public burn = 0x000000000000000000000000000000000000dEaD;

    address public rewardsToken;
    address public rewardsDistribution;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event RewardPaid(address indexed user, uint256 reward);

    function setVault(address _vault) public {
        if (vault != address(0)) revert Forbidden();
        vault = _vault;
    }

    function setRewardsToken(address _rewardsToken) public {
        if (vault != address(0)) revert Forbidden();
        rewardsToken = _rewardsToken;
    }

    function setRewardsDistribution(address _rewardsDistribution) public {
        if (vault != address(0)) revert Forbidden();
        rewardsDistribution = _rewardsDistribution;
    }

    function earned(address user) public view returns (uint256) {
        return rewards[user] + (balanceOf(user) * (rewardPerTokenStored - userRewardPerTokenPaid[user])) / 1e18;
    }

    function getReward() public {
        _updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            IERC20(rewardsToken).safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward) public {
        if (msg.sender != rewardsDistribution) revert Forbidden();

        uint256 amount = totalSupply() - balanceOf(vault) - balanceOf(pair) - balanceOf(burn);
        if (amount == 0) {
            return;
        }

        rewardPerTokenStored += (reward * 1e18) / amount;
        emit RewardAdded(reward);
    }

    function _updateReward(address user) private {
        if (rewardPerTokenStored == 0) {
            return;
        }
        rewards[user] = earned(user);
        userRewardPerTokenPaid[user] = rewardPerTokenStored;
    }
}
