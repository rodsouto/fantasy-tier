// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/src/auth/Owned.sol";
import "./Entities.sol";
import "./Squads.sol";
import "./Merkle.sol";

/// @title FantasyFootball
/// @notice This contract manages the core game logic for a fantasy football game
/// @dev Integrates with Reality.eth for real-world data and uses separate contracts for entity and squad management
contract FantasyFootball is Owned {
    /// @notice Contract for managing player and team entities
    Entities public entities;

    /// @notice Contract for managing user squads
    Squads public squads;

    /// @notice Contract for managing Reality.eth interactions
    Merkle public merkle;

    string public league;

    /// @notice The current game week number
    uint256 public currentGameWeek;

    /// @notice Indicates whether a game week is currently active
    bool public gameWeekActive;

    /// @notice Emitted when a new game week starts
    event GameWeekStarted(uint256 gameWeek);

    /// @notice Emitted when a game week ends
    event GameWeekEnded(uint256 gameWeek);

    /// @notice Initializes the contract with necessary dependencies
    /// @param _league League name
    /// @param _entities Address of the Entities contract
    /// @param _squads Address of the Squads contract
    /// @param _merkle Address of the Merkle contract
    constructor(
        string memory _league,
        Entities _entities,
        Squads _squads,
        Merkle _merkle
    ) Owned(msg.sender) {
        league = _league;
        entities = _entities;
        squads = _squads;
        merkle = _merkle;
    }

    /// @notice Starts a new game week
    /// @dev Can only be called by the contract owner
    function startGameWeek() external onlyOwner {
        require(!gameWeekActive, "Game week already active");
        currentGameWeek++;
        gameWeekActive = true;
        merkle.createGameWeekQuestion(league, currentGameWeek);
        emit GameWeekStarted(currentGameWeek);
    }

    /// @notice Ends the current game week and prepares for squad updates
    /// @dev Can only be called by the contract owner
    function endGameWeek() external onlyOwner {
        require(gameWeekActive, "No active game week");
        gameWeekActive = false;
        squads.resetTransfers();
        emit GameWeekEnded(currentGameWeek);
    }

    /// @notice Creates a new squad for the caller
    function createSquad() external {
        squads.createSquad(msg.sender, currentGameWeek);
    }
}
