// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "solmate/src/auth/Owned.sol";
import "./interfaces/IRealityETH.sol";

/// @title Merkle
/// @notice Manages interactions with Reality.eth for the fantasy football game
/// @dev Handles asking questions and retrieving answers from Reality.eth
contract Merkle is Owned {
    /// @notice Interface for interacting with Reality.eth
    IRealityETH public realityETH;

    /// @notice The arbitrator address for Reality.eth questions
    address public arbitrator;

    /// @notice The timeout period for Reality.eth questions
    uint32 public questionTimeout;

    /// @notice The minimum bond required for Reality.eth questions
    uint256 public minBond;

    /// @notice Struct to represent a squad's score for a game week
    struct SquadScore {
        address owner;
        uint256 points;
    }

    /// @notice Mapping to store Reality.eth question IDs for each game week
    /// @dev gameWeekQuestions[gameWeek] = questionId
    mapping(uint256 => bytes32) public gameWeekQuestions;

    /// @notice Emitted when a question is asked to Reality.eth
    /// @param gameWeek The game week for which the question was asked
    /// @param questionId The ID of the question asked to Reality.eth
    event QuestionAsked(uint256 indexed gameWeek, bytes32 questionId);

    /// @notice Initializes the Merkle contract
    /// @param _realityETH Address of the Reality.eth contract
    /// @param _arbitrator Address of the arbitrator for Reality.eth questions
    /// @param _questionTimeout Timeout period for Reality.eth questions
    /// @param _minBond Minimum bond required for Reality.eth questions
    constructor(IRealityETH _realityETH, address _arbitrator, uint32 _questionTimeout, uint256 _minBond)
        Owned(msg.sender)
    {
        realityETH = _realityETH;
        arbitrator = _arbitrator;
        questionTimeout = _questionTimeout;
        minBond = _minBond;
    }

    /// @notice Asks a question to Reality.eth for the current game week's Merkle root
    /// @param league The league name
    /// @param gameWeek The game week number
    function createGameWeekQuestion(string calldata league, uint256 gameWeek) external onlyOwner {
        string memory question = string(
            abi.encodePacked(
                "What is the merkle root of a merkle tree containing the squad scores for ",
                league,
                " game week ",
                gameWeek,
                "?"
            )
        );

        bytes32 questionId = realityETH.askQuestionWithMinBond(2, question, arbitrator, questionTimeout, 0, 0, minBond);
        gameWeekQuestions[gameWeek] = questionId;
        emit QuestionAsked(gameWeek, questionId);
    }

    /// @notice Retrieves the Merkle root for a specific game week
    /// @param gameWeek The game week number
    /// @return merkleRoot The Merkle root for the game week
    function getGameWeekMerkleRoot(uint256 gameWeek) public view returns (bytes32 merkleRoot) {
        bytes32 questionId = gameWeekQuestions[gameWeek];
        merkleRoot = realityETH.resultForOnceSettled(questionId);
        return merkleRoot;
    }

    /// @notice Verifies a Merkle proof for a squad's score
    /// @param gameWeek The game week number
    /// @param squadScore The SquadScore struct containing the owner's address and points
    /// @param proof The Merkle proof
    /// @return True if the proof is valid, false otherwise
    function verifySquadScore(uint256 gameWeek, SquadScore memory squadScore, bytes32[] memory proof)
        public
        view
        returns (bool)
    {
        bytes32 merkleRoot = getGameWeekMerkleRoot(gameWeek);

        bytes32 leaf = keccak256(abi.encodePacked(squadScore.owner, squadScore.points));
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == merkleRoot;
    }
}
