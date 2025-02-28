// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "abdk-libraries-solidity/ABDKMathQuad.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @custom:oz-upgrades-from OldTool
contract Tool is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private constant DECIMALS = 1e18;
    uint256 public constant SECONDS_PER_BLOCK = 6;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function LnUint256(uint256 value) public pure returns (uint256) {
        bytes16 v = ABDKMathQuad.ln(ABDKMathQuad.fromUInt(value));
        return getLnValue(v);
    }

    function getLnValue(bytes16 value) public pure returns (uint256) {
        return ABDKMathQuad.toUInt(ABDKMathQuad.mul(value, ABDKMathQuad.fromUInt(DECIMALS)));
    }

    function safeDiv(uint256 a, uint256 b) public pure returns (uint256) {
        require(b > 0, "Division by zero");

        bytes16 scaledA = ABDKMathQuad.fromUInt(a * DECIMALS);

        bytes16 result = ABDKMathQuad.div(scaledA, ABDKMathQuad.fromUInt(b));

        return ABDKMathQuad.toUInt(result);
    }

    function getDecimals() public pure returns (uint256) {
        return DECIMALS;
    }

    function contains(bytes memory str, bytes memory substr) internal pure returns (bool) {
        if (str.length < substr.length) {
            return false;
        }
        for (uint256 i = 0; i <= str.length - substr.length; i++) {
            bool find = true;
            for (uint256 j = 0; j < substr.length; j++) {
                if (bytes1(str[i + j]) != bytes1(substr[j])) {
                    find = false;
                    break;
                }
            }
            if (find) {
                return true;
            }
        }
        return false;
    }

    function hasNumberGreaterThan20(string memory str) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        uint256 num = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] >= "0" && strBytes[i] <= "9") {
                num = num * 10 + (uint8(strBytes[i]) - uint8(bytes1("0")));
            } else if (num != 0) {
                if (num >= 20) {
                    return true;
                }
                num = 0;
            }
        }
        return num > 20;
    }

    function checkString(string memory text) public pure returns (bool) {
        bool hasNvidia = contains(bytes(text), bytes("NVIDIA"));

        bool has = hasNumberGreaterThan20(text);

        return hasNvidia && has;
    }
}
