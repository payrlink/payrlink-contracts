// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PayrLink is Ownable {
    mapping (string => address) public factories;   // Address of each factories with factory name
    // factory name should be capitalized

    /**
        @notice Get address of factory contract
        @param name Factory name
     */
    function getFactory(string memory name) public view returns ( address ) {
        return factories[name];
    }

    /**
        @notice Set and update the address of factories
        @param _name Factory name
        @param _factoryAddress Factory contract address
     */
    function setFactory(string memory _name, address _factoryAddress) public onlyOwner {
        factories[_name] = _factoryAddress;
    }
}