// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITicket {
  struct TicketData {
    int24 lowestRangeIndex;
    int24 highestRangeIndex;
    uint256 liqAdded;
  }

  /// @notice retruns the nextId that will be assigned to next minted Ticket
  /// @return the nextId
  function getNextId() external view returns (uint256);

  /// @notice get owner of ticket with ticketId Id
  /// @param ticketId of ticket
  /// @return owner od the ticket with Id == ticketId
  function getTicketOwner(uint256 ticketId) external view returns (address);

  /// @notice get ticketData srtuct assigned to ticket with Id ticketId
  /// @param ticketId of ticket
  /// @return TicketData assigned to the ticket
  function getTicketData(uint256 ticketId) external view returns (TicketData memory);

  /// @notice get number of tickets owned by owner
  /// @param
  /// @return number of ticket owned by owner
  function numberOf(address owner) external view returns (uint256);
}
