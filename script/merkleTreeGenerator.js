const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { encodeAbiParameters, parseAbiParameters } = require('viem');

// Assume we have these functions implemented elsewhere
const { fetchSquads, fetchPlayerStats } = require('./dataFetcher');

// Helper function to calculate player score
function calculatePlayerScore(stats) {
    if (!stats.played) {
        return 0;
    }

    let score = 0;

    if (stats.position === "Forward") {
        score += stats.goals * 4;
    } else if (stats.position === "Midfielder") {
        score += stats.goals * 5;
        score += stats.cleanSheet * 1;
    } else if (stats.position === "Defender") {
        score += stats.goals * 6;
        score += stats.cleanSheet * 4;
    } else if (stats.position === "Goalkeeper") {
        score += stats.goals * 6;
        score += stats.cleanSheet * 4;
        score += stats.penaltySaves * 5;
    }

    score += stats.assists * 3;
    score -= stats.penaltyMisses * 2;
    score -= stats.yellowCards * 1;
    score -= stats.redCards * 3;
    score -= stats.ownGoals * 2;

    return Math.max(score, 0); // Ensure the score is never negative
}

// Calculate squad score
function calculateSquadScore(squad, playerStats) {
    let totalScore = 0;
    for (const playerId of squad.players) {
        const stats = playerStats[playerId];
        if (stats && stats.played) {
            let playerScore = calculatePlayerScore(stats);
            if (playerId === squad.captainId) {
                playerScore *= 2;
            } else if (playerId === squad.viceCaptainId && !playerStats[squad.captainId]?.played) {
                playerScore *= 2;
            }
            totalScore += playerScore;
        }
    }
    return totalScore;
}

async function generateMerkleTreeForGameWeek(gameWeek) {
    const squads = await fetchSquads(gameWeek);
    const playerStats = await fetchPlayerStats(gameWeek);

    const squadScores = squads.map(squad => ({
        owner: squad.owner,
        score: calculateSquadScore(squad, playerStats)
    }));

    const leaves = squadScores.map(squadScore =>
        keccak256(encodeAbiParameters(
            parseAbiParameters('address owner, uint256 score'),
            [squadScore.owner, BigInt(squadScore.score)]
        ))
    );

    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const root = tree.getHexRoot();

    console.log(`Merkle Root for Game Week ${gameWeek}:`, root);

    return { tree, squadScores, root };
}

function getProofForSquad(tree, owner, score) {
    const leaf = keccak256(encodeAbiParameters(
        parseAbiParameters('address owner, uint256 score'),
        [owner, BigInt(score)]
    ));
    return tree.getHexProof(leaf);
}

async function main() {
    const gameWeek = 1; // Example game week
    const { tree, squadScores, root } = await generateMerkleTreeForGameWeek(gameWeek);

    // Example: Get proof for a specific squad
    const exampleSquad = squadScores[0];
    const proof = getProofForSquad(tree, exampleSquad.owner, exampleSquad.score);
    console.log(`Proof for Squad ${exampleSquad.owner}:`, proof);

    // You would then send the root to your smart contract
    // and store the proofs for later use when updating squad scores

    // Example of data to be sent to the smart contract for score updates
    const updateData = squadScores.map(squadScore => ({
        owner: squadScore.owner,
        score: squadScore.score,
        proof: getProofForSquad(tree, squadScore.owner, squadScore.score)
    }));

    console.log('Update data:', updateData);
}

main().catch(console.error);