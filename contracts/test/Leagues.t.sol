// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Leagues.sol";
import "../src/Squads.sol";
import "../src/Entities.sol";
import "../src/Merkle.sol";

contract LeagueTest is Test {
    Leagues public leagues;
    Squads public squads;
    Entities public entities;
    Merkle public merkle;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        entities = new Entities();
        merkle = new Merkle(IRealityETH(address(0)), address(0), 0, 0); // Mock RealityETH address
        squads = new Squads(entities, merkle);
        leagues = new Leagues(address(squads));

        // Create squads for testing
        squads.createSquad(user1, 1);
        squads.createSquad(user2, 1);
    }

    function testCreateLeague() public {
        vm.prank(user1);
        leagues.createLeague("Test League");
        assertEq(leagues.leagueCounter(), 1);
        (uint256 id, string memory name) = leagues.leagues(1);
        assertEq(id, 1);
        assertEq(name, "Test League");
    }

    function testJoinLeague() public {
        vm.prank(user1);
        leagues.createLeague("Test League");

        vm.prank(user2);
        leagues.joinLeague(1);

        assertTrue(leagues.isParticipant(1, user1));
        assertTrue(leagues.isParticipant(1, user2));
        assertEq(leagues.getParticipantCount(1), 2);
    }

    function testAbandonLeague() public {
        vm.prank(user1);
        leagues.createLeague("Test League");

        vm.prank(user2);
        leagues.joinLeague(1);

        vm.prank(user2);
        leagues.abandonLeague(1);

        assertTrue(leagues.isParticipant(1, user1));
        assertFalse(leagues.isParticipant(1, user2));
        assertEq(leagues.getParticipantCount(1), 1);
    }

    function testUpdateLeagueScores() public {
        vm.prank(user1);
        leagues.createLeague("Test League");

        vm.prank(user2);
        leagues.joinLeague(1);

        // Update squad points using updateGameWeekScores
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

        leagues.updateLeagueScores(1);

        // Check if scores are updated correctly
        assertEq(leagues.getScore(1, user1), 100);
        assertEq(leagues.getScore(1, user2), 150);
    }
}
