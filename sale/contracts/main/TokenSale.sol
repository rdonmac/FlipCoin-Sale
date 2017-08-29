/**********************************************************
* FLIPCOIN TOKEN SALE
* CAPPED CROWDSALE
* Created: July 20, 2017 12:30
*
* Jethro Au (@jethroau)
* Jack Kasbeer (@jcksber)
*
*
 **********************************************************/


pragma solidity ^0.4.11;

import "../lib/Auth.sol";
import "../lib/Exec.sol";
import "../lib/SafeMath.sol";
import "./Flipcoin20.sol";

contract CoinflipSale is Auth, SafeMath {

    Flipcoin20      public  Flipcoin;             // Flipcoin: Token being sold

    uint            public  totalSupply;          // Total FlipCoin amount created
    uint            public  foundersAllocation;   // Amount given to founders
    uint            public  saleAllocation;       // Total amount of sellable tokens

    address         public  foundersWallet;       // wallet address of founder

    uint            public  startTime;
    uint            public  endTime;
    uint            public  duration;

    uint            public  price;                // (FLP/ETH) Default sale price of Flipcoin  - triggered if GetPrice comparisons fail
    uint            public  tierOne;              // (FLP/ETH) Token Tier-one price, triggered at start of sale (FLP/ETH)
    uint            public  tierTwo;              // (FLP/ETH) Token Tier-two price, triggered after tierOneLimit threshold exceeded (FLP/ETH)
    uint            public  tierThree;            // (FLP/ETH) Token Tier-three price, triggered after tierTwoLimit threshhold exceeded (FLP/ETH)

    uint            internal  tierOneLimit;         // tierOne price threshold
    uint            internal  tierTwoLimit;         // tierTwo price threshold
    uint            internal  tierThreeLimit;       // tierThree price threshold

    uint            public  totalMinted   = 0;    // total # of tokens minted, denomianted in 0 decimals for clarity
    uint            public  weiAmount     = 0;    // total amount of ether raised

    bool            public  saleFinalized = false;          // has Coinflip sale finalized?
    bool            public  saleStopped   = false;          // has Coinflip stopped selling?

    uint            public  fundingMinimum;                 // minimum-funding amount in Wei

    uint  constant  internal  decimalMultiplier    = 10**18 ;     // ether-to-Wei conversion
    /*uint  constant  internal  MINIMUM_TOKEN_SUPPLY = 5000000; // MINIMUM ETHER supply - Refer to Coinflip Sale subsection*/

    mapping (address => uint)                       public  userBuys;
    mapping (bytes32 => uint)                       public  transactionMap;

    event LogBuy            (address user, uint amount);
    event LogFinalized      ();
    event LogStopped        ();
    event LogOpened         ();
    event LogMinimumReached ();
    event LogCapReached     ();


    ////////////////////////////////////////
    /* ---------- Coinflip Sale --------- */
    ////////////////////////////////////////


    // @dev:  Contract creator needs to input the following correct parameters.
    // @param: (uint) _startTime is the timestamp of when the crowdsale would start.
    // @param: (uint) duration is the length of crowdsale - IN DAYS -
    // @param: (address) _foundersWallet is the address of the founder's cold storage wallet. Funds would be redirected to this address
    // @param: (uint) _fundingMinimum is the minimum ether funding amount in Wei.
    // @notice: Although there are checks during contract construction, Flipcoin contract creator requires due diligence.

    function CoinflipSale(
        uint     _startTime,
        uint     _duration,
        address  _foundersWallet,
        uint     _fundingMinimum
    ) {
        startTime          = _startTime;
        duration           = _duration;
        endTime            = _startTime + (_duration * 1 days);
        foundersWallet     = _foundersWallet;
        fundingMinimum     = _fundingMinimum * 1 ether;

        totalSupply        = 0;                  // Total number of tokens minted  (in 18 decimal places)
        totalMinted        = 0;                  // Initial Mint amount is         (in 0 decimal places)
        saleAllocation     = 50000000;           // Total number of tokens minted  (in 0 decimal places)

        price              = 2500  ;             // - FALL BACK PRICE                  - 0.12 USD/FLP
        tierOne            = 3750 ;              // - ADJUSTED 1 HOUR BEFORE CROWDSALE - 0.08  USD/FLP
        tierTwo            = 3000 ;              // - ADJUSTED 1 HOUR BEFORE CROWDSALE - 0.1  USD/FLP
        tierThree          = 2500 ;              // - ADJUSTED 1 HOUR BEFORE CROWDSALE - 0.12 USD/FLP

        tierOneLimit       = 10000000;           // - MAY ADJUST - first 10 MIL of total tokens sold @ tierOne price in Wei
        tierTwoLimit       = 30000000;           // - MAY ADJUST - next 30 MIL of total tokens sold @ tierTwo price in Wei
        tierThreeLimit     = 10000000;           // - MAY ADJUST  - last 10 MILof total tokens sold @ tierThree price in Wei

        // Sanity checks
        assert(startTime >= time());
        assert(endTime >= startTime);
        assert(_foundersWallet != 0x0);
        assert(_fundingMinimum >= 0);

    }


    function initializeToken()
             auth
             public
    {
      // Creates Flipcoin
      Flipcoin = new Flipcoin20();

      // Set Founder
      setFounder();
    }

    ////////////////////////////////////////
    /* ---------- Token Buying  --------- */
    ////////////////////////////////////////

    // @dev: Main buying function for token sale. Calls buyInternal function with sender address

    function Buy() public payable
    {
       buyInternal(msg.sender);
    }

    // @dev: ProxyBuy allows a third-party to pay on behalf of a future token-holder.
    // @param: (address) address of the receiver

    function ProxyBuy(address reciever) public payable
    {
       buyInternal(reciever);
    }

    // @dev: fallback function calls call ProxyBuy function
    // @notice: SET TRANSACTION GAS LIMIT TO 200,000

    function () public payable {
       ProxyBuy(msg.sender);
    }


    ////////////////////////////////////////
    /* ------- Internal Functions ------- */
    ////////////////////////////////////////

    // @dev: isBetween is an internal function that determines if the supplied value is in between the lower and upper bound
    // @param: (uint) _lowerBound is the lower bound for domain logic
    // @param: (uint) _upperBound is the upper bound for domain logic
    // @param: (uint) _value is the value being compared to

    function isBetween(uint _lowerBound, uint _upperBound, uint _value)
             internal
             returns (bool)
    {
      return (_value > _lowerBound && _value <= _upperBound);
    }


   // @dev: withinCap  is an internal function that determines whether if the incoming transaction will be in-cap or out
   // @param: (uint) _totalSupply: total supply of tokens created in 18 DECIMALS
   // @param: (uint) _amount: ether value in Wei (18 DECIMALS)
   // @notice: comparison logic is conducted with a multiplier - DECIMALS

   function withinCap(uint _totalSupply, uint _amount)
            internal
            returns (bool)
   {
      uint newTotal = add(_totalSupply, _amount);
      if (newTotal <= mul(saleAllocation,decimalMultiplier))
      {
        return true;
      }
      else
      {
        LogCapReached();
        return false;
      }
   }

   // @dev: getPrice is a public function that receives the total supply of tokens minted
   //       and returns the given price level
   // @param: (uint) total # of tokens minted

   function getPrice(uint _totalMinted)
            internal
            returns (uint)
   {
       assert  (_totalMinted >= 0);

       if      (isBetween(0,tierOneLimit,_totalMinted) || _totalMinted == 0)    { return tierOne;   }
       else if (isBetween(tierOneLimit, tierTwoLimit,_totalMinted))             { return tierTwo;   }
       else if (isBetween(tierTwoLimit, tierThreeLimit,_totalMinted))           { return tierThree; }
       else                                                                     { return price;     }

   }

   // @dev: time is an internal function that returns the UNIX timestamp of the current block
   function time()
            constant
            internal
            returns (uint)
   {
      return block.timestamp;
   }

   /*// @dev: hasReachedMinimum is an internal functiont hat returns true if the totalMinted has reached
   function hasReachedMinimum()
            internal
            returns (bool)
   {
      return (totalMinted >= MINIMUM_TOKEN_SUPPLY);
   }*/


   // @dev: minReached is an internal function that returns true if the minimum ether amount has been raised

   function minReached()
            internal
            constant
            returns (bool) {
     if (weiAmount >= fundingMinimum)
     {
       LogMinimumReached();
       return true;
     } else {return false;}
   }

   /////////////////////////////////////////
   /* -------- Private Functions -------- */
   ////////////////////////////////////////


   // @dev: buyInternal is an internal function that receives ether and assigns
   //       Flipcoins to contributer
   // @param: (address) address of contributer

   function buyInternal(address _address)
       private
       during_sale_period
       not_finalized
       not_stopped
       non_zero_address(_address)
       min_eth
   {

       // Price calculation
       uint salePrice = getPrice(totalMinted);
       uint reward = mul(salePrice, msg.value);

       // Capped crowdsale at 50 million tokens sold
       require(withinCap(totalSupply, reward));

       //Update metrics
       weiAmount += msg.value * 1 ether;
       userBuys[_address] += reward;

       //Assign Flipcoins to investor
       assignFlipcoin(msg.sender,reward);

       //Push ether to foundersWallet
       sendToWallet(msg.value);

   }


   // @dev: assignFlipcoin is a private function that mints contributer given amount in wei-FLP amount
   // @param: (address) address of token receiver
   // @param: (uint) the amount of flipcoins in wei-FLP conversion
   // @notice: totalSupply logged in total token mint volume - denominated to 18 decimal places
   // @notice: minumum eth deposit is 0.01 ether. Base price is >= 100, upholding uint type

   function assignFlipcoin(address receiver, uint amount)
            auth
            private
   {
     Flipcoin.mint(receiver, amount);

     // update 18 decimal balance
     totalSupply = add(totalSupply, amount);

     // update 0 decimal balance
     uint tokenAmount = div(amount,decimalMultiplier);
     totalMinted = add(totalMinted,tokenAmount);

     //Trigger LogBuy Event
     LogBuy(msg.sender, tokenAmount);

   }

   // @dev: internalFinalize is a private function finalizes the sale, and is called by the finalizeSale function
   // @notice: if the minimum token amount is reached, Flipcoin will retain 10% of all tokens minted


  /*
          If minimum is reached, Flipcoin retains 5% or 1/20 of all tokens minted.

          ------TotalMinted is hence 19/20 of total supply - and founders allocation is 1/20 of total minted.
          ------   using basic algebra - founder allocation is hence 1/19 of total supply
          ------   to calculate founder's portion, totalMinted is multiplied by 10**18 decimal places (our token decimal point)
          ------   and then divided by 19.

  */
   function internalFinalize()
            auth
            private
   {
       uint tokenAmount;

       if (minReached())
       {
         foundersAllocation = div(mul(totalMinted, decimalMultiplier),19);
         assignFlipcoin(foundersWallet, tokenAmount);
       }

       saleFinalized = true;
       saleStopped   = true;
       Flipcoin.finalized();
   }


   // @dev: sendToWallet is a private function that forwards the contract ether to founder's MultiSig Wallet
   function sendToWallet(uint balance)
            auth
            private
   {
       uint amount = balance;
       if (!foundersWallet.send(amount)) {  revert(); }
   }

   // @dev: Alias to setOwner in auth
   function setFounder()
            auth
            private
   {
        super.setFounder(foundersWallet);
   }

   ////////////////////////////////////////
   //* -------- Owner Functions -------- */
   ////////////////////////////////////////

   // @notice: All owner functions are public and MUST have the 'auth' modifier
   // @notice: All owner functions must have the not_finalized modifier
   // @dev: emergecyStop is a public function that allows the contract owner to stop the token
   // -------in an unexpected event. The sale can only stopped during the token sale.
   function emergencyStop()
            auth
            during_sale_period
            not_stopped
            not_finalized
            public
   {
      saleStopped = true;
      LogStopped();
   }

   // @dev: after stopping crowdsale, the contract owner can restart the crowdsale
   // @notice: - restartSale is a one-way function - contract can be only restarted once

   function restartSale()
            auth
            not_finalized
            public
    {
      saleStopped = false;
      LogOpened();
    }

   // @dev: finalizeSale is a public function that finalizes the sale
   // @notice: in order to protect the interest of investors, crowdsale can only be finalized

   function finalizeSale()
            auth
            not_finalized
            public
   {
      internalFinalize();
   }


   // @dev: setPrice is a public function that allows the owner to adjust token price before sale starts

   function setPriceFromEth(uint _ethPrice)
            auth
            before_sale_start
            not_finalized
            public
  {
      tierOne   = div(mul(100,_ethPrice),8);        // 0.08 USD/FLP Conversion
      tierTwo   = div(mul(100,_ethPrice),10);       // 0.10 USD/FLP Conversion
      tierThree = div(mul(100,_ethPrice),12);       // 0.12 USD/FLP Conversion
      price     = div(mul(100,_ethPrice),12);
  }


  // dev: ownerMint is a function that is only called by owner that allows the contract to mint on backend
  // @param: (bytes32) _transactionHash
  // @notice: this function is ONLY used for BTC payments to crowdsale. This is a back-up function
  // @notice: backendMint requires Bitcoin's transaction hash to be submitted along with every mint for public verification
  // @notice: for cash deposits - a hash form of the payments-details would be used - contact us for more info.

  function ownerMint(bytes32 _transactionHash, uint _amount, address receiver)
           auth
           not_finalized
  {
    uint tokenDecimal = mul(_amount,decimalMultiplier);
    require(withinCap(totalSupply,tokenDecimal));
    assert(!(transactionMap[_transactionHash] > 0));
    transactionMap[_transactionHash] = _amount;
    assignFlipcoin(receiver, tokenDecimal);

  }


  ////////////////////////////////////////
  /* ----------- Modifiers  ----------- */
  ////////////////////////////////////////

   modifier during_sale_period
   {
      assert(time() >= startTime);
      assert(time() <= endTime);
      _;
   }

   modifier before_sale_start
   {
     assert(time() < startTime);
     _;
   }

    modifier after_sale_start
    {
      assert(time() >= startTime);
      _;
    }

   modifier after_sale_closed
   {
     assert(time() > endTime || saleStopped);
     _;
   }

   modifier non_zero_address(address _address)
   {
     require(_address != 0x0);
     _;
   }

   modifier min_reached
   {
     require(minReached());
     _;
   }

   modifier not_finalized
   {
     assert(!saleFinalized);
     _;
   }

   modifier not_stopped
   {
     assert(!saleStopped);
     _;
   }

   modifier has_stopped
   {
     assert(saleStopped);
     _;
   }

   modifier min_eth
   {
     require(msg.value >= 0.01 ether);
     _;
   }

}
