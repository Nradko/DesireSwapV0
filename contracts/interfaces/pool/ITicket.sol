// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface ITicket is IERC721 {
  struct TicketData {
    int24 lowestRangeIndex;
    int24 highestRangeIndex;
    uint256 liqAdded;
  }

  /// @notice returns the nextId that will be assigned to next minted Ticket
  /// @return the nextId
  function getNextTicketId() external view returns (uint256);

  /// @param ticketId of ticket
  /// @return TicketData assigned to the ticket
  function getTicketData(uint256 ticketId) external view returns (TicketData memory);

  /// @param ticketId of ticket
  /// @param index of range
  /// @return supply at range
  function getTicketSupplyData(uint256 ticketId, int24 index) external view returns (uint256);

  /// @notice returns amount of tickets that were sent to owner_
  /// @return amount of tickets sent to this address
  function getAddressTicketsAmount(address owner_) external view returns (uint256);

  /// @notice returns Id of ticked that was sent to owner_ as position_, returns 0 If onwer_ isnt onwer of ticket anymore
  function getAddressTicketsByPosition(address owner_, uint256 position_) external view returns (uint256);

  /// @notice return position_ of ticked with ticketId_ on the list of tickets of owner of this ticket
  function getTicketPosition(uint256 ticketId_) external view returns (uint256);

  /// @notice return list of all onwer_ tickets with its data
  function getAddressTicketIdList(address owner_) external view returns (uint256[] memory ticketIdList);
}
