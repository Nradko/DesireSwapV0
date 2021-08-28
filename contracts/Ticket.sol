// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Ticket {

    struct TicketData {
        int24 lowestRangeIndex;
        int24 highestRangeIndex;
        uint256 liqAdded;
        //mapping (int24 => uint256) positionSupplyCoefficient;
    }

    // Mapping from token ID to owner address
    mapping (uint256 => address) internal _owners;

    // Mapping owner address to token count
    mapping (address => uint256) internal _balances;

    // Mapping from token ID to data
    mapping (uint256 => TicketData) internal _ticketData;

    // Mapping from token Id to positionSupplyCoefficient
    mapping (uint256 => mapping(int24 => uint256)) _ticketSupplyData;

    uint256 emissionCounter;

    constructor() {
        emissionCounter = 0;
    }

    function numberOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ERC721: ZERO_ADDRESS");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: TOKEN_DOES_NOT_EXIST");
        return owner;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _mint(address to) internal virtual returns (uint256) {
        require(to != address(0), "ERC721: ZERO_ADDRESS");

        _balances[to] += 1;
        _owners[emissionCounter] = to;
        emissionCounter++;
        return (emissionCounter - 1);
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];
    }
}
