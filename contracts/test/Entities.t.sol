// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Entities.sol";

contract EntitiesTest is Test {
    Entities public entities;
    address public owner;
    address public user1;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);

        entities = new Entities();
    }

    function testAddTeam() public {
        entities.addTeam("Team A");
        (uint256 id, string memory name) = entities.teams(0);
        assertEq(id, 1);
        assertEq(name, "Team A");
        assertEq(entities.getTeamCount(), 1);
    }

    function testAddTeamNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        entities.addTeam("Team B");
    }

    function testAddPlayer() public {
        entities.addTeam("Team A");
        entities.addPlayer("Player 1", "Forward", 10 * 1e6, 1);

        Entities.Player memory player = entities.player(1);
        assertEq(player.id, 1);
        assertEq(player.name, "Player 1");
        assertEq(player.position, "Forward");
        assertEq(player.price, 10 * 1e6);
        assertEq(player.teamId, 1);
        assertEq(entities.getPlayerCount(), 1);
    }

    function testAddPlayerNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        entities.addPlayer("Player 2", "Midfielder", 8 * 1e6, 1);
    }

    function testUpdatePlayer() public {
        entities.addTeam("Team A");
        entities.addTeam("Team B");
        entities.addPlayer("Player 1", "Forward", 10 * 1e6, 1);

        entities.updatePlayer(1, "Player 1 Updated", "Midfielder", 12 * 1e6, 2);

        Entities.Player memory player = entities.player(1);
        assertEq(player.name, "Player 1 Updated");
        assertEq(player.position, "Midfielder");
        assertEq(player.price, 12 * 1e6);
        assertEq(player.teamId, 2);
    }

    function testUpdatePlayerNotOwner() public {
        entities.addTeam("Team A");
        entities.addPlayer("Player 1", "Forward", 10 * 1e6, 1);

        vm.prank(user1);
        vm.expectRevert("UNAUTHORIZED");
        entities.updatePlayer(1, "Player 1 Updated", "Midfielder", 12 * 1e6, 1);
    }

    function testUpdateNonExistentPlayer() public {
        vm.expectRevert("Player does not exist");
        entities.updatePlayer(1, "Non-existent Player", "Forward", 10 * 1e6, 1);
    }

    function testGetPlayerCount() public {
        assertEq(entities.getPlayerCount(), 0);

        entities.addTeam("Team A");
        entities.addPlayer("Player 1", "Forward", 10 * 1e6, 1);
        entities.addPlayer("Player 2", "Midfielder", 8 * 1e6, 1);

        assertEq(entities.getPlayerCount(), 2);
    }

    function testGetTeamCount() public {
        assertEq(entities.getTeamCount(), 0);

        entities.addTeam("Team A");
        entities.addTeam("Team B");

        assertEq(entities.getTeamCount(), 2);
    }

    function testGetNonExistentPlayer() public view {
        Entities.Player memory player = entities.player(1);
        assertEq(player.id, 0);
        assertEq(player.name, "");
        assertEq(player.position, "");
        assertEq(player.price, 0);
        assertEq(player.teamId, 0);
    }
}
