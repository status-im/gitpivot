pragma solidity ^0.4.11;

import "./common/strings.sol";


/** 
 * @title JSONHelper 
 * Abstract Logic for JSON responses from Oracle
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH) 
 */
contract JSONHelper {
    
    function getCredentialString(string _clientId, string _clientSecret) internal returns (string cred) {
        strings.slice[] memory cm = new strings.slice[](4);
        cm[0] = strings.toSlice("?client_id=");
        cm[1] = strings.toSlice(_clientId);
        cm[2] = strings.toSlice("&client_secret=");
        cm[3] = strings.toSlice(_clientSecret);
        cred = strings.join(cm);
    }

    function getNextString(bytes _str, uint256 _pos) internal pure returns (string str, uint256 next) {
        var (start, end) = findStringBounds(_str, _pos);
        str = string(copyBytesPart(_str, start, end));
        next = findNextChar(_str, end, ",") + 1;
    }

    function getNextAddr(bytes _str, uint256 _pos) internal pure returns (address, uint256) {
        uint160 iaddr = 0;
        uint len = _str.length;
        for (; len > _pos; _pos++) {
            byte bp = _str[_pos];
            if (bp == "0") {
                if (_str[_pos+1] == "x") {
                    for (_pos = _pos+2; _pos < 2 + 2 * 20; _pos += 2) {
                        iaddr *= 256;
                        iaddr += (uint160(hexVal(uint160(_str[_pos])))*16+uint160(hexVal(uint160(_str[_pos+1]))));
                    }
                    _pos++; 
                    break;
                }
            }else if (bp == ",") {
                _pos++; 
                break; 
            } 
        }
        return (address(iaddr), _pos);
    }

    function getNextUInt(bytes _str, uint256 _pos) internal pure returns (uint, uint256) {
        uint val = 0;
        uint len = _str.length;
        for (; len > _pos; _pos++) {
            byte bp = _str[_pos];
            if (bp == ",") {//Find ends
                _pos++; 
                break;
            } else if ((bp >= 48) && (bp <= 57)) { //only ASCII numbers
                val *= 10;
                val += uint(bp) - 48;
            }
        }
        return (val, _pos);
    }

    function hexVal(uint val) internal pure returns (uint) {
        return val - (val < 58 ? 48 : (val < 97 ? 55 : 87));
    }

    function copyBytesPart(bytes _src, uint256 _start, uint256 _end) private pure returns (bytes res) {
        uint256 len = _end - _start;
        res = new bytes(len);
        for (uint i = 0; i < len; i++) {
            res[i] = _src[_start + i];
        }
    }

    /**
     * @dev Finds next char. Retuns _str length case not found.
     */
    function findNextChar(bytes _str, uint256 _start, byte _char) private pure returns(uint256 pos) {
        uint256 len = _str.length;
        for (pos = _start + 1; pos < len; pos++) {
            if (_str[pos] == _char) {
                return pos;
            }
        }
    }

    /**
     * @dev Finds JSON string bounds: first unescaped " and next unescaped" . Returns 0,0 case not found.
     * @param _str The converted to bytes string. 
     * @param _offset The search offset into _str
     */
    function findStringBounds(bytes _str, uint256 _offset) private pure returns (uint256 start, uint256 end) {
        uint256 len = _str.length;
        for (uint256 _pos = _offset; _pos < len; _pos++) {
            if (_str[_pos] == "\"") {
                if (_pos == 0 || _str[_pos-1] != "\\") { //is not escaped
                    end = start == 0 ? 0 : _pos;
                    start = start == 0 ? (_pos+1) : start;
                    if (end > 0) {
                        return (start, end);
                    }
                }
            }
        }
        return (0, 0);
    }
}