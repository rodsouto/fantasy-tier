// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/src/auth/Owned.sol";

/// @title Entities
/// @notice Manages player and team entities for the fantasy football game
/// @dev Handles the creation, updating, and retrieval of player and team data
contract Entities is Owned {
    /// @notice Struct to represent a player
    struct Player {
        uint256 id;
        string name;
        string position;
        uint256 price;
        uint256 teamId;
    }

    /// @notice Struct to represent a team
    struct Team {
        uint256 id;
        string name;
    }

    /// @notice Mapping of player IDs to Player structs
    mapping(uint256 => Player) public players;

    /// @notice Array of all teams
    Team[] public teams;

    /// @notice Counter for player IDs
    uint256 private playerIdCounter;

    /// @notice Emitted when a new player is added
    event PlayerAdded(
        uint256 indexed playerId,
        string name,
        string position,
        uint256 price,
        uint256 teamId
    );

    /// @notice Emitted when a player is updated
    event PlayerUpdated(
        uint256 indexed playerId,
        string name,
        string position,
        uint256 price,
        uint256 teamId
    );

    /// @notice Emitted when a new team is added
    event TeamAdded(uint256 indexed teamId, string name);

    /// @notice Initializes the Entities contract
    constructor() Owned(msg.sender) {}

    /// @notice Adds a new player to the game
    /// @param name The player's name
    /// @param position The player's position
    /// @param price The player's price
    /// @param teamId The ID of the team the player belongs to
    /// @dev Can only be called by the contract owner
    function addPlayer(
        string memory name,
        string memory position,
        uint256 price,
        uint256 teamId
    ) external onlyOwner {
        playerIdCounter++;
        players[playerIdCounter] = Player({
            id: playerIdCounter,
            name: name,
            position: position,
            price: price,
            teamId: teamId
        });

        emit PlayerAdded(playerIdCounter, name, position, price, teamId);
    }

    /// @notice Updates an existing player's information
    /// @param playerId The ID of the player to update
    /// @param name The player's new name
    /// @param position The player's new position
    /// @param price The player's new price
    /// @param teamId The ID of the team the player now belongs to
    /// @dev Can only be called by the contract owner
    function updatePlayer(
        uint256 playerId,
        string memory name,
        string memory position,
        uint256 price,
        uint256 teamId
    ) external onlyOwner {
        require(players[playerId].id != 0, "Player does not exist");

        Player storage _player = players[playerId];
        _player.name = name;
        _player.position = position;
        _player.price = price;
        _player.teamId = teamId;

        emit PlayerUpdated(playerId, name, position, price, teamId);
    }

    /// @notice Adds a new team to the game
    /// @param name The name of the new team
    /// @dev Can only be called by the contract owner
    function addTeam(string memory name) external onlyOwner {
        teams.push(Team({id: teams.length + 1, name: name}));
        emit TeamAdded(teams.length, name);
    }

    /// @notice Retrieves a player's information
    /// @param playerId The ID of the player
    /// @return The Player struct for the given player ID
    function player(uint256 playerId) public view returns (Player memory) {
        return players[playerId];
    }

    /// @notice Gets the total number of players
    /// @return The total number of players
    function getPlayerCount() external view returns (uint256) {
        return playerIdCounter;
    }

    /// @notice Gets the total number of teams
    /// @return The total number of teams
    function getTeamCount() external view returns (uint256) {
        return teams.length;
    }
}
