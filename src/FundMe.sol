// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {PriceConverter} from "./PriceConverter.sol";

// ETH/USD - Sepolia
// 0x694AA1769357215DE4FAC081bf1f309aDC325306

// ETH/USD - zkSync-sepolia
// 0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF

error FundMe__NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5e18;
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    address[] private s_funders;
    mapping(address funder => uint256 fundedAmount) private s_addressToFundedAmount;

    //////Constructor
    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    ////Fund Function
    function fund() public payable {
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD, "Insufficient funds");

        s_funders.push(msg.sender);
        s_addressToFundedAmount[msg.sender] += msg.value;
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    modifier onlyOwner() {
        //require(msg.sender == i_owner, "You are not the owner of this contract!");
        if (msg.sender != i_owner) {
            revert FundMe__NotOwner();
        } //for more gas efficiency
        _;
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 funderLength = s_funders.length;
        for (uint256 funderIndex = 0; funderIndex < funderLength; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToFundedAmount[funder] = 0;
        }

        uint256 balance = address(this).balance;

        (bool callSuccess,) = payable(msg.sender).call{value: balance}("");
        require(callSuccess, "Call failed");
    }

    function withdraw() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToFundedAmount[funder] = 0;
        }

        s_funders = new address[](0);

        uint256 balance = address(this).balance;

        //transfer
        // payable (msg.sender).transfer(balance);

        //send
        // bool sendSuccess = payable (msg.sender).send(balance);
        // require(sendSuccess, "Send failed");

        //call
        //You may want to use Checks-Effects-Interactions pattern and Re-entrancy Guards for safety.
        //import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
        (bool callSuccess,) = payable(msg.sender).call{value: balance}("");
        require(callSuccess, "Call failed");
    }

    //receive function
    receive() external payable {
        fund();
    }

    //fallback function
    fallback() external payable {
        fund();
    }

    //view pure functions (getters)

    function getAddressToFundedAmount(address fundingAddress) external view returns (uint256) {
        return s_addressToFundedAmount[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getFunders() external view returns (address[] memory) {
        return s_funders;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
