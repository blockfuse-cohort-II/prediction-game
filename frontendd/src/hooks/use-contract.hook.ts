import { useState, useEffect } from "react";
import {
  useWriteContract,
  useReadContract,
  useAccount,
  BaseError,
} from "wagmi";
import rawAbi from "../abi/GuessGame.json";
import toast from "react-hot-toast";
import { parseEther } from "viem";

const abi = rawAbi.abi;
const CONTRACT_ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS;

export const useGuessGame = () => {
  const { isConnected, address } = useAccount();
  const [transactionStatus, setTransactionStatus] = useState<string | null>(null);
  const { writeContract, isPending, data: hash, error } = useWriteContract();

  useEffect(() => {
    if (hash) {
      setTransactionStatus("success");
    }
    if (error) {
      toast.error(error.message ?? "Transaction failed. Please try again.");
    }
  }, [hash, error]);

  /**
   * Submit predictions and stake ETH.
   */
  const submitPredictions = async (
    predictions: number[],
    stakeAmount: number
  ) => {
    if (!isConnected) {
      toast.error("Please connect your wallet first.");
      return;
    }
    if (predictions.length !== 10) {
      toast.error("Invalid number of predictions.");
      return;
    }
    if (stakeAmount <= 0) {
      toast.error("You must stake some ETH.");
      return;
    }

    try {
      writeContract({
        address: CONTRACT_ADDRESS,
        abi,
        functionName: "submitPredictions",
        args: [predictions],
        value: parseEther(stakeAmount.toString()), // Convert ETH to Wei
      });
    } catch (err: unknown) {
      if (err instanceof BaseError) {
        toast.error(err.shortMessage || err.message);
      }
    }
  };

  /**
   * Withdraw the staked ETH.
   */
  const withdrawStake = async () => {
    if (!isConnected) {
      toast.error("Please connect your wallet first.");
      return;
    }

    try {
      writeContract({
        address: CONTRACT_ADDRESS,
        abi,
        functionName: "withdrawStake",
        args: [],
      });
    } catch (err: unknown) {
      if (err instanceof BaseError) {
        toast.error(err.shortMessage || err.message);
      }
    }
  };

  /**
   * Fetch player details from the smart contract.
   */
  const { data: playerData, refetch: getPlayerDetails } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi,
    functionName: "getPlayerDetails",
    args: address ? [address] : undefined,
  });

  /**
   * Fetch the game leaderboard.
   */
  const { data: gameLeaderboard, refetch: getGameLeaderboard } =
    useReadContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: "getGameLeaderboard",
      args: address ? [address] : undefined,
    });

  /**
   * Fetch the global leaderboard.
   */
  const { data: globalLeaderboard, refetch: getGlobalLeaderboard } =
    useReadContract({
      address: CONTRACT_ADDRESS,
      abi,
      functionName: "getGlobalLeaderboard",
      args: address ? [address] : undefined,
    });

  return {
    submitPredictions,
    withdrawStake,
    getPlayerDetails,
    getGameLeaderboard,
    getGlobalLeaderboard,
    playerData,
    gameLeaderboard,
    globalLeaderboard,
    transactionStatus,
    isPending
  };
};

export const useUsername = () => {
  const [transactionStatus, setTransactionStatus] = useState<string | null>(
    null
  );
  const [errorMessage, setErrorMessage] = useState("");
  const { isConnected } = useAccount();
  const { data: hash, isPending, writeContract, error } = useWriteContract();

  useEffect(() => {
    if (hash) {
      setTransactionStatus("Transaction successful!");
    }
    if (error) {
      toast.error(error.message ?? "Transaction failed. Please try again.");
    }
  }, [hash, error]);

  /**
   * Handles setting the username in the smart contract.
   */
  const setUsernameOnChain = async (username: string) => {
    if (!isConnected) {
      toast.error("Please connect your wallet first.");
      return;
    }
    if (!username.trim()) {
      toast.error("Username cannot be empty.");
      return;
    }
    if (username.length < 4) {
      toast.error("Username must be at least 4 characters long!");
      return;
    }

    setTransactionStatus(null);
    setErrorMessage("");

    try {
      writeContract({
        address: CONTRACT_ADDRESS,
        abi,
        functionName: "setUsername",
        args: [username],
      });
    } catch (err: unknown) {
      if (err instanceof BaseError) {
        setErrorMessage(err.shortMessage || err.message);
      }
    }
  };

  return {
    setUsernameOnChain,
    isPending,
    transactionStatus,
    errorMessage,
  };
};
