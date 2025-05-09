// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {

    uint8 private decimal;

    constructor(string memory _name, string memory _symbol, uint8 _decimal)  ERC20(_name, _symbol) {
        decimal = _decimal;
    }

    function decimals() public view override returns(uint8) {
        return decimal;
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}