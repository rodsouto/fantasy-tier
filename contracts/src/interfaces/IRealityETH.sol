// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRealityETH {
    function askQuestionWithMinBond(
        uint256 template_id,
        string memory question,
        address arbitrator,
        uint32 timeout,
        uint32 opening_ts,
        uint256 nonce,
        uint256 min_bond
    ) external payable returns (bytes32);

    function resultForOnceSettled(
        bytes32 question_id
    ) external view returns (bytes32);
}
