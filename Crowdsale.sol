pragma solidity ^0.4.18;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error.
 */
library SafeMath {

    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;
    }

    /**
     * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }

}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization
 *      control functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

    // Public variable with address of owner
    address public owner;

    /**
     * Log ownership transference
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the
     *      contract to the sender account.
     */
    function Ownable() public {
        // Set the contract creator as the owner
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        // Check that sender is owner
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) onlyOwner public {
        // Check for a non-null owner
        require(newOwner != address(0));
        // Log ownership transference
        OwnershipTransferred(owner, newOwner);
        // Set new owner
        owner = newOwner;
    }

}


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}


/**
 * @title Mango Token contract.
 * @dev Custom ERC20 compatible token.
 */
contract MangoToken is ERC20Basic, Ownable {

    using SafeMath for uint256;

    /**
     * BasicToken data.
     */
    uint256 public totalSupply_ = 0;
    mapping(address => uint256) balances;

    /**
     * StandardToken data.
     */
    mapping (address => mapping (address => uint256)) internal allowed;

    /**
     * MintableToken data.
     */
    bool public mintingFinished = false;

    /**
     * CappedToken data.
     */
    uint256 public cap = 40000000000000000000000000;
    // --------------------------^

    /**
     * DetailedERC20 data.
     */
    string public name     = "Mango";
    string public symbol   = "MNG";
    uint8  public decimals = 18;

    /**
     * MangoToken data.
     *
     * Pre-Sale start: Thu, 01 Mar 2018 13:00:00 +0000 (UTC) UNIX: 1519909200 (-)
     * Pre-Sale end:   Tue, 20 Mar 2018 13:00:00 +0000 (UTC) UNIX: 1521550800
     * ICO Sale start: Wed, 21 Mar 2018 13:00:00 +0000 (UTC) UNIX: 1521637200
     * ICO Sale end:   Sat, 21 Apr 2018 13:00:00 +0000 (UTC) UNIX: 1524315600 (*) (-)
     * Public Release: Mon, 21 May 2018 13:00:00 +0000 (UTC) UNIX: 1526907600 (+)
     * Team Release:   Fri, 21 Sep 2018 13:00:00 +0000 (UTC) UNIX: 1537534800 (+)
     * (*) Team minting released.
     * (-) Dates relevant to contract creation.
     * (+) Dates relevant to contract locking functionality.
     */
    mapping (address => bool) partners;
    mapping (address => bool) blacklisted;
    mapping (address => bool) freezed;
    uint256 public publicRelease   = 1526907600; // Mon, 21 May 2018 13:00:00 +0000 (UTC)
    uint256 public partnersRelease = 1537534800; // Fri, 21 Sep 2018 13:00:00 +0000 (UTC)

    /**
     * ERC20Basic events.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * ERC20 events.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * MintableToken events.
     */
    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    /**
     * BurnableToken events.
     */
    event Burn(address indexed burner, uint256 value);

    /**
     * MangoToken events.
     */
    event UpdatedPublicReleaseDate(uint256 date);
    event UpdatedPartnersReleaseDate(uint256 date);
    event Blacklisted(address indexed account);
    event Freezed(address indexed investor);
    event PartnerAdded(address indexed investor);
    event PartnerRemoved(address indexed investor);
    event Unfreezed(address indexed investor);

    /**
     * Initialize token contract.
     */
    function MangoToken() public {
        assert(publicRelease < partnersRelease); // Public realease date must be before partner's realease date.
        assert(0 < cap && totalSupply_ == 0);    // Ensure contract validity.
    }

    /**
     * MintableToken modifiers.
     */

    modifier canMint() {
        require(!mintingFinished);
        _;
    }

    /**
     * ERC20Basic interface.
     */

    /**
     * @dev Gets the total raised token supply.
     */
    function totalSupply() public view returns (uint256 total) {
        return totalSupply_;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param investor The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address investor) public view returns (uint256 balance) {
        return balances[investor];
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param to The address which you want to transfer to.
     * @param amount The amount of tokens to be transferred.
     * @return A boolean that indicates if the operation was successful.
     */
    function transfer(address to, uint256 amount) public returns (bool success) {
        require(!freezed[msg.sender] && !blacklisted[msg.sender]);
        require(to != address(0) && !freezed[to] && !blacklisted[to]);
        require((!partners[msg.sender] && now >= publicRelease) || now >= partnersRelease);
        require(0 < amount && amount <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[to] = balances[to].add(amount);
        Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * ERC20 interface.
     */

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param holder The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address holder, address spender) public view returns (uint256 remaining) {
        return allowed[holder][spender];
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     *      Beware that changing an allowance with this method brings the risk that someone may use both
     *      the old and the new allowance by unfortunate transaction ordering. One possible solution to
     *      mitigate this race condition is to first reduce the spender's allowance to 0 and set the
     *      desired value afterwards.
     * @param spender The address which will spend the funds.
     * @param amount The amount of tokens to be spent.
     * @return A boolean that indicates if the operation was successful.
     */
    function approve(address spender, uint256 amount) public returns (bool success) {
        allowed[msg.sender][spender] = amount;
        Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param amount The amount of tokens to be transferred.
     * @return A boolean that indicates if the operation was successful.
     */
    function transferFrom(address from, address to, uint256 amount) public returns (bool success) {
        require(!blacklisted[msg.sender]);
        require(to != address(0) && !freezed[to] && !blacklisted[to]);
        require(from != address(0) && !freezed[from] && !blacklisted[from]);
        require((!partners[from] && now >= publicRelease) || now >= partnersRelease);
        require(0 < amount && amount <= balances[from]);
        require(amount <= allowed[from][msg.sender]);
        balances[from] = balances[from].sub(amount);
        balances[to] = balances[to].add(amount);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(amount);
        Transfer(from, to, amount);
        return true;
    }

    /**
     * StandardToken interface.
     */

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * @param spender The address which will spend the funds.
     * @param amount The amount of token to be decreased, in fraction units.
     * @return A boolean that indicates if the operation was successful.
     */
    function decreaseApproval(address spender, uint256 amount) public returns (bool success) {
        uint256 oldValue = allowed[msg.sender][spender];
        if (amount > oldValue) {
            allowed[msg.sender][spender] = 0;
        } else {
            allowed[msg.sender][spender] = oldValue.sub(amount);
        }
        Approval(msg.sender, spender, allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     *      approve should be called when allowance(owner, spender) == 0. To
     *      increment allowed value is better to use this function to avoid 2
     *      calls (and wait until the first transaction is mined).
     * @param spender The address which will spend the funds.
     * @param amount The amount of token to be increased, in fraction units.
     * @return A boolean that indicates if the operation was successful.
     */
    function increaseApproval(address spender, uint amount) public returns (bool success) {
        allowed[msg.sender][spender] = allowed[msg.sender][spender].add(amount);
        Approval(msg.sender, spender, allowed[msg.sender][spender]);
        return true;
    }

    /**
     * MintableToken interface.
     */

    /**
     * @dev Function to mint tokens to investors.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint, in fraction units.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address to, uint256 amount) onlyOwner canMint public returns (bool success) {
        require(!freezed[to] && !blacklisted[to] && !partners[to]);
        return mintTokens(to, amount);
    }

    /**
     * @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() onlyOwner public returns (bool success) {
        mintingFinished = true;
        MintFinished();
        return true;
    }

    /**
     * GrantableToken interface.
     */

    /**
     * @dev Function to mint tokens to team members.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint, in fraction units.
     * @return A boolean that indicates if the operation was successful.
     */
    function grant(address to, uint256 amount) onlyOwner canMint public returns (bool success) {
        require(!freezed[to] && !blacklisted[to] && partners[to]);
        return mintTokens(to, amount);
    }

    function mintTokens(address to, uint256 amount) internal returns (bool) {
        require(0 < amount && totalSupply_.add(amount) <= cap);
        totalSupply_ = totalSupply_.add(amount);
        balances[to] = balances[to].add(amount);
        Transfer(address(0), to, amount);
        Mint(to, amount);
        return true;
    }

    /**
     * BurnableToken interface.
     */

    /**
     * @dev Burns a specific amount of tokens.
     * @param amount The amount of token to be burned, in fraction units.
     * @return A boolean that indicates if the operation was successful.
     */
    function burn(uint256 amount) public returns (bool success) {
        require(!freezed[msg.sender]);
        require((!partners[msg.sender] && now >= publicRelease) || now >= partnersRelease);
        require(0 < amount && amount <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        totalSupply_ = totalSupply_.sub(amount);
        Transfer(msg.sender, address(0), amount);
        Burn(msg.sender, amount);
        return true;
    }

    /**
     * MangoToken interface.
     */

    /**
     * Add a new partner.
     * Marks an investor account as member of the team. Locking dates for team members
     * will be applied to this account. In order an account can be marked as a partner,
     * it need to have no token in its current balance, otherwise, the operation will
     * fail.
     * WARNING: Investor who will buy tokens must use another account to have public
     * locking privileges, otherwise, tokens minted to the account will be locked until
     * partnersRelease date.
     */
    function addPartner(address investor) onlyOwner public returns (bool) {
        require(investor != address(0));
        require(!partners[investor] && !blacklisted[investor] && balances[investor] == 0);
        partners[investor] = true;
        PartnerAdded(investor);
        return partners[investor];
    }

    /**
     * Remove a partner.
     * Removes an investor account from the team. In order an account can be removed from
     * the partners list, it need to have no token in its current balance, otherwise, the
     * operation will fail.
     */
    function removePartner(address investor) onlyOwner public returns (bool) {
        require(partners[investor] && balances[investor] == 0);
        partners[investor] = false;
        PartnerRemoved(investor);
        return !partners[investor];
    }

    function isPartner(address investor) public view returns (bool) {
        return partners[investor];
    }

    /**
     * Freeze permanently an investor.
     * WARNING: This will burn out any token sold to the blacklisted account.
     * No refund will be done to blacklisted investor.
     */
    function blacklist(address account) onlyOwner public returns (bool) {
        require(account != address(0));
        require(!blacklisted[account]);
        blacklisted[account] = true;
        uint256 amount = balances[account];
        balances[account] = 0;
        totalSupply_ = totalSupply_.sub(amount);
        Transfer(account, address(0), amount);
        Burn(account, amount);
        Blacklisted(account);
        return blacklisted[account];
    }

    /**
     * Freeze (temporarily) an investor.
     */
    function freeze(address investor) onlyOwner public returns (bool) {
        require(investor != address(0));
        require(!freezed[investor]);
        freezed[investor] = true;
        Freezed(investor);
        return freezed[investor];
    }

    /**
     * Unfreeze an investor.
     */
    function unfreeze(address investor) onlyOwner public returns (bool) {
        require(freezed[investor]);
        freezed[investor] = false;
        Unfreezed(investor);
        return !freezed[investor];
    }

    /**
     * @dev Set a new release date for investor's transfers.
     *      Must be executed before the current release date, and the new
     *      date must be a later one. Up to one more week for security reasons.
     * @param date UNIX timestamp of the new release date for investor's transfers.
     * @return True if the operation was successful.
     */
    function setPublicRelease(uint256 date) onlyOwner public returns (bool success) {
        require(now < publicRelease && publicRelease < date);
        require(date.sub(publicRelease) <= 604800);
        publicRelease = date;
        assert(publicRelease <= partnersRelease);
        UpdatedPublicReleaseDate(date);
        return true;
    }

    /**
     * @dev Set a new release date for partners' transfers.
     *      Must be executed before the current release date, and the new
     *      date must be a later one. Up to one more week for security reasons.
     * @param date UNIX timestamp of the new release date for partners' transfers.
     * @return True if the operation was successful.
     */
    function setPartnersRelease(uint256 date) onlyOwner public returns (bool success) {
        require(now < partnersRelease && partnersRelease < date);
        require(date.sub(partnersRelease) <= 604800);
        partnersRelease = date;
        assert(publicRelease <= partnersRelease);
        UpdatedPartnersReleaseDate(date);
        return true;
    }

}


/**
 * @title MangoVault
 * @dev This contract is used for storing funds while a crowdsale
 * is in progress. Supports refunding the ether if crowdsale fails,
 * and forwarding it if crowdsale is successful. It also supports
 * withdrawing the ether while the crowdsale is in progress and
 * the soft goal was reached, i.e., provided no refunding will be
 * required anymore. In other words, refunding and withdrawing are
 * mutually exclusive.
 */
contract MangoVault is Ownable {

    using SafeMath for uint256;

    enum State { Active, Withdrawing, Refunding, Closed }

    /**
     * WithdrawableRefundVault data.
     */
    mapping (address => uint256) public deposited_;
    address public wallet;
    State public state;

    /**
     * WithdrawableRefundVault events.
     */
    event Closed();
    event Deposited(address indexed beneficiary, uint256 amount);
    event Refunded(address indexed beneficiary, uint256 amount);
    event RefundsEnabled();
    event WithdrawsEnabled();
    event Withdrawed(uint256 amount);

    /**
     * Initialize vault contract.
     */
    function MangoVault(address store) public {
        require(store != address(0));
        wallet = store;
        state = State.Active;
    }

    /**
     * WithdrawableRefundVault modifiers.
     */
    modifier canRefund() {
        require(state == State.Refunding);
        _;
    }

    modifier canWithdraw() {
        require(state == State.Withdrawing);
        _;
    }

    /**
     * WithdrawableRefundVault interface.
     */

    function close() onlyOwner public {
        require(state < State.Refunding);
        state = State.Closed;
        Closed();
        wallet.transfer(this.balance);
    }

    function deposit(address investor) onlyOwner public payable {
        require(state < State.Refunding);
        deposited_[investor] = deposited_[investor].add(msg.value);
        Deposited(investor, msg.value);
    }

    function enableRefunds() onlyOwner public {
        require(state == State.Active);
        state = State.Refunding;
        RefundsEnabled();
    }

    function enableWithdraws() onlyOwner public {
        require(state == State.Active);
        state = State.Withdrawing;
        WithdrawsEnabled();
    }

    function refund(address investor) canRefund public {
        require(0 < deposited_[investor]);
        uint256 amount = deposited_[investor];
        deposited_[investor] = 0;
        investor.transfer(amount);
        Refunded(investor, amount);
    }

    /**
     * Owner can withdraw ether here.
     */
    function withdraw(uint256 amount) onlyOwner canWithdraw public {
        require(amount <= this.balance);
        wallet.transfer(amount);
        Withdrawed(amount);
    }

    /**
     * MangoVault interface.
     */

    function depositOf(address investor) public view returns (uint256 deposited) {
        return deposited_[investor];
    }

}


/**
 * @title Mango Crowdsale contract. (Gas limit: 5687032, price: 20)
 * @dev This is a capped, refundable, pauseable and finalizeable
 * crowdsale. It also support three level bonus.
 */
contract MangoCrowdsale is Ownable {

    using SafeMath for uint256;

    /**
     * Standard crowdsale data.
     * - start and end timestamps where investments are allowed (left inclusive)
     * - how many token units a buyer gets per wei
     * - amount of raised money in wei
     */
    uint256 public startTime;
    uint256 public endTime;
    uint256 public rate = 9000; // 9000 MNG / 1 ETH || 9000 MNG*10^-18 / 1 WEI
    uint256 public weiRaised;

    /**
     * CappedCrowdsale data.
     */
    uint256 public cap;

    /**
     * RefundableCrowdsale data.
     */
    uint256 public goal = 100000000000000000000; // 100 ETH minimum amount of funds to be raised in weis.
    //-----------------------^

    /**
     * MangoCrowdsale data.
     *
     * Pre-Sale start: Thu, 01 Mar 2018 13:00:00 +0000 (UTC) UNIX: 1519909200 (-)
     * Pre-Sale end:   Tue, 20 Mar 2018 13:00:00 +0000 (UTC) UNIX: 1521550800 (-)
     * ICO Sale start: Wed, 21 Mar 2018 13:00:00 +0000 (UTC) UNIX: 1521637200
     * ICO Sale end:   Sat, 21 Apr 2018 13:00:00 +0000 (UTC) UNIX: 1524315600 (*)
     * Public Release: Mon, 21 May 2018 13:00:00 +0000 (UTC) UNIX: 1526907600 (+)
     * Team Release:   Fri, 21 Sep 2018 13:00:00 +0000 (UTC) UNIX: 1537534800 (+)
     * (*) Team minting released.
     * (-) Dates relevant to contract creation.
     * (+) Dates relevant to contract locking functionality.
     */
    uint256 public presaleBegin = 1519909200; // Thu, 01 Mar 2018 13:00:00 +0000 (UTC)
    uint256 public presaleEnd   = 1521550800; // Tue, 20 Mar 2018 13:00:00 +0000 (UTC)
    uint256 public pubsaleBegin = 1521637200; // Wed, 21 Mar 2018 13:00:00 +0000 (UTC)
    uint256 public pubsaleEnd   = 1524315600; // Sat, 21 Apr 2018 13:00:00 +0000 (UTC)

    uint256 public presaleCap = 10000000000000000000000000;
    uint256 public pubsaleCap = 40000000000000000000000000;
    // ---------------------------------^

    uint256 public minimum;
    uint256 public presaleMin = 1000000000000000000; // 1 ETH == 1*10^18 WEI.
    uint256 public pubsaleMin = 0; // No minimum buy.
    // --------------------------^

    uint256 public relaySupply  = 2000000000000000000000000; // Locked 1 month.
    uint256 public bountySupply =  800000000000000000000000; // .
    uint256 public legalSupply  =  400000000000000000000000; // .
    uint256 public teamSupply   = 2800000000000000000000000; // Locked 5 months.
    // ----------------------------------^

    uint256[3] bonusPercent;
    uint256[3] bonusMinimum;

    enum State { Standby, Active, Paused, Finalized }      // *** State machine ***
    State public state;                                    // current state.
    enum Stage { Suspended, Presale, Pubsale, Terminated } // ...
    Stage public stage;                                    // current stage.

    MangoToken public token; // The token being sold.
    MangoVault public vault; // The vault holding the funds, support refunding.

    /**
     * Standard crowdsale events.
     */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /**
     * FinalizableCrowdsale events.
     */
    event Finalized();

    /**
     * MangoCrowdsale events.
     */
    event Grant(uint i, address indexed to, uint256 amount);
    event Initialized();
    event Paused();
    event PresaleEnded();
    event PresaleStarted();
    event PubsaleEnded();
    event PubsaleStarted();
    event Resumed();
    event UpdatedBonusRate(uint i, uint256 value, uint256 percent);
    event UpdatedMinimumBuy(uint256 value);
    event UpdatedPubsalePeriod(uint256 start, uint256 end);
    event UpdatedPresalePeriod(uint256 start, uint256 end);
    event UpdatedSaleRate(uint256 value);

    /**
     * Initialize crowdsale contract.
     */
    function MangoCrowdsale() public {
        require(now <= presaleBegin);              // Must be created before presale begins.
        require(presaleBegin < presaleEnd);        // Start date must be before end date.
        require(pubsaleBegin < pubsaleEnd);        // .
        require(presaleEnd < pubsaleBegin);        // Presale ends before Pubsale begins.
        require(0 < rate && 0 < goal);             // Ensure contract validity.
        require(weiRaised == 0);                   // .
        require(0 < presaleCap && 0 < pubsaleCap); // .
        state = State.Standby;
        stage = Stage.Suspended;
    }

    /**
     * MangoCrowdsale modifiers.
     */

    modifier canGrant() {
        require(now >= pubsaleEnd);
        _;
    }

    modifier toBounty() {
        require(0 < bountySupply);
        _;
    }

    modifier toLegal() {
        require(0 < legalSupply);
        _;
    }

    modifier toRelay() {
        require(0 < relaySupply);
        _;
    }

    modifier toTeam() {
        require(0 < teamSupply);
        _;
    }

    /**
     * MangoCrowdsale interface.
     */

    /* Gas limit: 2009560, price: 20 */
    function initialize(address wallet) onlyOwner public {
        require(wallet != address(0));
        token = new MangoToken();
        vault = new MangoVault(wallet);
        Initialized();
        assert(pubsaleEnd < token.publicRelease()); // Team minting realease date must be before public realease date.
    }

    /* Gas limit: 230404, price: 20 */
    function start() onlyOwner public {
        require(now <= presaleBegin);
        require(stage == Stage.Suspended && state == State.Standby);
        state = State.Active;
        startTime = presaleBegin;
        endTime = presaleEnd;
        cap = presaleCap;
        minimum = presaleMin;
        bonusMinimum[0] = uint256(  1000000000000000000); //   1 ETH
        bonusPercent[0] = uint256(33);                    //  33 %
        bonusMinimum[1] = uint256( 20000000000000000000); //  20 ETH
        bonusPercent[1] = uint256(39);                    //  39 %
        bonusMinimum[2] = uint256(100000000000000000000); // 100 ETH
        bonusPercent[2] = uint256(49);                    //  49 %
        stage = Stage.Presale;
        PresaleStarted();
    }

    function launch() onlyOwner public {
        require(stage == Stage.Presale && state == State.Active);
        require(hasEnded());// && now <= pubsaleBegin
        PresaleEnded();
        startTime = pubsaleBegin;
        endTime = pubsaleEnd;
        cap = pubsaleCap;
        minimum = pubsaleMin;
        bonusMinimum[0] = uint256(15000000000000000000);
        bonusPercent[0] = uint256(15);
        bonusMinimum[1] = bonusMinimum[0];
        bonusPercent[1] = bonusPercent[0];
        bonusMinimum[2] = bonusMinimum[0];
        bonusPercent[2] = bonusPercent[0];
        stage = Stage.Pubsale;
        PubsaleStarted();
    }

    function setRate(uint256 mngPerWei) onlyOwner public returns (bool success) {
        require(0 < mngPerWei);
        rate = mngPerWei;
        UpdatedSaleRate(mngPerWei);
        return true;
    }

    function setMinimumBuy(uint256 minWei) onlyOwner public returns (bool success) {
        require(0 <= minWei);
        minimum = minWei;
        UpdatedMinimumBuy(minWei);
        return true;
    }

    function setBonusRate(uint i, uint256 minWei, uint256 percent) onlyOwner public returns (bool success) {
        require(0 <= i && i <= 2);
        require(0 < minWei && 0 <= percent);
        bonusMinimum[i] = minWei;
        bonusPercent[i] = percent;
        UpdatedBonusRate(i, minWei, percent);
        return true;
    }

    /**
     * @dev Set a new end date for public sale.
     *      Must be executed before the current date, and the new date must be
     *      a later one. Up to one more week for security reasons.
     * @param date UNIX timestamp of the new release date for public sale end.
     * @return True if the operation was successful.
     */
    function setPublicsaleEnd(uint256 date) onlyOwner public returns (bool success) {
        require(now < pubsaleEnd && pubsaleEnd < date);
        require(date.sub(pubsaleEnd) <= 604800);
        pubsaleEnd = date;
        token.setPublicRelease(date.add(2592000));    // 1 month after
        token.setPartnersRelease(date.add(13219200)); // 5 months after
        if (stage == Stage.Pubsale) {
            endTime = date;
        }
        UpdatedPubsalePeriod(pubsaleBegin, date);
        return true;
    }

    function setPublicsaleBegin(uint256 date) onlyOwner public returns (bool success) {
        require(now < pubsaleBegin && pubsaleBegin < date);
        require(date.sub(pubsaleBegin) <= 604800);
        pubsaleBegin = date;
        if (stage == Stage.Pubsale) {
            startTime = date;
        }
        assert(pubsaleBegin < pubsaleEnd);
        UpdatedPubsalePeriod(date, pubsaleEnd);
        return true;
    }

    function setPresaleEnd(uint256 date) onlyOwner public returns (bool success) {
        require(now < presaleEnd && presaleEnd < date);
        require(date.sub(presaleEnd) <= 604800);
        presaleEnd = date;
        if (stage == Stage.Presale) {
            endTime = date;
        }
        assert(presaleEnd < pubsaleBegin);
        UpdatedPresalePeriod(presaleBegin, date);
        return true;
    }

    function setPresaleBegin(uint256 date) onlyOwner public returns (bool success) {
        require(now < presaleBegin && presaleBegin < date);
        require(date.sub(presaleBegin) <= 604800);
        presaleBegin = date;
        if (stage == Stage.Presale) {
            startTime = date;
        }
        assert(presaleBegin < presaleEnd);
        UpdatedPresalePeriod(date, presaleEnd);
        return true;
    }

    /**
     * @dev Set a new release date for investor's transfers.
     *      Must be executed before the current release date, and the new
     *      date must be a later one. Up to one more week for security reasons.
     * @param date UNIX timestamp of the new release date for investor's transfers.
     * @return True if the operation was successful.
     */
    function setPublicRelease(uint256 date) onlyOwner public returns (bool success) {
        return token.setPublicRelease(date);
    }

    /**
     * @dev Set a new release date for partners' transfers.
     *      Must be executed before the current release date, and the new
     *      date must be a later one. Up to one more week for security reasons.
     * @param date UNIX timestamp of the new release date for partners' transfers.
     * @return True if the operation was successful.
     */
    function setPartnersRelease(uint256 date) onlyOwner public returns (bool success) {
        return token.setPartnersRelease(date);
    }

    function hasStarted() public view returns (bool) {
        return startTime <= now;
    }

    function withinPeriod() public view returns (bool) {
        //return (hasStarted() && !endReached());
        return (startTime <= now && now < endTime);
    }

    function endReached() public view returns (bool) {
        // afterPeriod
        return endTime <= now;
    }

    function capReached() public view returns (bool) {
        return cap <= token.totalSupply();
    }

    function pause() onlyOwner public returns (bool success) {
        require(state == State.Active);
        //pausing();
        state = State.Paused;
        Paused();
        return true;
    }

    //function pausing() internal {
        // NOOP
    //}

    function isPaused() public view returns (bool) {
        return (state == State.Paused);
    }

    function resume() onlyOwner public returns (bool success) {
        require(token.owner() == address(this));
        require(state == State.Paused);
        //resuming();
        state = State.Active;
        Resumed();
        return true;
    }

    //function resuming() internal {
        // NOOP
    //}

    function isActive() public view returns (bool) {
        return (state == State.Active);
    }

    function tradeEth(address beneficiary, uint256 weiAmount) onlyOwner public returns (bool success) {
        require(beneficiary != address(0));
        uint256 tokenAmount = getTokenAmount(weiAmount);
        require(validTrading(weiAmount, tokenAmount));
        weiRaised = weiRaised.add(weiAmount);
        token.mint(beneficiary, tokenAmount);
        TokenPurchase(msg.sender, beneficiary, weiAmount, tokenAmount);
        return true;
    }

    // E.g.: tokAmount = BTC * 10^18, 1 BTC = 10.5 ETH => ethRate = 105, tokRate = 10.
    function tradeTokens(address beneficiary, uint256 tokAmount, uint256 ethRate, uint256 tokRate) onlyOwner public returns (bool success) {
        uint256 weiAmount = tokAmount.mul(ethRate).div(tokRate);
        return tradeEth(beneficiary, weiAmount);
    }

    function validTrading(uint256 weiAmount, uint256 tokenAmount) internal view returns (bool) {
        bool nonZeroPurchase = 0 < weiAmount;
        bool overMinimum = minimum <= weiAmount;
        bool withinCap = tokenAmount.add(token.totalSupply()) <= cap;
        return withinPeriod() && nonZeroPurchase && overMinimum && withinCap;
    }

    /**
     * @dev Function to mint tokens to partners (grants).
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint, in fraction units.
     * @return A boolean that indicates if the operation was successful.
     */
    function grantTeam(address to, uint256 amount) onlyOwner canGrant toTeam public returns (bool success) {
        require(amount <= teamSupply);
        token.grant(to, amount);
        teamSupply = teamSupply.sub(amount);
        Grant(0, to, amount);
        return true;
    }

    function grantRelay(address to, uint256 amount) onlyOwner canGrant toRelay public returns (bool success) {
        require(amount <= relaySupply);
        token.mint(to, amount);
        relaySupply = relaySupply.sub(amount);
        Grant(1, to, amount);
        return true;
    }

    function grantBounty(address to, uint256 amount) onlyOwner canGrant toBounty public returns (bool success) {
        require(amount <= bountySupply);
        token.mint(to, amount);
        bountySupply = bountySupply.sub(amount);
        Grant(2, to, amount);
        return true;
    }

    function grantLegal(address to, uint256 amount) onlyOwner canGrant toLegal public returns (bool success) {
        require(amount <= legalSupply);
        token.mint(to, amount);
        legalSupply = legalSupply.sub(amount);
        Grant(3, to, amount);
        return true;
    }

    /**
     * Add a new partner.
     * Marks an investor account as member of the team. Locking dates for team members
     * will be applied to this account. In order an account can be marked as a partner,
     * it need to have no token in its current balance, otherwise, the operation will
     * fail.
     * WARNING: Investor who will buy tokens must use another account to have public
     * locking privileges, otherwise, tokens minted to the account will be locked until
     * partnersRelease date.
     */
    function addPartner(address investor) onlyOwner public returns (bool) {
        return token.addPartner(investor);
    }

    /**
     * Remove a partner.
     * Removes an investor account from the team. In order an account can be removed from
     * the partners list, it need to have no token in its current balance, otherwise, the
     * operation will fail.
     */
    function removePartner(address investor) onlyOwner public returns (bool) {
        return token.removePartner(investor);
    }

    /**
     * Freeze permanently an investor.
     * WARNING: This will burn out any token sold to the blacklisted account.
     * No refund will be done to blacklisted investor.
     */
    function blacklist(address account) onlyOwner public returns (bool) {
        return token.blacklist(account);
    }

    /**
     * Freeze (temporarily) an investor.
     */
    function freeze(address investor) onlyOwner public returns (bool) {
        return token.freeze(investor);
    }

    /**
     * Unfreeze an investor.
     */
    function unfreeze(address investor) onlyOwner public returns (bool) {
        return token.unfreeze(investor);
    }

    function claimHolder() onlyOwner public returns (bool success) {
        require(state == State.Paused);
        require(token.owner() == address(this));
        token.transferOwnership(owner);
        assert(token.owner() == owner);
        return true;
    }

    /**
     * Standard/CappedCrowdsale interface.
     */

    function () external payable {
        buyTokens(msg.sender);
    }

    function buyTokens(address beneficiary) public payable {
        require(beneficiary != address(0));
        uint256 weiAmount = msg.value;
        uint256 tokenAmount = getTokenAmount(weiAmount);
        require(validPurchase(tokenAmount));
        weiRaised = weiRaised.add(weiAmount);
        token.mint(beneficiary, tokenAmount);
        TokenPurchase(msg.sender, beneficiary, weiAmount, tokenAmount);
        forwardFunds();
    }

    function hasEnded() public view returns (bool) {
        return endReached() || capReached();
    }

    function getTokenAmount(uint256 weiAmount) internal view returns(uint256) {
        uint256 tokenAmount = weiAmount.mul(rate);
        uint256 tokenBonus = 0;
        if (weiAmount >= bonusMinimum[2]) {
            tokenBonus = bonusPercent[2];
        }
        else if (weiAmount >= bonusMinimum[1]) {
            tokenBonus = bonusPercent[1];
        }
        else if (weiAmount >= bonusMinimum[0]) {
            tokenBonus = bonusPercent[0];
        }
        if (tokenBonus > 0) {
            tokenBonus = tokenAmount.mul(tokenBonus).div(100);
            tokenAmount = tokenAmount.add(tokenBonus);
        }
        return tokenAmount;
    }

    function forwardFunds() internal {
        vault.deposit.value(msg.value)(msg.sender);
    }

    function validPurchase(uint256 tokenAmount) internal view returns (bool) {
        bool nonZeroPurchase = 0 < msg.value;
        bool overMinimum = minimum <= msg.value;
        bool withinCap = tokenAmount.add(token.totalSupply()) <= cap;
        return withinPeriod() && nonZeroPurchase && overMinimum && withinCap;
    }

    /**
     * FinalizableCrowdsale interface.
     */

    function finalize() onlyOwner public {
        require(stage == Stage.Pubsale && state == State.Active);
        require(!isFinalized());
        require(hasEnded());
        stage = Stage.Terminated;
        PubsaleEnded();
        finalization();
        state = State.Finalized;
        Finalized();
    }

    function finalization() internal {
        if (goalReached()) {
            vault.close();
        }
        else {
            vault.enableRefunds();
        }
        token.finishMinting();
        token.transferOwnership(owner);
    }

    function isFinalized() public view returns (bool) {
        return state == State.Finalized;
    }

    /**
     * RefundableCrowdsale interface.
     */

    function claimRefund() public {
        require(isFinalized());
        require(!goalReached());
        vault.refund(msg.sender);
    }

    function goalReached() public view returns (bool) {
        return goal <= weiRaised;
    }

    /**
     * WithdrawableCrowdsale interface.
     */

    function enableWithdraws() onlyOwner public {
        require(goalReached());
        vault.enableWithdraws();
    }
  
    function withdraw(uint256 weiAmount) onlyOwner public {
        require(goalReached());
        vault.withdraw(weiAmount);
    }

}
