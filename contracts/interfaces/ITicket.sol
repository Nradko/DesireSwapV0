// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITicket
{
    struct TicketData {
        int24 lowestRangeIndex;
        int24 highestRangeIndex;
        uint256 liqAdded;
    }

    function getTicketOwner(uint256 ticketId) external view
    returns(address);

    function getBalance(address owner) external view
    returns(uint256);

    function findOwnedTickets(address owner, uint256 number) external view
    returns (uint256);

    function getTicketData(uint256 ticketId) external view
    returns(TicketData memory);

    function numberOf(address owner) external view returns (uint256);
}