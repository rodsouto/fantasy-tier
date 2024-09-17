// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/FantasyFootball.sol";
import "../src/Entities.sol";
import "../src/Squads.sol";
import "../src/Merkle.sol";
import "../src/interfaces/IRealityETH.sol";

contract FantasyFootballTest is Test {
    FantasyFootball public fantasyFootball;
    Entities public entities;
    Squads public squads;
    Merkle public merkle;
    IRealityETH public mockRealityETH;

    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        entities = new Entities();

        // Create a mock RealityETH contract
        mockRealityETH = IRealityETH(address(new MockRealityETH()));

        // Create Merkle contract with the mock RealityETH address
        merkle = new Merkle(mockRealityETH, address(0), 0, 0);

        squads = new Squads(entities, merkle);

        vm.prank(owner);
        fantasyFootball = new FantasyFootball(
            "Test League",
            entities,
            squads,
            merkle
        );

        // Transfer ownership of Merkle contract to FantasyFootball
        merkle.transferOwnership(address(fantasyFootball));
        // Transfer ownership of Squads contract to FantasyFootball
        squads.transferOwnership(address(fantasyFootball));

        // Add some players and teams to Entities
        entities.addTeam("Team A");
        entities.addTeam("Team B");
        entities.addPlayer("Player 1", "Forward", 10 * 1e6, 1);
        entities.addPlayer("Player 2", "Midfielder", 8 * 1e6, 1);
        entities.addPlayer("Player 3", "Defender", 7 * 1e6, 2);
        entities.addPlayer("Player 4", "Goalkeeper", 6 * 1e6, 2);
    }

    function testInitialState() public view {
        assertEq(fantasyFootball.league(), "Test League");
        assertEq(fantasyFootball.currentGameWeek(), 0);
        assertFalse(fantasyFootball.gameWeekActive());
    }

    function testStartGameWeek() public {
        // Mock the askQuestion function
        vm.mockCall(
            address(mockRealityETH),
            abi.encodeWithSelector(IRealityETH.askQuestionWithMinBond.selector),
            abi.encode(bytes32(uint256(1))) // Return a dummy question ID
        );

        vm.prank(owner);
        fantasyFootball.startGameWeek();

        assertEq(fantasyFootball.currentGameWeek(), 1);
        assertTrue(fantasyFootball.gameWeekActive());
    }

    function testStartGameWeekNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        fantasyFootball.startGameWeek();
    }

    function testStartGameWeekAlreadyActive() public {
        vm.startPrank(owner);
        fantasyFootball.startGameWeek();
        vm.expectRevert("Game week already active");
        fantasyFootball.startGameWeek();
        vm.stopPrank();
    }

    function testEndGameWeek() public {
        vm.startPrank(owner);
        fantasyFootball.startGameWeek();
        fantasyFootball.endGameWeek();
        vm.stopPrank();

        assertFalse(fantasyFootball.gameWeekActive());
    }

    function testEndGameWeekNotOwner() public {
        vm.prank(owner);
        console.log("owner test");
        console.logAddress(fantasyFootball.owner());
        fantasyFootball.startGameWeek();

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        fantasyFootball.endGameWeek();
    }

    function testEndGameWeekNotActive() public {
        vm.prank(owner);
        vm.expectRevert("No active game week");
        fantasyFootball.endGameWeek();
    }

    function testCreateSquad() public {
        vm.prank(user1);
        fantasyFootball.createSquad();

        Squads.Squad memory squad = squads.getSquad(user1);
        assertEq(squad.owner, user1);
    }

    function testCreateSquadTwice() public {
        vm.startPrank(user1);
        fantasyFootball.createSquad();
        vm.expectRevert("Squad already exists");
        fantasyFootball.createSquad();
        vm.stopPrank();
    }

    function testGameWeekFlow() public {
        vm.startPrank(owner);
        fantasyFootball.startGameWeek();
        assertEq(fantasyFootball.currentGameWeek(), 1);
        assertTrue(fantasyFootball.gameWeekActive());

        fantasyFootball.endGameWeek();
        assertFalse(fantasyFootball.gameWeekActive());

        fantasyFootball.startGameWeek();
        assertEq(fantasyFootball.currentGameWeek(), 2);
        vm.stopPrank();
    }
}

// Mock RealityETH contract
contract MockRealityETH is IRealityETH {
    function askQuestionWithMinBond(
        uint256,
        string memory,
        address,
        uint32,
        uint32,
        uint256,
        uint256
    ) external payable returns (bytes32) {
        // Return a dummy question ID
        return bytes32(uint256(1));
    }

    // Implement other functions from IRealityETH interface as needed
    // For now, we'll leave them empty as they're not used in our tests
    function resultForOnceSettled(
        bytes32 question_id
    ) external view override returns (bytes32) {}
}
