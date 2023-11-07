// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
