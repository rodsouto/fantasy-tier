// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Squads.sol";
import "../src/Entities.sol";
import "../src/Merkle.sol";

contract SquadsTest is Test {
    Squads public squads;
    Entities public entities;
    Merkle public merkle;
    address public owner;
    address public user1;
    address public user2;
    bytes32 public merkleRoot;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        entities = new Entities();
        merkle = new Merkle(IRealityETH(address(0)), address(0), 0, 0); // Mock RealityETH address
        squads = new Squads(entities, merkle);

        // Add some players and teams to Entities
        entities.addTeam("Team A");
        entities.addTeam("Team B");
        entities.addTeam("Team C");
        entities.addTeam("Team D");
        entities.addTeam("Team E");
        entities.addTeam("Team F");
        entities.addPlayer("Player 1", "Forward", 10 * 1e6, 1);
        entities.addPlayer("Player 2", "Midfielder", 8 * 1e6, 1);
        entities.addPlayer("Player 3", "Defender", 7 * 1e6, 2);
        entities.addPlayer("Player 4", "Goalkeeper", 6 * 1e6, 2);
        entities.addPlayer("Player 5", "Forward", 10 * 1e6, 3);
        entities.addPlayer("Player 6", "Midfielder", 8 * 1e6, 3);
        entities.addPlayer("Player 7", "Defender", 7 * 1e6, 4);
        entities.addPlayer("Player 8", "Midfielder", 8 * 1e6, 4);
        entities.addPlayer("Player 9", "Forward", 10 * 1e6, 5);
        entities.addPlayer("Player 10", "Defender", 7 * 1e6, 5);
        entities.addPlayer("Player 11", "Midfielder", 8 * 1e6, 6);

        // Generate a mock Merkle root
        merkleRoot = keccak256("mock merkle root");
    }

    function testCreateSquad() public {
        squads.createSquad(user1, 1);
        Squads.Squad memory squad = squads.getSquad(user1);
        assertEq(squad.owner, user1);
        assertEq(squad.budget, squads.INITIAL_BUDGET());
        assertEq(squad.joinedGameWeek, 1);
    }

    function testAddPlayer() public {
        squads.createSquad(user1, 1);
        vm.prank(user1);
        squads.addPlayer(1);
        Squads.Squad memory squad = squads.getSquad(user1);
        assertEq(squad.players.length, 1);
        assertEq(squad.players[0].id, 1);
    }

    function testRemovePlayer() public {
        squads.createSquad(user1, 1);
        vm.startPrank(user1);
        squads.addPlayer(1);
        squads.removePlayer(1);
        vm.stopPrank();
        Squads.Squad memory squad = squads.getSquad(user1);
        assertEq(squad.players.length, 0);
    }

    function testSetLineup() public {
        squads.createSquad(user1, 1);
        vm.startPrank(user1);

        // Add players from different teams to avoid reaching the max players per team limit
        squads.addPlayer(1); // Forward from Team A
        squads.addPlayer(2); // Midfielder from Team A
        squads.addPlayer(3); // Defender from Team B
        squads.addPlayer(4); // Goalkeeper from Team B
        squads.addPlayer(5); // Forward from Team C (assuming we have more teams)
        squads.addPlayer(6); // Midfielder from Team C
        squads.addPlayer(7); // Defender from Team D
        squads.addPlayer(8); // Midfielder from Team D
        squads.addPlayer(9); // Forward from Team E
        squads.addPlayer(10); // Defender from Team E
        squads.addPlayer(11); // Midfielder from Team F

        uint256[] memory starterIds = new uint256[](11);
        starterIds[0] = 4; // Goalkeeper
        starterIds[1] = 3; // Defender
        starterIds[2] = 7; // Defender
        starterIds[3] = 10; // Defender
        starterIds[4] = 2; // Midfielder
        starterIds[5] = 6; // Midfielder
        starterIds[6] = 8; // Midfielder
        starterIds[7] = 11; // Midfielder
        starterIds[8] = 1; // Forward
        starterIds[9] = 5; // Forward
        starterIds[10] = 9; // Forward

        squads.setLineup(starterIds);
        vm.stopPrank();

        // Get the updated squad
        Squads.Squad memory squad = squads.getSquad(user1);

        // Check if the correct number of players are set as starters
        uint256 starterCount = 0;
        for (uint256 i = 0; i < squad.players.length; i++) {
            if (squad.players[i].isStarter) {
                starterCount++;
            }
        }
        assertEq(starterCount, 11, "Incorrect number of starters");

        // Check if the correct players are set as starters
        bool[12] memory playerStarterStatus = [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ];
        for (uint256 i = 0; i < squad.players.length; i++) {
            if (squad.players[i].isStarter) {
                playerStarterStatus[squad.players[i].id] = true;
            }
        }
        assertTrue(playerStarterStatus[1], "Forward should be a starter");
        assertTrue(playerStarterStatus[2], "Midfielder should be a starter");
        assertTrue(playerStarterStatus[3], "Defender should be a starter");
        assertTrue(playerStarterStatus[4], "Goalkeeper should be a starter");

        // Check if the correct number of players for each position are set as starters
        uint256 goalkeeperCount = 0;
        uint256 defenderCount = 0;
        uint256 midfielderCount = 0;
        uint256 forwardCount = 0;

        for (uint256 i = 0; i < squad.players.length; i++) {
            if (squad.players[i].isStarter) {
                Entities.Player memory player = entities.player(
                    squad.players[i].id
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
            }
        }

        assertEq(goalkeeperCount, 1, "Incorrect number of goalkeepers");
        assertEq(defenderCount, 3, "Incorrect number of defenders");
        assertEq(midfielderCount, 4, "Incorrect number of midfielders");
        assertEq(forwardCount, 3, "Incorrect number of forwards");
    }

    function testSetLineupInvalidPlayerCount() public {
        squads.createSquad(user1, 1);
        vm.startPrank(user1);
        squads.addPlayer(1);
        squads.addPlayer(2);
        squads.addPlayer(3);
        squads.addPlayer(4);

        uint256[] memory starterIds = new uint256[](10); // Invalid: only 10 players
        for (uint256 i = 0; i < 10; i++) {
            starterIds[i] = 1;
        }

        vm.expectRevert("Must select exactly 11 starters");
        squads.setLineup(starterIds);
        vm.stopPrank();
    }

    function testSetLineupNoGoalkeeper() public {
        squads.createSquad(user1, 1);
        vm.startPrank(user1);
        squads.addPlayer(1);
        squads.addPlayer(2);
        squads.addPlayer(3);

        uint256[] memory starterIds = new uint256[](11);
        for (uint256 i = 0; i < 11; i++) {
            starterIds[i] = i < 3 ? i + 1 : 3; // No goalkeeper
        }

        vm.expectRevert("Must have exactly 1 goalkeeper");
        squads.setLineup(starterIds);
        vm.stopPrank();
    }

    function testSetLineupInsufficientDefenders() public {
        squads.createSquad(user1, 1);
        vm.startPrank(user1);
        squads.addPlayer(1);
        squads.addPlayer(2);
        squads.addPlayer(3);
        squads.addPlayer(4);

        uint256[] memory starterIds = new uint256[](11);
        starterIds[0] = 4; // Goalkeeper
        starterIds[1] = 3; // Only 1 defender
        for (uint256 i = 2; i < 11; i++) {
            starterIds[i] = i % 2 == 0 ? 1 : 2; // Alternating forwards and midfielders
        }

        vm.expectRevert("Must have at least 3 defenders");
        squads.setLineup(starterIds);
        vm.stopPrank();
    }

    function testSetLineupInsufficientMidfielders() public {
        squads.createSquad(user1, 1);
        vm.startPrank(user1);
        squads.addPlayer(1);
        squads.addPlayer(2);
        squads.addPlayer(3);
        squads.addPlayer(4);

        uint256[] memory starterIds = new uint256[](11);
        starterIds[0] = 4; // Goalkeeper
        starterIds[1] = 3; // Defender
        starterIds[2] = 3; // Defender
        starterIds[3] = 3; // Defender
        starterIds[4] = 2; // Only 1 midfielder
        for (uint256 i = 5; i < 11; i++) {
            starterIds[i] = 1; // Forwards
        }

        vm.expectRevert("Must have at least 2 midfielders");
        squads.setLineup(starterIds);
        vm.stopPrank();
    }

    function testSetLineupNoForwards() public {
        squads.createSquad(user1, 1);
        vm.startPrank(user1);
        squads.addPlayer(1);
        squads.addPlayer(2);
        squads.addPlayer(3);
        squads.addPlayer(4);

        uint256[] memory starterIds = new uint256[](11);
        starterIds[0] = 4; // Goalkeeper
        starterIds[1] = 3; // Defender
        starterIds[2] = 3; // Defender
        starterIds[3] = 3; // Defender
        for (uint256 i = 4; i < 11; i++) {
            starterIds[i] = 2; // All midfielders, no forwards
        }

        vm.expectRevert("Must have at least 1 forward");
        squads.setLineup(starterIds);
        vm.stopPrank();
    }

    function testSetLineupInvalidPlayerId() public {
        squads.createSquad(user1, 1);
        vm.startPrank(user1);
        squads.addPlayer(1);
        squads.addPlayer(2);
        squads.addPlayer(3);
        squads.addPlayer(4);

        uint256[] memory starterIds = new uint256[](11);
        starterIds[0] = 4; // Goalkeeper
        starterIds[1] = 3; // Defender
        starterIds[2] = 3; // Defender
        starterIds[3] = 3; // Defender
        starterIds[4] = 2; // Midfielder
        starterIds[5] = 2; // Midfielder
        starterIds[6] = 1; // Forward
        starterIds[7] = 1; // Forward
        starterIds[8] = 1; // Forward
        starterIds[9] = 1; // Forward
        starterIds[10] = 5; // Invalid player ID

        vm.expectRevert("Invalid player ID");
        squads.setLineup(starterIds);
        vm.stopPrank();
    }

    function testUpdateGameWeekScores() public {
        squads.createSquad(user1, 1);
        squads.createSquad(user2, 1);

        uint256 gameWeek = 1;
        Merkle.SquadScore[] memory squadScores = new Merkle.SquadScore[](2);
        squadScores[0] = Merkle.SquadScore(user1, 100);
        squadScores[1] = Merkle.SquadScore(user2, 150);

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = keccak256("mock proof for user1");
        proofs[1] = new bytes32[](1);
        proofs[1][0] = keccak256("mock proof for user2");

        // Mock the Merkle verification
        vm.mockCall(
            address(merkle),
            abi.encodeWithSelector(merkle.verifySquadScore.selector),
            abi.encode(true)
        );

        squads.updateGameWeekScores(gameWeek, squadScores, proofs);

        assertEq(squads.getSquadGameWeekPoints(user1, gameWeek), 100);
        assertEq(squads.getSquadGameWeekPoints(user2, gameWeek), 150);

        Squads.Squad memory squad1 = squads.getSquad(user1);
        Squads.Squad memory squad2 = squads.getSquad(user2);

        assertEq(squad1.totalPoints, 100);
        assertEq(squad2.totalPoints, 150);
    }

    function testUpdateGameWeekScoresInvalidProof() public {
        uint256 gameWeek = 1;
        Merkle.SquadScore[] memory squadScores = new Merkle.SquadScore[](1);
        squadScores[0] = Merkle.SquadScore(user1, 100);

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](1);
        proofs[0][0] = keccak256("invalid proof");

        // Mock the Merkle root
        vm.mockCall(
            address(merkle),
            abi.encodeWithSelector(merkle.getGameWeekMerkleRoot.selector),
            abi.encode(merkleRoot)
        );
        // Mock the verification to return false
        vm.mockCall(
            address(merkle),
            abi.encodeWithSelector(merkle.verifySquadScore.selector),
            abi.encode(false)
        );

        vm.expectRevert("Invalid Merkle proof");
        squads.updateGameWeekScores(gameWeek, squadScores, proofs);
    }
}
