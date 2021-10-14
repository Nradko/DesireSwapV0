// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface ITicket {
  struct TicketData {
    int24 lowestRangeIndex;
    int24 highestRangeIndex;
    uint256 liqAdded;
  }

  /// @notice returns the nextId that will be assigned to next minted Ticket
  /// @return the nextId
  function getNextTicketId() external view returns (uint256);

  /// @notice get ticketData srtuct assigned to ticket with Id ticketId
  /// @param ticketId of ticket
  /// @return TicketData assigned to the ticket
  function getTicketData(uint256 ticketId) external view returns (TicketData memory);

  /// @notice returns the supply at range indexed by index of ticket with ticket Id ticketId
  /// @param ticketId of ticket
  /// @param index of range
  /// @return supply at range
  function getTicketSupplyData(uint256 ticketId, int24 index) external view returns (uint256);

  /// doc in TicketId;
  function getAddressLength(address owner_) external view returns (uint256);

  function getAddressTickets(address owner_, uint256 position_) external view returns (uint256);

  function getTicketPosition(uint256 ticketId_) external view returns (uint256);
}
