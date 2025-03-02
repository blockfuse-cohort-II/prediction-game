// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Errors {
    error NotOwner();
    error EmptyQuestionText();
    error InvalidDuration();
    error InvalidResolutionWindow();
    error PredictionPeriodEnded();
    error ResolutionWindowExpired();
    error UsernameCannotBeEmpty();
    error InvalidRoi();
    error InvalidDeadline();
    error InvalidAnswer();
    error InvalidStake();
    error InvalidPoolId();
    error DeadlineNotReached();
    error ResultAlreadySet();
    error AnswerNotSet();
    error NoFundsInPool();
    error AlreadyPredicted();
}