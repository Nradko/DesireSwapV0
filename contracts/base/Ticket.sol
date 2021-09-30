/*******************************************************
 * Copyright (C) 2021-2022 Konrad Wierzbik <desired.desire@protonmail.com>
 *
 * This file is part of DesireSwapProject.
 *
 * DesireSwapProject can not be copied and/or distributed without the express
 * permission of Konrad Wierzbik
 *******************************************************/
pragma solidity ^0.8.0;

import '../interfaces/pool/ITicket.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import 'hardhat/console.sol';

contract Ticket is ERC721, ITicket {
  // struct TicketData can be found in ITicket

  // Mapping from token Id to positionSupplyCoefficient
  mapping(uint256 => mapping(int24 => uint256)) internal _ticketSupplyData;

  // Mapping from token ID to data
  mapping(uint256 => TicketData) internal _ticketData;

  uint256 internal _nextTicketId = 1;
  // below mappings are keeping infromation about which tickets and address own
  // and on which position in array the ticket can be found
  mapping(address => mapping(uint256 => uint256)) private _addressTickets;
  mapping(address => uint256) private _addressTicketsLength;
  mapping(uint256 => uint256) private _ticketPosition;

  constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

  function getNextTicketId() public view override returns (uint256) {
    return _nextTicketId;
  }

  function getTicketData(uint256 ticketId_) external view override returns (TicketData memory) {
    return _ticketData[ticketId_];
  }

  function getTicketSupplyData(uint256 ticketId_, int24 index_) external view override returns (uint256) {
    return _ticketSupplyData[ticketId_][index_];
  }

  function getAddressLength(address owner_) external view override returns (uint256) {
    return _addressTicketsLength[owner_];
  }

  function getAddressTickets(address owner_, uint256 position_) external view override returns (uint256) {
    return _addressTickets[owner_][position_];
  }

  function getTicketPosition(uint256 ticketId_) external view override returns (uint256) {
    return _ticketPosition[ticketId_];
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 ticketId
  ) internal override {
    uint256 ticketPosition = _ticketPosition[ticketId];
    _addressTickets[from][ticketPosition] = 0;
    uint256 length = _addressTicketsLength[to]++;
    if (length == 0) {
      length++;
      _addressTicketsLength[to]++;
    }
    _addressTickets[to][length] = ticketId;
    _ticketPosition[ticketId] = length;
  }
}
