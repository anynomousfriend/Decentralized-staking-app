// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    // Mapping to track each staker's balance
    mapping(address => uint256) public balances;
    // Total amount staked in the contract
    uint256 public totalStaked;
    // Threshold to determine success state (1 ETH)
    uint256 public constant threshold = 1 ether;
    // Deadline timestamp for staking period
    uint256 public deadline;
    // Flag to open withdrawals if threshold not met
    bool public openForWithdraw;
    // Ensure execute() can only run once
    bool public executed;

    // Event emitted when a stake is made
    event Stake(address indexed user, uint256 amount);

    // Modifier: only before deadline
    modifier beforeDeadline() {
        require(block.timestamp < deadline, "Staking period is over");
        _;
    }

    // Modifier: only after deadline
    modifier afterDeadline() {
        require(block.timestamp >= deadline, "Deadline not reached");
        _;
    }

    // Modifier: only if external contract not completed
    modifier notCompleted() {
        require(!exampleExternalContract.completed(), "Already completed");
        _;
    }

    /// @notice Constructor sets the external contract and staking deadline
    /// @param exampleExternalContractAddress Address of the external contract
    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
        deadline = block.timestamp + 72 hours;
    }

    /// @notice Stake ETH into the contract before the deadline
    function stake() public payable beforeDeadline {
        require(msg.value > 0, "Must stake non-zero amount");

        balances[msg.sender] += msg.value;
        totalStaked += msg.value;

        emit Stake(msg.sender, msg.value);
        console.log("Stake:", msg.sender, msg.value);
    }

    /// @notice Accept ETH sent directly and forward to stake()
    receive() external payable {
        stake();
    }

    /// @notice Returns remaining time (in seconds) until deadline
    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    /// @notice After deadline, transition to success or withdraw state
    function execute() public afterDeadline notCompleted {
        require(!executed, "Already executed");
        executed = true;

        if (address(this).balance >= threshold) {
            // Success: send all Ether to external contract
            exampleExternalContract.complete{value: address(this).balance}();
        } else {
            // Failure: open withdrawals
            openForWithdraw = true;
        }
    }

    /// @notice Withdraw staked ETH if threshold not met
    function withdraw() public afterDeadline notCompleted {
        require(openForWithdraw, "Withdrawals not open");

        uint256 userBalance = balances[msg.sender];
        require(userBalance > 0, "No balance to withdraw");

        balances[msg.sender] = 0;
        payable(msg.sender).transfer(userBalance);
    }
}
