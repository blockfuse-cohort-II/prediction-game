// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./lib/Events.sol";
import "./lib/Errors.sol";

contract PredictionGame {
    // State Variables
    address public owner;
    uint256 public constant QUESTIONS_PER_GAME = 10;
    uint256 public constant MAX_OPTIONS = 4;
    uint256 public constant POINTS_PER_CORRECT_ANSWER = 10;
    uint256 public constant STREAK_REWARD_POINTS = 50;
    uint256 public constant STREAK_LENGTH = 3;

    struct Player {
        address playerAddress;
        string username;
        uint256 totalPoints;
        uint256 totalCorrect;
        uint256 currentStreak;
        Prediction[] predictionHistory;
    }

    struct Question {
        string text;
        string[MAX_OPTIONS] options;
        uint256 correctAnswer;
        uint256 createdAt;
        uint256 deadline;
        uint256 resolveBy;
        uint256 timeLimit;
        bool resolved;
        uint256 totalStakes;
        mapping(address => uint256) stakes;
        mapping(address => uint256) answers;
        address[] participants;
    }

    struct Prediction {
        uint256 questionId;
        uint256 answer;
        bool correct;
        uint256 timestamp;
    }

    mapping(uint256 => Question) public questions;
    mapping(address => Player) public players;
    address[] public allPlayers;
    uint256 public currentQuestionId;
    address[] public leaderboard;
    uint256 public lastLeaderboardUpdate;

    constructor() {
        owner = msg.sender;
        currentQuestionId = 1;
    }

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert Errors.OnlyOwner();
        _;
    }

    modifier validQuestion(uint256 questionId) {
        if (questionId <= 0 || questionId > currentQuestionId)
            revert Errors.InvalidQuestionID();
        _;
    }

    // Function to set username
    function setUsername(string memory _username) external {
        if (bytes(_username).length == 0) revert Errors.UsernameEmpty();

        // Ensure the username is unique
        for (uint i = 0; i < allPlayers.length; i++) {
            if (
                keccak256(bytes(players[allPlayers[i]].username)) ==
                keccak256(bytes(_username))
            ) {
                revert Errors.UsernameTaken();
            }
        }

        // Register player if new
        if (players[msg.sender].playerAddress == address(0)) {
            players[msg.sender].playerAddress = msg.sender;
            allPlayers.push(msg.sender);
        }

        // Set the username
        players[msg.sender].username = _username;
        emit Events.UsernameSet(msg.sender, _username);
    }

    // Function to create a question (called by backend)
    function createQuestion(
        string memory text,
        string[MAX_OPTIONS] memory options,
        uint256 duration,
        uint256 resolutionWindow,
        uint256 timeLimit
    ) external onlyOwner {
        if (currentQuestionId > QUESTIONS_PER_GAME)
            revert Errors.MaxQuestionsReached();
        if (timeLimit == 0) revert Errors.TimeLimitInvalid();

        Question storage q = questions[currentQuestionId];
        q.text = text;
        q.options = options;
        q.createdAt = block.timestamp;
        q.deadline = block.timestamp + (duration * 1 hours);
        q.resolveBy = q.deadline + (resolutionWindow * 1 hours);
        q.timeLimit = timeLimit;

        emit Events.QuestionCreated(
            currentQuestionId,
            text,
            duration,
            resolutionWindow,
            timeLimit
        );
        currentQuestionId++;
    }

    // Function to predict (stake CORE tokens)
    function predict(
        uint256 questionId,
        uint256 answer
    ) external payable validQuestion(questionId) {
        Question storage q = questions[questionId];
        if (block.timestamp >= q.deadline)
            revert Errors.PredictionPeriodEnded();
        if (block.timestamp > q.createdAt + q.timeLimit)
            revert Errors.TimeLimitExpired();
        if (answer == 0 || answer > MAX_OPTIONS) revert Errors.InvalidAnswer();
        if (q.answers[msg.sender] != 0) revert Errors.AlreadyPredicted();
        if (msg.value == 0) revert Errors.InvalidStakeAmount();

        // Register player if new
        if (players[msg.sender].playerAddress == address(0)) {
            players[msg.sender].playerAddress = msg.sender;
            allPlayers.push(msg.sender);
        }

        // Record prediction
        q.answers[msg.sender] = answer;
        q.stakes[msg.sender] = msg.value;
        q.totalStakes += msg.value;
        q.participants.push(msg.sender);

        emit Events.PredictionSubmitted(
            msg.sender,
            questionId,
            answer,
            msg.value
        );
    }

    // Function to resolve a question (called by backend)
    function resolveQuestion(
        uint256 questionId,
        uint256 correctAnswer
    ) external onlyOwner validQuestion(questionId) {
        Question storage q = questions[questionId];
        if (block.timestamp < q.deadline) revert Errors.DeadlineNotReached();
        if (block.timestamp > q.resolveBy)
            revert Errors.ResolutionWindowExpired();
        if (q.resolved) revert Errors.ResultAlreadySet();
        if (correctAnswer == 0 || correctAnswer > MAX_OPTIONS)
            revert Errors.InvalidCorrectAnswer();

        q.correctAnswer = correctAnswer;
        q.resolved = true;

        _updateScores(questionId);
        _updateLeaderboard();

        emit Events.QuestionResolved(questionId, correctAnswer);
    }

    // Internal function to update scores
    function _updateScores(uint256 questionId) internal {
        Question storage q = questions[questionId];
        uint256 totalCorrect;
        uint256 totalCorrectStakes;

        for (uint i = 0; i < q.participants.length; i++) {
            address participant = q.participants[i];
            if (q.answers[participant] == q.correctAnswer) {
                totalCorrect++;
                totalCorrectStakes += q.stakes[participant];
            }
        }

        if (totalCorrect == 0) return;

        for (uint i = 0; i < q.participants.length; i++) {
            address participant = q.participants[i];
            Player storage p = players[participant];

            if (q.answers[participant] == q.correctAnswer) {
                uint256 stake = q.stakes[participant];
                uint256 reward = (stake * q.totalStakes) / totalCorrectStakes;

                p.totalCorrect++;
                p.currentStreak++;

                // Award points for correct prediction
                p.totalPoints += POINTS_PER_CORRECT_ANSWER;

                // Check for streak reward
                if (p.currentStreak % STREAK_LENGTH == 0) {
                    p.totalPoints += STREAK_REWARD_POINTS;
                    emit Events.StreakReward(
                        participant,
                        p.currentStreak,
                        STREAK_REWARD_POINTS
                    );
                }

                p.totalPoints += reward;
                p.predictionHistory.push(
                    Prediction({
                        questionId: questionId,
                        answer: q.answers[participant],
                        correct: true,
                        timestamp: block.timestamp
                    })
                );

                // Transfer reward in CORE tokens
                (bool success, ) = participant.call{value: reward}("");
                if (!success) revert Errors.CoreTransferFailed();
                emit Events.RewardDistributed(participant, reward);
            } else {
                p.currentStreak = 0;
                p.predictionHistory.push(
                    Prediction({
                        questionId: questionId,
                        answer: q.answers[participant],
                        correct: false,
                        timestamp: block.timestamp
                    })
                );
            }
        }
    }

    // Internal function to update leaderboard
    function _updateLeaderboard() internal {
        // Sort players by points
        for (uint i = 0; i < allPlayers.length; i++) {
            for (uint j = i + 1; j < allPlayers.length; j++) {
                if (
                    players[allPlayers[i]].totalPoints <
                    players[allPlayers[j]].totalPoints
                ) {
                    address temp = allPlayers[i];
                    allPlayers[i] = allPlayers[j];
                    allPlayers[j] = temp;
                }
            }
        }

        // Trim leaderboard to top 100
        if (allPlayers.length > 100) {
            for (uint i = 100; i < allPlayers.length; i++) {
                delete allPlayers[i];
            }
        }

        leaderboard = allPlayers;
        lastLeaderboardUpdate = block.timestamp;
    }

    // Function to get player details
    function getPlayerDetails(
        address playerAddress
    ) public view returns (Player memory) {
        return players[playerAddress];
    }

    // Function to get leaderboard
    function getLeaderboard()
        public
        view
        returns (address[] memory, string[] memory, uint256[] memory)
    {
        address[] memory sorted = new address[](leaderboard.length);
        string[] memory usernames = new string[](leaderboard.length);
        uint256[] memory scores = new uint256[](leaderboard.length);

        for (uint i = 0; i < leaderboard.length; i++) {
            sorted[i] = leaderboard[i];
            usernames[i] = players[leaderboard[i]].username;
            scores[i] = players[leaderboard[i]].totalPoints;
        }

        return (sorted, usernames, scores);
    }
}
