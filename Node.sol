// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Node {
    using SafeERC20 for IERC20;

    address public recipient;
    address public token;
    address public relationship;
    uint256 public amount;
    uint256 public totalSupply;
    uint256 public actualSupply;

    mapping(address => bool) public nodes;

    event NodeCreated(address indexed user);

    error UserNotBinded();
    error Created();
    error SoldOut();

    constructor(address _recipient, address _token, address _relationship, uint256 _amount, uint256 _totalSupply) {
        recipient = _recipient;
        token = _token;
        relationship = _relationship;
        amount = _amount;
        totalSupply = _totalSupply;
    }

    function create() public {
        if (nodes[msg.sender] == true) revert Created();
        if (actualSupply == totalSupply) revert SoldOut();

        nodes[msg.sender] = true;

        IERC20(token).safeTransferFrom(msg.sender, recipient, amount);
        actualSupply++;

        emit NodeCreated(msg.sender);
    }
}
