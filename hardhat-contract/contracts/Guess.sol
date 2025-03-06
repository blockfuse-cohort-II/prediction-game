// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./lib/Events.sol";
import "./lib/Errors.sol";

contract GuessGame {
    // State Variables
    address public owner;
    uint8 public constant MAX_NUMBER_OF_LEVELS = 10;
    uint256 public constant QUESTIONS_PER_GAME = 10;
    uint256 public constant POINTS_PER_CORRECT_ANSWER = 10;
    uint256 public constant STREAK_REWARD_POINTS = 50;
    uint256 public constant STREAK_LENGTH = 3;
    uint256 public currentGameId;

    struct Player {
        address playerAddress;
        string username;
        uint256 totalPoints;
        uint256 totalCorrect;
        uint256 currentStreak;
        uint256 stakedAmount;
        // bool hasPlayed;
    }

    struct GameResult {
        address player;
        string username;
        uint256 correctAnswers;
        uint256 totalPoints;
    }

    mapping(address => Player) public players;
    address[] public allPlayers;
    mapping(address => uint8) public gameLevels;
    mapping(uint256 => GameResult[]) public gameResults; // Per-game leaderboard
    mapping(address => uint256[QUESTIONS_PER_GAME]) public userPredictions;
    mapping(address => uint256[QUESTIONS_PER_GAME]) public correctAnswers;
    mapping(address => bool) public resultsGenerated;

    event PredictionsSubmitted(address indexed player, uint256[QUESTIONS_PER_GAME] answers);
    event ResultsGenerated(address indexed player, uint256[QUESTIONS_PER_GAME] correctAnswers);
    event PointsUpdated(address indexed player, uint256 totalCorrect, uint256 totalPoints);
    event StakeWithdrawn(address indexed player, uint256 amount);
    event GameFinished(uint256 gameId);

    constructor() {
        owner = msg.sender;
        currentGameId = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    function setUsername(string memory _username) external {
        require(bytes(_username).length > 0, "Username cannot be empty");

        for (uint256 i = 0; i < allPlayers.length; i++) {
            require(
                keccak256(bytes(players[allPlayers[i]].username)) != keccak256(bytes(_username)),
                "Username already taken"
            );
        }

        if (players[msg.sender].playerAddress == address(0)) {
            players[msg.sender].playerAddress = msg.sender;
            allPlayers.push(msg.sender);
        }

        players[msg.sender].username = _username;
        emit Events.UsernameSet(msg.sender, _username);
    }

    function submitPredictions(uint256[QUESTIONS_PER_GAME] memory answers) external payable {
        // require(!players[msg.sender].hasPlayed, "Already played");
        require(gameLevels[msg.sender] < 10, "Level already completed");
        require(msg.value > 0, "Must stake some ETH");

        userPredictions[msg.sender] = answers;
        players[msg.sender].stakedAmount = msg.value;
        // players[msg.sender].hasPlayed = true;
        gameLevels[msg.sender] += 1;

        _generateCorrectAnswers();
        emit PredictionsSubmitted(msg.sender, answers);
    }

    function _generateCorrectAnswers() internal {
        address player = msg.sender;
        // require(players[player].hasPlayed, "Player has not played");
        uint256[QUESTIONS_PER_GAME] memory generatedAnswers;
        for (uint256 i = 0; i < QUESTIONS_PER_GAME; i++) {
            generatedAnswers[i] = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, player, i))) % 2;
        }
        correctAnswers[player] = generatedAnswers;
        resultsGenerated[player] = true;

        _calculateScore(player);
        emit ResultsGenerated(player, generatedAnswers);
    }

    function _calculateScore(address player) internal {
        require(resultsGenerated[player], "Results not generated");

        Player storage p = players[player];
        uint256 correctCount = 0;
        uint256[QUESTIONS_PER_GAME] memory userAnswers = userPredictions[player];
        uint256[QUESTIONS_PER_GAME] memory generatedAnswers = correctAnswers[player];

        for (uint256 i = 0; i < QUESTIONS_PER_GAME; i++) {
            if (userAnswers[i] == generatedAnswers[i]) {
                correctCount++;
            }
        }

        p.totalCorrect += correctCount;
        p.totalPoints += correctCount * POINTS_PER_CORRECT_ANSWER;

        if (p.currentStreak % STREAK_LENGTH == 0 && correctCount > 0) {
            p.totalPoints += STREAK_REWARD_POINTS;
            emit Events.StreakReward(player, p.currentStreak, STREAK_REWARD_POINTS);
        }

        gameResults[currentGameId].push(GameResult(player, p.username, correctCount, p.totalPoints));
        emit PointsUpdated(player, correctCount, p.totalPoints);
    }

    function finishGame() external onlyOwner {
        currentGameId++;
        emit GameFinished(currentGameId);
    }

    function getGameLeaderboard(uint256 gameId) external view returns (GameResult[] memory) {
        return gameResults[gameId];
    }

    function getGlobalLeaderboard() external view returns (Player[] memory) {
        Player[] memory leaderboard = new Player[](allPlayers.length);
        for (uint256 i = 0; i < allPlayers.length; i++) {
            leaderboard[i] = players[allPlayers[i]];
        }
        return leaderboard;
    }

    function withdrawStake() external {
        Player storage p = players[msg.sender];
        require(resultsGenerated[msg.sender], "Results not generated");
        require(p.stakedAmount > 0, "No stake to withdraw");

        uint256 amount = p.stakedAmount;
        p.stakedAmount = 0;
        
        bool sendSuccess = payable(msg.sender).send(amount);
        require(sendSuccess, "send failed");
        emit StakeWithdrawn(msg.sender, amount);
    }

    function getPlayerDetails(address playerAddress) public view returns (Player memory) {
        return players[playerAddress];
    }

     function getAllCorrectAnswers(
        address player
    ) external view returns (uint256[QUESTIONS_PER_GAME] memory) {
        require(resultsGenerated[player], "Results not generated yet");
        return correctAnswers[player];
    }
}