/******************************************************************************
 * COINFLIP MEMBERSHIP TOKEN
 * FLIPCOIN [v1.0.0]
 * Created: July 17, 2017 04:18
 *
 * Jethro Au
 * Jack Kasbeer
 *
 *
 ******************************************************************************/
import "../lib/Stoppable.sol";
import "../lib/Security.sol";
import "../lib/SafeMath.sol";
import "../lib/Membership.sol";
import "./Flipcoin_Standard.sol";

pragma solidity ^0.4.11;


contract Flipcoin20 is Stoppable, Membership, Flipcoin_Standard(0) {

    // Name the token
    string public name = "Flipcoin";
    // Declare symbol
    string public symbol = "ATM";
    // Assign decimal #
    uint8 public decimals = 18; // standard

    // minting lock
    bool  public mintingLocked = false;

    // Founder address
    address public Founder = 0x0A9237Cd0F52834dBD4576F1A944Cdf3Fb3E2e97;

    // mapping of address to boolean flag of whether an address is verified
    // all boolean flags are defaulted to false
    mapping(address => bool) transferLock;

    event Mint(address _to, uint256 amount);
    event MintFinished();

    // constructor function call
    // locks all trading activity until called otherwise
    function Flipcoin20()
    {
      return stop();
    }

    // Receive ether != bueno
    function () { revert(); }

    /////////////////////////////
    /*--------STOPPABLE--------*/
    /////////////////////////////

    /*

    FLIPCOINS ARE UN-TRADEABLE UNTIL SALE IS FINALIZED
    - all functions in this sub-section must have the stoppable modifier
    - all functions in this sub-section must have transfer_not_locked modifier

    */


    // ERC20 call forwards
    function transfer(address dst, uint pot)
             stoppable
             transfer_not_locked(msg.sender)
             note
             returns (bool)
    {

        return super.transfer(dst, pot);
    }


    function transferFrom(address src, address dst, uint pot)
             stoppable
             transfer_not_locked(msg.sender)
             note
             returns (bool)
    {
      return super.transferFrom(src, dst, pot);
    }

    // Alis to approve
    function approve(address addy, uint pot)
             stoppable
             transfer_not_locked(msg.sender)
             note returns (bool)
    {
        return super.approve(addy, pot);
    }


    // Alias to transfer
    function push(address dst, uint pot)
             stoppable
             transfer_not_locked(msg.sender)
             returns (bool)
    {
        return transfer(dst, pot);
    }

    // Alias to transferFrom
    function pull(address src, uint pot)
             stoppable
             transfer_not_locked(msg.sender)
             returns (bool) {
        return transferFrom(src, msg.sender, pot);
    }


    /////////////////////////////
    /*--------MINTING--------*/
    /////////////////////////////

    /*

    ALL FUNCTIONS BELOW ARE FOR MINTING PURPOSES AND WILL BE USED ONLY DURING CROWDSALE
    - all functions below must have minting_not_locked modifier
    - mint function is only used during crowdsale period

    */


    // Create Flipcoins in msg.sender
    function mint(address reciever, uint pot)
             auth
             minting_not_locked
             note
    {
        _balances[reciever] = add(_balances[reciever], pot);
        _supply = add(_supply, pot);
        Mint(reciever, pot);
    }

    // lock minting - can be only called once
    function finalized()
             auth
             minting_not_locked
             returns (bool)
    {
      mintingLocked = true; // No one can mint - including founders and owners
      super.start();

      setFounder(Founder);

      MintFinished();
      return true;
    }

    // modifier for mint lock -- to be only used for mint function
    modifier minting_not_locked
    {
      require(!mintingLocked);
      _;
    }


    /*-----MODIFIERS -----*/
    modifier minting_locked
    {
      require(mintingLocked);
      _;
    }

    /////////////////////////////
    /*--MEMBERSHIP MANAGEMENT--*/
    /////////////////////////////

    /*
      IF TOKEN IS VERIFIED, TOKENS WILL BE LOCKED UNTIL DELETED.
      THIS IS FOR SECURITY PURPOSES

      The following porton is used for membership management
      *modifers inherited: verifed, not_verifed
      *functions: isMember, getMemberCount, getMember, deleteMember, updateBalance, verifyMember

    */

    /*-----AUTHORITY : ALL-----*/
    // function to verify a new Member - LOCKS TOKENS
    function Verify(bytes32 userHash)
             not_verified(userHash,msg.sender)
             public
             returns (bool success)
    {
        uint _balance = super.balanceOf(msg.sender);
        uint _time    = block.timestamp;
        super.verifyMember(userHash,msg.sender,_balance,_time);
        transferLock[msg.sender] = true;
        return true;
    }

    // Alias to getMember
    function GetMember(bytes32 userHash)
             public
             returns(address _userAddress, uint _balance, uint joinDate, uint index)
    {
      return super.getMember(userHash);
    }

    // Alias to getMemberCount
    function MemberCount()
             public
             returns (uint count)
    {
      return super.getMemberCount();
    }

    /*-----AUTHORITY : MEMBER ONLY -----*/
    // UPDATE AND DELETE FUNCTIONS

    // function to update Member - MUST HAVE confirmMemberAccount FUNCTION
    function UpdateMember(bytes32 userHash)
             public
             returns (bool success)
    {
      require(super.confirmMemberAccount(userHash,msg.sender));
      uint _balance = super.balanceOf(msg.sender);
      return (super.updateBalance(userHash,_balance));
    }


    // function to deleteMember - MUST HAVE onlyMember MODIFIER
    // UNLOCKS TOKENS
    function DeleteMember(bytes32 userHash)
             public
             returns (bool success)
    {
        require(super.confirmMemberAccount(userHash,msg.sender));
        super.deleteMember(userHash);
        transferLock[msg.sender] = false;
        return true;

    }


    /*-----AUTHORITY : OWNER ONLY -----*/

    // Owner call to verify remote userHash
    // function to verify a new Member - LOCKS TOKENS
    function Verify_Owner(bytes32 userHash, address _address)
             not_verified(userHash,_address)
             public
             returns (bool success)
    {
        uint _balance = super.balanceOf(_address);
        uint _time    = block.timestamp;
        super.verifyMember(userHash,_address,_balance,_time);
        transferLock[_address] = true;
        return true;
    }


    // function to update Member - MUST HAVE onlyMember MODIFIER
    // must have auth modifier
    function UpdateMember_Owner(bytes32 userHash, address _address)
             auth
             public
             returns (bool success)
    {
      uint _balance = super.balanceOf(_address);
      return (super.updateBalance(userHash,_balance));
    }

    // Owner call to delete backend - MUST HAVE auth MODIFIER
    // UNLOCKS TOKENS
    function DeleteMember_Owner(bytes32 userHash)
             auth
             public
             returns (bool success)
    {
      super.deleteMember(userHash);
      transferLock[msg.sender] = false;
      return true;
    }

    function DeAuthenticate_Owner(address _address)
             auth
             public
             returns (bool success)
    {
      super.registered[_address] = false;
      return true;
    }


  /*-----MODIFIERS -----*/

    // modifier to allow transfers - transfers would only be locked after verifying
    modifier transfer_not_locked(address _address)
    {
      require(!transferLock[_address]);
      _;
    }


}
