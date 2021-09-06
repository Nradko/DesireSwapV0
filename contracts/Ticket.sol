// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/ITicket.sol";

contract Ticket is ITicket{

    // struct TicketData can be found in ITicket
    
    // Mapping from token Id to positionSupplyCoefficient
    mapping (uint256 => mapping(int24 => uint256)) internal _ticketSupplyData;

    // Mapping from token ID to owner address
    mapping (uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping (address => uint256) private _balances;

    // Mapping from token ID to data
    mapping (uint256 => TicketData) internal _ticketData;


    uint256 private nextId;

    constructor() {
        nextId = 1;
    }

    function getNextId() external view override
    returns(uint256)
    {
        return nextId;
    }

    function getTicketOwner(uint256 ticketId) external view override
    returns(address)
    {
        return _owners[ticketId];
    }

    function getTicketData(uint256 ticketId) external view override
    returns(TicketData memory)
    {
        return _ticketData[ticketId];
    }

    function numberOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: ZERO_ADDRESS");
        return _balances[owner];
    }

    function ownerOf(uint256 ticketId) internal view returns (address) {
        address owner = _owners[ticketId];
        require(owner != address(0), "ERC721: TOKEN_DOES_NOT_EXIST");
        return owner;
    }

    function _exists(uint256 ticketId) internal view returns (bool) {
        return _owners[ticketId] != address(0);
    }

    function _mint(address to) internal returns (uint256) {
        require(to != address(0), "ERC721: ZERO_ADDRESS");

        _balances[to] += 1;
        _owners[nextId] = to;
        return (nextId++);
    }

    function _burn(uint256 ticketId) internal {
        address owner = ownerOf(ticketId);
        _balances[owner] -= 1;
        _owners[ticketId] = address(0);
        delete _ticketData[ticketId];
    }
}
