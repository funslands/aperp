// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../libraries/Governable.sol";

contract APerp is ERC20, Governable {

    uint256 public cap = 100000000e18;

    error ERC20ExceededCap(uint256 increasedSupply, uint256 cap);

    constructor() ERC20("a perp", "APERP") Governable() {}

    function mint(address account, uint256 amount) public onlyGov() {
        require(totalSupply()+amount <= cap, ERC20ExceededCap(totalSupply()+amount, cap));
        _mint(account, amount);
    }
}