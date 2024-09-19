// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "solmate/src/auth/Owned.sol";

/// @title Entities
/// @notice Manages player and team entities for the fantasy football game
/// @dev Handles the creation, updating, and retrieval of player and team data
contract Entities is Owned {
    enum Position {
        GOALKEEPER,
        DEFENDER,
        MIDFIELDER,
        FORWARD
    }

    /// @notice Struct to represent a player
    struct Player {
        Position position;
        uint8 teamId; // index of team ordering all the teams alphabetically
        uint240 price;
    }

    /// @notice Mapping of player IDs to Player structs
    mapping(bytes32 => Player) public players;

    /// @notice Emitted when a player is updated
    event PlayerUpdated(bytes32 indexed playerId, Position indexed position, uint8 indexed teamId, uint240 price);

    /// @notice Adds a new player to the game
    /// @param playerIds The player's name
    /// @param positions The player's position
    /// @param teamIds The ID of the team the player belongs to
    /// @param prices The player's price
    /// @dev Can only be called by the contract owner
    function addPlayers(
        bytes32[] calldata playerIds,
        Position[] calldata positions,
        uint8[] calldata teamIds,
        uint240[] calldata prices
    ) external onlyOwner {
        for (uint256 i; i < playerIds.length; i++) {
            players[playerIds[i]] = Player({position: positions[i], teamId: teamIds[i], price: prices[i]});

            emit PlayerUpdated(playerIds[i], positions[i], teamIds[i], prices[i]);
        }
    }
}
