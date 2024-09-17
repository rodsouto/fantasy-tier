// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/src/auth/Owned.sol";
import "./Entities.sol";
import "./Merkle.sol";

/// @title Squads
/// @notice Manages user squads for the fantasy football game
/// @dev Handles squad creation, player management, and point calculations
contract Squads is Owned {
    /// @notice Reference to the Entities contract
    Entities public entities;

    /// @notice Represents a player in a user's squad
    struct SquadPlayer {
        uint256 id;
        uint256 teamId;
        bool isStarter;
    }

    /// @notice Represents a user's squad
    struct Squad {
        address owner;
        SquadPlayer[] players;
        uint256 budget;
        uint256 totalPoints;
        uint256 freeTransfers;
        bool usedWildcard;
        uint256 captainId;
        uint256 viceCaptainId;
        uint256 joinedGameWeek; // New field to track when the squad joined
    }

    /// @notice Mapping of user addresses to their squads
    mapping(address => Squad) public squads;

    /// @notice Array of all squad owners' addresses
    address[] public squadOwners;

    /// @notice Maximum number of players allowed in a squad
    uint256 public constant MAX_SQUAD_SIZE = 15;

    /// @notice Maximum number of players allowed from a single team
    uint256 public constant MAX_PLAYERS_PER_TEAM = 3;

    /// @notice Initial budget for each squad
    uint256 public constant INITIAL_BUDGET = 100 * 1e6; // 100 million

    /// @notice Point cost for extra transfers
    uint256 public constant TRANSFER_COST = 4; // 4 points per extra transfer

    /// @notice Maximum number of free transfers allowed
    uint256 public constant MAX_FREE_TRANSFERS = 2;

    /// @notice Emitted when a new squad is created
    event SquadCreated(address indexed owner);

    /// @notice Emitted when a player is added to a squad
    event PlayerAdded(address indexed owner, uint256 playerId);

    /// @notice Emitted when a player is removed from a squad
    event PlayerRemoved(address indexed owner, uint256 playerId);

    /// @notice Emitted when a player transfer occurs
    event PlayerTransferred(
        address indexed owner,
        uint256 playerOut,
        uint256 playerIn
    );

    /// @notice Emitted when a squad's lineup is set
    event LineupSet(address indexed owner);

    /// @notice Emitted when a squad's captain and vice-captain are set
    event CaptainSet(
        address indexed owner,
        uint256 captainId,
        uint256 viceCaptainId
    );

    /// @notice Emitted when a wildcard is used
    event WildcardUsed(address indexed owner);

    /// @notice Emitted when a squad's points are updated
    event SquadPointsUpdated(
        address indexed owner,
        uint256 gameWeek,
        uint256 newTotalPoints
    );

    /// @notice Reference to the Merkle contract
    Merkle public merkle;

    /// @notice Mapping to store squad points for each game week
    /// @dev Mapping structure: squadOwner => gameWeek => points
    mapping(address => mapping(uint256 => uint256)) public squadGameWeekPoints;

    /// @notice Mapping to track processed game weeks for each squad
    mapping(address => mapping(uint256 => bool)) public processedGameWeeks;

    /// @notice Initializes the Squads contract
    /// @param _entities Address of the Entities contract
    /// @param _merkle Address of the Merkle contract
    constructor(Entities _entities, Merkle _merkle) Owned(msg.sender) {
        entities = _entities;
        merkle = _merkle;
    }

    /// @notice Creates a new squad for the specified owner
    /// @param owner The address of the squad owner
    /// @param currentGameWeek The current game week when the squad is created
    function createSquad(
        address owner,
        uint256 currentGameWeek
    ) external onlyOwner {
        require(squads[owner].owner == address(0), "Squad already exists");
        squads[owner].owner = owner;
        squads[owner].budget = INITIAL_BUDGET;
        squads[owner].totalPoints = 0;
        squads[owner].freeTransfers = MAX_FREE_TRANSFERS;
        squads[owner].usedWildcard = false;
        squads[owner].captainId = 0;
        squads[owner].viceCaptainId = 0;
        squads[owner].joinedGameWeek = currentGameWeek;
        // Note: We don't initialize the players array here, it will start empty
        squadOwners.push(owner);
        emit SquadCreated(owner);
    }

    /// @notice Adds a player to the caller's squad
    /// @param playerId The ID of the player to add
    function addPlayer(uint256 playerId) public {
        Squad storage squad = squads[msg.sender];
        Entities.Player memory player = entities.player(playerId);

        require(squad.players.length < MAX_SQUAD_SIZE, "Squad is full");
        require(squad.budget >= player.price, "Insufficient budget");

        // Check for max players per team
        uint256 teamPlayerCount = 0;
        for (uint256 i = 0; i < squad.players.length; i++) {
            if (squad.players[i].teamId == player.teamId) {
                teamPlayerCount++;
            }
        }
        require(
            teamPlayerCount <= MAX_PLAYERS_PER_TEAM,
            "Max players per team reached"
        );

        squad.players.push(
            SquadPlayer({
                id: player.id,
                teamId: player.teamId,
                isStarter: false
            })
        );
        squad.budget -= player.price;
        emit PlayerAdded(msg.sender, playerId);
    }

    /// @notice Removes a player from the caller's squad
    /// @param playerId The ID of the player to remove
    function removePlayer(uint256 playerId) public {
        Squad storage squad = squads[msg.sender];
        Entities.Player memory player = entities.player(playerId);

        for (uint256 i = 0; i < squad.players.length; i++) {
            if (squad.players[i].id == player.id) {
                squad.players[i] = squad.players[squad.players.length - 1];
                squad.players.pop();
                squad.budget += player.price;
                break;
            }
        }
        emit PlayerRemoved(msg.sender, playerId);
    }

    /// @notice Transfers a player in the caller's squad
    /// @param playerOutId The ID of the player to remove
    /// @param playerInId The ID of the player to add
    function transferPlayer(uint256 playerOutId, uint256 playerInId) external {
        Squad storage squad = squads[msg.sender];
        require(squad.owner != address(0), "Squad does not exist");

        removePlayer(playerOutId);
        addPlayer(playerInId);

        if (squad.freeTransfers > 0) {
            squad.freeTransfers--;
        } else {
            squad.totalPoints -= TRANSFER_COST;
        }

        emit PlayerTransferred(msg.sender, playerOutId, playerInId);
    }

    /// @notice Uses the wildcard for the caller's squad
    function useWildcard() external {
        Squad storage squad = squads[msg.sender];
        require(squad.owner != address(0), "Squad does not exist");
        require(!squad.usedWildcard, "Wildcard already used this season");

        squad.usedWildcard = true;
        squad.freeTransfers = MAX_SQUAD_SIZE; // Allow unlimited free transfers
        emit WildcardUsed(msg.sender);
    }

    /// @notice Sets the lineup for the caller's squad
    /// @param starterIds An array of player IDs to set as starters
    function setLineup(uint256[] calldata starterIds) external {
        Squad storage squad = squads[msg.sender];
        require(squad.owner != address(0), "Squad does not exist");
        require(starterIds.length == 11, "Must select exactly 11 starters");

        uint256 goalkeeperCount = 0;
        uint256 defenderCount = 0;
        uint256 midfielderCount = 0;
        uint256 forwardCount = 0;

        for (uint256 i = 0; i < squad.players.length; i++) {
            squad.players[i].isStarter = false;
        }

        for (uint256 i = 0; i < starterIds.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < squad.players.length; j++) {
                if (squad.players[j].id == starterIds[i]) {
                    squad.players[j].isStarter = true;
                    found = true;

                    Entities.Player memory player = entities.player(
                        starterIds[i]
                    );
                    if (
                        keccak256(abi.encodePacked(player.position)) ==
                        keccak256(abi.encodePacked("Goalkeeper"))
                    ) {
                        goalkeeperCount++;
                    } else if (
                        keccak256(abi.encodePacked(player.position)) ==
                        keccak256(abi.encodePacked("Defender"))
                    ) {
                        defenderCount++;
                    } else if (
                        keccak256(abi.encodePacked(player.position)) ==
                        keccak256(abi.encodePacked("Midfielder"))
                    ) {
                        midfielderCount++;
                    } else if (
                        keccak256(abi.encodePacked(player.position)) ==
                        keccak256(abi.encodePacked("Forward"))
                    ) {
                        forwardCount++;
                    }

                    break;
                }
            }
            require(found, "Invalid player ID");
        }

        require(goalkeeperCount == 1, "Must have exactly 1 goalkeeper");
        require(defenderCount >= 3, "Must have at least 3 defenders");
        require(midfielderCount >= 2, "Must have at least 2 midfielders");
        require(forwardCount >= 1, "Must have at least 1 forward");

        emit LineupSet(msg.sender);
    }

    /// @notice Sets the captain and vice-captain for the caller's squad
    /// @param captainId The ID of the player to set as captain
    /// @param viceCaptainId The ID of the player to set as vice-captain
    function setCaptain(uint256 captainId, uint256 viceCaptainId) external {
        Squad storage squad = squads[msg.sender];
        require(squad.owner != address(0), "Squad does not exist");

        bool captainFound = false;
        bool viceCaptainFound = false;

        for (uint256 i = 0; i < squad.players.length; i++) {
            if (
                squad.players[i].id == captainId && squad.players[i].isStarter
            ) {
                captainFound = true;
            }
            if (
                squad.players[i].id == viceCaptainId &&
                squad.players[i].isStarter
            ) {
                viceCaptainFound = true;
            }
        }

        require(captainFound, "Captain must be in the starting lineup");
        require(
            viceCaptainFound,
            "Vice-captain must be in the starting lineup"
        );
        require(
            captainId != viceCaptainId,
            "Captain and vice-captain must be different players"
        );

        squad.captainId = captainId;
        squad.viceCaptainId = viceCaptainId;

        emit CaptainSet(msg.sender, captainId, viceCaptainId);
    }

    /// @notice Resets transfers for all squads
    /// @dev Can only be called by the contract owner
    function resetTransfers() external onlyOwner {
        for (uint256 i = 0; i < squadOwners.length; i++) {
            address squadOwner = squadOwners[i];
            Squad storage squad = squads[squadOwner];
            squad.freeTransfers = squad.freeTransfers < MAX_FREE_TRANSFERS
                ? squad.freeTransfers + 1
                : MAX_FREE_TRANSFERS;
        }
    }

    /// @notice Retrieves a squad by owner address
    /// @param owner The address of the squad owner
    /// @return The Squad struct for the given owner
    function getSquad(address owner) external view returns (Squad memory) {
        return squads[owner];
    }

    /// @notice Retrieves all squad owner addresses
    /// @return An array of all squad owner addresses
    function getSquadOwners() external view returns (address[] memory) {
        return squadOwners;
    }

    /// @notice Updates scores for multiple squads in a given game week
    /// @param gameWeek The game week number
    /// @param squadScores Array of SquadScore structs containing owner addresses and points
    /// @param proofs Array of Merkle proofs corresponding to each SquadScore
    function updateGameWeekScores(
        uint256 gameWeek,
        Merkle.SquadScore[] memory squadScores,
        bytes32[][] memory proofs
    ) external onlyOwner {
        require(squadScores.length == proofs.length, "Invalid input length");

        for (uint256 i = 0; i < squadScores.length; i++) {
            require(
                merkle.verifySquadScore(gameWeek, squadScores[i], proofs[i]),
                "Invalid Merkle proof"
            );

            address squadOwner = squadScores[i].owner;
            uint256 newPoints = squadScores[i].points;

            // Check if this game week has already been processed for this squad
            if (!processedGameWeeks[squadOwner][gameWeek]) {
                squads[squadOwner].totalPoints += newPoints;
                squadGameWeekPoints[squadOwner][gameWeek] = newPoints;
                processedGameWeeks[squadOwner][gameWeek] = true;
                emit SquadPointsUpdated(
                    squadOwner,
                    gameWeek,
                    squads[squadOwner].totalPoints
                );
            }
        }
    }

    /// @notice Retrieves the points for a specific squad in a given game week
    /// @param squadOwner The address of the squad owner
    /// @param gameWeek The game week number
    /// @return The points scored by the squad in the specified game week
    function getSquadGameWeekPoints(
        address squadOwner,
        uint256 gameWeek
    ) external view returns (uint256) {
        return squadGameWeekPoints[squadOwner][gameWeek];
    }
}
