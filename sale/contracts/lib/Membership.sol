/******************************************************************************
 * COINFLIP MEMBERSHIP DATABASE
 * FLIPCOIN [v1.1.]
 * Created: Aug 04, 2017 16:18
 *
 * Jethro Au
 *
 *
 *
 ******************************************************************************/

/*

  --- Overview
  Membership is a database contract that maintains a ledger of Member-type structs that contains the folloiwng information:
        * userAddress
        * balance
        * joinDate
        * index (in userIndex type)

  The 'key' used in a database is an account hash that is assigned and provided to the user after registered.
  Each entry of a registered-user's CoinFlip account and account hash is also stored locally in CoinFlip's database.


  --- Technical Details:

  The creation of the database adheres to the CRUD cycle (Create, Read, Update, Delete)
  In order to maintain modularity - AUTHORIZATIONS IS NOT IMPLEMENTED IN THIS CONTRACT, BUT IN THE FLIPCOIN20.SOL CONTRACT-

  Storage: The ledger is stored as a private mapping called memberships, mapping a byte32 type to Member struct-type
  Management: The ledger is managed by a key-store called userIndex, which is an unstructure bytes32 array
  Handling: Each change to the database is sequentially handled (enforced by ethereum's transaction ordering)
            and updated in the unstructured userIndex array

  Create - updates memberships mapping, and increases userIndex length
  Read   - retrieves data using the account hash in hash table
  Update - looks Member using account hash and change
  Delete - delete entry of userIndex by replacing the last-index in the unstructured array - this removes the linkage
         - initialize Member data using the delete function in solidity


*/


pragma solidity ^0.4.11;

contract Membership {

  // private is used to prevent child-contract calls
  // hash map of account key - provided by flipcoinsale.com - to member token balance
  mapping(bytes32 => Member) private memberships;

  // index array of account key
  bytes32[] private userIndex;

  // Member is a struct type to track ATM memberships
  // @var: (address) userAddress is the ethereum public key of the token holder
  // @var: (uint)    balance is the token balance of the user
  // @var: (uint)    joinDate is the timestamp of the last update by the the token holder
  struct Member {
    address userAddress;
    uint  balance;
    uint  joinDate;
    uint  index; // <= this
  }

  event LogNewMember    (bytes32 indexed _userHash, uint index, uint joinDate);
  event LogUpdateMember (bytes32 indexed _userHash, uint index, uint joinDate);
  event LogDeleteMember (bytes32 indexed _userHash, uint _rowToDelete);

  ////////////////////////////////////////
  /* -------- Public functions  ---------*/
  ////////////////////////////////////////

  //READ

  // @dev: isMember is public function that returns a boolean type indicating whether a given _userHash is an address
  function isMember(string userHash)
    public
    constant
    returns (bool indeedMember)
  {
    if(userIndex.length == 0){ return false; }
    bytes32 _userHash = stringToBytes32(userHash);
    return (userIndex[memberships[_userHash].index] == _userHash);
  }

  function confirmMemberAccount(string userHash, address _address)
    internal
    constant
    verified(userHash)
    returns(bool confirmed)
  {
    bytes32 _userHash = stringToBytes32(userHash);
    return(memberships[_userHash].userAddress == _address);
  }

  function getMember(string userHash)
    public
    constant
    verified(userHash)
    returns(address _userAddress, uint _balance, uint joinDate, uint index)
  {
    bytes32 _userHash = stringToBytes32(userHash);
    return(
      memberships[_userHash].userAddress,
      memberships[_userHash].balance,
      memberships[_userHash].joinDate,
      memberships[_userHash].index);
  }

  function getMemberCount()
    public
    constant
    returns(uint count)
  {
    return userIndex.length;
  }


  //CREATE
  //
  function verifyMember(
    string userHash,
    address _userAddress,
    uint _balance,
    uint _joinDate)
    not_verified(userHash)
    internal
    returns (uint index)
  {
    bytes32 _userHash = stringToBytes32(userHash);
    memberships[_userHash].userAddress  = _userAddress;
    memberships[_userHash].balance      = _balance;
    memberships[_userHash].joinDate     = _joinDate;
    memberships[_userHash].index        = userIndex.push(_userHash)-1;

    LogNewMember(_userHash,_balance,_joinDate);
    return userIndex.length-1;

  }

  // UPDATE
  //
  function updateBalance(string userHash, uint _balance)
    verified(userHash)
    internal
    returns(bool success)
  {
    bytes32 _userHash = stringToBytes32(userHash);
    memberships[_userHash].balance = _balance;
    LogUpdateMember(
      _userHash,
      memberships[_userHash].index,
      memberships[_userHash].joinDate);
    return true;
  }


  // DELETE
  //
  function deleteMember(string userHash)
    verified(userHash)
    internal
    returns(uint index)
  {
    bytes32 _userHash = stringToBytes32(userHash);
    uint rowToDelete = memberships[_userHash].index;
    bytes32 keyToMove = userIndex[userIndex.length-1];
    userIndex[rowToDelete] = keyToMove;
    memberships[keyToMove].index = rowToDelete;
    userIndex.length--;            // removes pointer index

    delete memberships[_userHash]; // initializes mapping

    LogDeleteMember(_userHash, rowToDelete);

    return rowToDelete;
  }

  ////////////////////////////////////////
  /* -------  Internal Functions  -------*/
  ////////////////////////////////////////

  function stringToBytes32(string memory source)
           private
           returns (bytes32 result) {
      assembly {
          result := mload(add(source, 32))
      }
  }

  ////////////////////////////////////////
  /* -----------  Modifiers  -----------*/
  ////////////////////////////////////////


  modifier not_verified(string _userHash)
  {
    require(!isMember(_userHash));
    _;
  }

  modifier verified(string _userHash)
  {
    require(isMember(_userHash));
    _;
  }

}
