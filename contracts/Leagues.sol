// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./Squads.sol";

/// @title Leagues
/// @notice Manages leagues and competitions for the fantasy football game
/// @dev Interacts with the Squads contracts to access player and squad data
contract Leagues {
    address public constant SDAI = 0xaf204776c7245bF4147c2612BF6e5972Ee483701;
    address public constant WXDAI = 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;

    /// @notice Reference to the Squads contract
    Squads public squads;

    /// @notice Struct to represent a league
    struct League {
        uint256 id;
        string name;
        address[] participants;
        mapping(address => bool) isParticipant;
        mapping(address => uint256) scores;
    }

    /// @notice Mapping of league IDs to League structs
    mapping(uint256 => League) public leagues;

    /// @notice Counter for league IDs
    uint256 public leagueCounter;

    /// @notice Emitted when a new league is created
    event LeagueCreated(uint256 indexed leagueId, string name, address creator);

    /// @notice Emitted when a player joins a league
    event PlayerJoinedLeague(uint256 indexed leagueId, address player);

    /// @notice Emitted when a player abandons a league
    event PlayerAbandonedLeague(uint256 indexed leagueId, address player);

    /// @notice Initializes the Leagues contract
    /// @param _squads Address of the Squads contract
    constructor(address _squads) {
        squads = Squads(_squads);
    }

    /// @notice Creates a new league
    /// @param name The name of the new league
    function createLeague(string memory name) external {
        leagueCounter++;
        League storage newLeague = leagues[leagueCounter];
        newLeague.id = leagueCounter;
        newLeague.name = name;
        newLeague.participants.push(msg.sender);
        newLeague.isParticipant[msg.sender] = true;
        emit LeagueCreated(leagueCounter, name, msg.sender);
    }

    /// @notice Allows a user to join an existing league
    /// @param leagueId The ID of the league to join
    function joinLeague(uint256 leagueId) external payable {
        League storage league = leagues[leagueId];
        require(league.id != 0, "League does not exist");
        require(!league.isParticipant[msg.sender], "Already a participant");

        league.participants.push(msg.sender);
        league.isParticipant[msg.sender] = true;
        emit PlayerJoinedLeague(leagueId, msg.sender);
    }

    /// @notice Allows a user to join an existing league
    /// @param leagueId The ID of the league to join
    function joinGameweek(uint256 leagueId) external payable {
        League storage league = leagues[leagueId];
        require(league.id != 0, "League does not exist");
        require(!league.isParticipant[msg.sender], "Already a participant");

        league.participants.push(msg.sender);
        league.isParticipant[msg.sender] = true;
        emit PlayerJoinedLeague(leagueId, msg.sender);
    }

    /// @notice Allows a user to abandon a league
    /// @param leagueId The ID of the league to abandon
    function abandonLeague(uint256 leagueId) external {
        League storage league = leagues[leagueId];
        require(league.id != 0, "League does not exist");
        require(league.isParticipant[msg.sender], "Not a participant");

        // Remove the participant from the array
        for (uint256 i = 0; i < league.participants.length; i++) {
            if (league.participants[i] == msg.sender) {
                league.participants[i] = league.participants[league.participants.length - 1];
                league.participants.pop();
                break;
            }
        }

        // Update the participant status and remove their score
        league.isParticipant[msg.sender] = false;
        delete league.scores[msg.sender];

        emit PlayerAbandonedLeague(leagueId, msg.sender);
    }

    /// @notice Updates the scores for all participants in a league
    /// @param leagueId The ID of the league to update
    function updateLeagueScores(uint256 leagueId) external {
        League storage league = leagues[leagueId];
        for (uint256 i = 0; i < league.participants.length; i++) {
            address participant = league.participants[i];
            Squads.Squad memory squad = squads.getSquad(participant);
            league.scores[participant] = squad.totalPoints;
        }
    }

    /// @notice Checks if a player is a participant in a league
    /// @param leagueId The ID of the league to check
    /// @param player The address of the player to check
    /// @return True if the player is a participant, false otherwise
    function isParticipant(uint256 leagueId, address player) external view returns (bool) {
        return leagues[leagueId].isParticipant[player];
    }

    /// @notice Gets the number of participants in a league
    /// @param leagueId The ID of the league
    /// @return The number of participants in the league
    function getParticipantCount(uint256 leagueId) external view returns (uint256) {
        return leagues[leagueId].participants.length;
    }

    /// @notice Gets the score of a participant in a league
    /// @param leagueId The ID of the league
    /// @param participant The address of the participant
    /// @return The score of the participant in the specified league
    function getScore(uint256 leagueId, address participant) external view returns (uint256) {
        League storage league = leagues[leagueId];
        require(league.id != 0, "League does not exist");
        require(league.isParticipant[participant], "Not a participant in this league");
        return league.scores[participant];
    }
}
