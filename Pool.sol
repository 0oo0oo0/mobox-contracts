// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/INode.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IToken.sol";

contract Pool {
    using SafeERC20 for IERC20;

    uint256 public constant BASE = 10000;
    address public recipient;
    address public usdt; // USDT
    address public token;
    address public relationship;
    address public node;
    address public vault;
    address public router;
    address public pair;
    uint256 public amountMin; // 100
    uint256 public amountMax; // 2000
    uint256 public rewardRate; // 1.4
    uint256 public rewardRatePreSecond; // 1e6 * 7000 / 10000 * 180 / 10000 / 1 days
    uint256 public depthMax;

    struct Order {
        uint256 amount; // USDT
        uint256 totalReward; // USDT
        uint256 createdTime;
        uint256 claimedTime;
        uint256 claimedReward; // USDT
        bool running;
    }

    mapping(address => Order) public orders;

    struct Config {
        uint256 performance; // 业绩
        uint256 rewardRate; // 收益率
    }

    mapping(uint256 => Config) public configs;
    mapping(address => uint256) public levels;
    mapping(address => uint256) public performances;

    event OrderCreated(address indexed user, uint256 amount);

    error InvalidAmount();
    error UserNotBinded();
    error HasUnfinishedOrder();
    error NoRewards();

    constructor(
        address _recipient,
        address _usdt,
        address _token,
        address _relationship,
        address _node,
        address _vault,
        address _router
    ) {
        recipient = _recipient;
        usdt = _usdt;
        token = _token;
        relationship = _relationship;
        node = _node;
        vault = _vault;
        router = _router;

        amountMin = 100 * 1e6;
        amountMax = 2000 * 1e6;
        amountMax = type(uint256).max;
        rewardRate = 14000;
        rewardRatePreSecond = (1e6 * 7000 * 180) / BASE / BASE / 1 days;
        depthMax = 15;

        configs[1] = Config(2 * 1e4 * 1e6, 1000);
        configs[2] = Config(10 * 1e4 * 1e6, 2000);
        configs[3] = Config(30 * 1e4 * 1e6, 3000);
        configs[4] = Config(60 * 1e4 * 1e6, 4000);
        configs[5] = Config(100 * 1e4 * 1e6, 5000);

        pair = IUniswapV2Factory(IUniswapV2Router(router).factory()).createPair(token, usdt, router);
    }

    function price() public view returns (uint256) {
        address token0 = IUniswapV2Pair(pair).token0();
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        if (token0 == token) {
            return (uint256(reserve1) * 1e4) / uint256(reserve0);
        } else {
            return (uint256(reserve0) * 1e4) / uint256(reserve1);
        }
    }

    function getLevel(address user) public view returns (uint256) {
        uint256 level = levels[user];
        if (INode(node).nodes(user) == true && level < 2) {
            level = 2;
        }
        return level;
    }

    function earned(address user) public view returns (uint256) {
        Order memory order = orders[user];
        uint256 time;
        if (order.claimedTime == 0) {
            time = block.timestamp - order.createdTime;
        } else {
            time = block.timestamp - order.claimedTime;
        }
        uint256 reward = (order.amount * rewardRatePreSecond * time) / 1e6;
        if (reward > order.totalReward - order.claimedReward) {
            reward = order.totalReward - order.claimedReward;
        }
        return reward;
    }

    function mint(uint256 amount) public {
        if (amount < amountMin || amount > amountMax) revert InvalidAmount();
        if (orders[msg.sender].running == true) revert HasUnfinishedOrder();

        IERC20(usdt).safeTransferFrom(msg.sender, address(this), amount);

        IERC20(usdt).safeTransfer(vault, (amount * 8000) / BASE);

        uint256 reward = (amount * 500) / BASE;
        IERC20(usdt).safeTransfer(token, reward);
        IToken(token).notifyRewardAmount(reward);

        orders[msg.sender] = Order(amount, (amount * rewardRate) / BASE, block.timestamp, 0, 0, true);

        emit OrderCreated(msg.sender, amount);
    }

    function getReward() public {
        uint256 reward = earned(msg.sender);
        if (reward == 0) revert NoRewards();

        Order storage order = orders[msg.sender];
        order.claimedTime = block.timestamp;
        _updateOrder(order, reward);

        IVault(vault).transfer(usdt, pair, (reward * BASE * BASE) / 70000 / 18000);
        IUniswapV2Router(router).sync(pair);

        uint256 amount = (reward * 1e4) / price();

        IVault(vault).transfer(usdt, pair, reward);
        IVault(vault).transfer(token, pair, amount);
        IUniswapV2Router(router).sync(pair);

        IVault(vault).transfer(token, msg.sender, amount);
    }

    function _updateLevel(address user) private {
        uint256 level = levels[user];
        uint256 performance = configs[level + 1].performance;
        if (performance > 0 && performances[user] >= performance) {
            levels[user]++;
            _updateLevel(user);
        }
    }

    function _updateOrder(Order storage order, uint256 amount) private {
        order.claimedReward += amount;
        if (order.claimedReward == order.totalReward) {
            order.running = false;
        }
    }
}
