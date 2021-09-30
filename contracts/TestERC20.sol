// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
  constructor(
    string memory name_,
    string memory symbol_,
    address addr1
  ) ERC20(name_, symbol_) {
    _mint(addr1, 10**36);
  }
}
