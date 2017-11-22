pragma solidity ^0.4.15;

import "../common/Controlled.sol";

/**
 * @title Archive
 * @author Ricardo Guilherme Schmidt (Status Research & Development GmbH)
 */
contract Archive is Controlled {

    mapping(bytes32 => address) addressMap;
    mapping(bytes32 => bytes32) bytes32Map;
    mapping(bytes32 => uint) uIntMap;
    mapping(bytes32 => int) intMap;
    mapping(bytes32 => bool) boolMap;
    mapping(bytes32 => string) stringMap;
    mapping(bytes32 => bytes) bytesMap;

    /**
     * Getters
     */

    function getAddress(bytes32 _uid) public constant returns (address) {
        return addressMap[_uid];
    }
    
    function getBytes32(bytes32 _uid) public constant returns (bytes32) {
        return bytes32Map[_uid];
    }

    function getUInt(bytes32 _uid) public constant returns (uint) {
        return uIntMap[_uid];
    }
    
    function getInt(bytes32 _uid) public constant returns (int) {
        return intMap[_uid];
    }

    function getBoolean(bytes32 _uid) public constant returns (bool) {
        return boolMap[_uid];
    }

    function getString(bytes32 _uid) public constant returns (string) {
        return stringMap[_uid];
    }
    
    function getBytes(bytes32 _uid) public constant returns (bytes) {
        return bytesMap[_uid];
    }
    
    /**
     * Setters
     */

    function putAddress(bytes32 _uid, address value) public onlyController {
        addressMap[_uid] = value;
    }

    function putUInt(bytes32 _uid, uint value) public onlyController {
        uIntMap[_uid] = value;
    }

    function putInt(bytes32 _uid, int value) public onlyController {
        intMap[_uid] = value;
    }

    function putBoolean(bytes32 _uid, bool value) public onlyController {
        boolMap[_uid] = value;
    }

    function putBytes32(bytes32 _uid, bytes32 value) public onlyController {
        bytes32Map[_uid] = value;
    }

    function putString(bytes32 _uid, string value) public onlyController {
        stringMap[_uid] = value;
    }

    function putBytes(bytes32 _uid, bytes value) public onlyController {
        bytesMap[_uid] = value;
    }

    /**
     * Deleters
     */

    function deleteAddress(bytes32 _uid) public onlyController {
        delete addressMap[_uid];
    }

    function deleteBytes32(bytes32 _uid) public onlyController {
      delete bytes32Map[_uid];
    }

    function deleteUInt(bytes32 _uid) public onlyController {
      delete uIntMap[_uid];
    }

    function deleteInt(bytes32 _uid) public onlyController {
        delete intMap[_uid];
    }

    function deleteBoolean(bytes32 _uid) public onlyController {
        delete boolMap[_uid];
    }

    function deleteString(bytes32 _uid) public onlyController {
        delete stringMap[_uid];
    }

    function deleteBytes(bytes32 _uid) public onlyController {
        delete bytesMap[_uid];
    }

}