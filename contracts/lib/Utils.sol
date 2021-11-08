// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

library Utils{

    function hash(bytes memory data)internal pure returns(bytes32){
        return keccak256(data);
    }
    function toString(bytes memory data)internal pure returns(string memory){
        return string(data);
    }
    function toString(bool data)internal pure returns(string memory){
        if(data) return "true";
        else return "false";
    }
    function toBytes(string memory data)internal pure returns(bytes memory){
        return bytes(data);
    }
    function toAddress(string memory data)internal pure returns(address){
        bytes memory tmp = bytes(data);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
    function toUint(string memory s)internal pure returns(uint){
        bytes memory b = bytes(s);
        uint i;
        uint counterBeforeDot;
        uint counterAfterDot;
        uint result = 0;
        uint totNum = b.length;
        totNum--;
        bool hasDot = false;

        for (i = 0; i < b.length; i++) {
            uint c = uint(uint8(b[i]));

            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
                counterBeforeDot ++;
                totNum--;
            }

            if(c == 46){
                hasDot = true;
                break;
            }
        }

        if(hasDot) {
            for (uint j = counterBeforeDot + 1; j < 18; j++) {
                uint m = uint(uint8(b[j]));

                if (m >= 48 && m <= 57) {
                    result = result * 10 + (m - 48);
                    counterAfterDot ++;
                    totNum--;
                }

                if(totNum == 0){
                    break;
                }
            }
        }
        if(counterAfterDot < 18){
            uint addNum = 18 - counterAfterDot;
            uint multuply = 10 ** addNum;
            return result = result * multuply;
        }

        return result;
    }
    function equals(string memory a, string memory b)internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
    function isEmpty(string memory a)internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((""))));
    }
    function checkBytes(string memory str)internal pure returns(bool){
        return bytes(str).length != 0;
    }
    function checkAddress(address a)internal pure returns(bool){
        return a == address(a);
    }
    function stringToBool(string memory data)internal pure returns(bool){
        if(keccak256(abi.encodePacked(data)) == keccak256(abi.encodePacked("true")))return true;
        else return false;
    }
}