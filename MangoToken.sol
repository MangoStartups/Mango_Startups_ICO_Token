pragma solidity ^0.4.18;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

    // Public variable with address of owner
    address public owner;

    /**
     * Log ownership transference
     */
    event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
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

    uint256 public totalSupply = 0;
    function balanceOf(address who) public constant returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);

}


contract MintableToken is ERC20Basic, Ownable {

    bool public mintingFinished = false;

    event Mint(address indexed to, uint256 amount);
    event MintFinished();

    modifier canMint() {
        require(!mintingFinished);
        _;
    }

    function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool);

    /**
     * @dev Function to stop minting new tokens.
     * @return True if the operation was successful.
     */
    function finishMinting() onlyOwner public returns (bool) {
        mintingFinished = true;
        MintFinished();
        return true;
    }

}


/**
 * @title Mango (MNG) Token contract.
 * @dev Mango is a Capped token, i.e., a Mintable ERC20 token with a token cap.
 */
contract MangoToken is MintableToken {

    using SafeMath for uint256;

    /**
     * DetailedERC20 data.
     */
    string public name     = "Mango";
    string public symbol   = "MNG";
    uint8  public decimals = 18;

    /**
     * Transfer timelock data.
     */
    uint256 public publicRelease   = 1526907600; // Mon, May 21 2018 13:00:00 +0000 (GMT)
    uint256 public partnersRelease = 1539867600; // Thu, 18 Oct 2018 13:00:00 +0000 (GMT)

    /**
     * Token account balances and status data.
     */
    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) internal allowed;
    mapping (address => boolean) partners;
    mapping (address => boolean) blacklisted;
    mapping (address => boolean) freezed;

    /**
     * Token events.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Blacklisted(address indexed account);
    event Burn(address indexed burner, uint256 value);
    event Freezed(address indexed investor);
    event PartnerAdded(address indexed investor);
    event PartnerRemoved(address indexed investor);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unfreezed(address indexed investor);
    event Whitelisted(address indexed account);

    /**
     * Initializes contract.
     */
    function MangoToken() public {
        assert(publicLockEnd <= partnersLockEnd);
        assert(partnersMintLockEnd < partnersLockEnd);
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param investor The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address investor) public constant returns (uint256 balanceOfInvestor) {
        return balances[investor];
    }

    /**
     * Add a new partner.
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
     */
    function removePartner(address investor) onlyOwner public returns (bool) {
        require(partners[investor] && balances[investor] == 0);
        partners[investor] = false;
        PartnerRemoved(investor);
        return !partners[investor];
    }

    /**
     * Add a new account to the blacklist.
     * WARNING: This will burn out any token sold to the blacklisted account.
     */
    function blacklist(address account) onlyOwner public returns (bool) {
        require(account != address(0));
        require(!blacklisted[account]);
        blacklisted[account] = true;
        totalSupply = totalSupply.sub(balances[account]);
        balances[account] = 0;
        Blacklisted(account);
        return blacklisted[account];
    }

    /**
     * Remove an account from the blacklist.
     */
    function whitelist(address account) onlyOwner public returns (bool) {
        require(blacklisted[account]);
        blacklisted[account] = false;
        Whitelisted(account);
        return !blacklisted[account];
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
     * @dev transfer token for a specified address
     * @param _to The address to transfer to.
     * @param _amount The amount to be transferred.
     */
    function transfer(address _to, uint256 _amount) public returns (bool) {
        require(_to != address(0) && !freezed[_to] && !blacklisted[_to]);
        require(!freezed[msg.sender] && !blacklisted[msg.sender]);
        require((!partners[msg.sender] && now >= publicRelease) || now >= partnersRelease);
        require(_amount > 0 && _amount <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        Transfer(msg.sender, _to, _amount);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _amount uint256 the amount of tokens to be transferred
     */
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool) {
        require(_to != address(0) && !freezed[_to] && !blacklisted[_to]);
        require(!freezed[_from] && !blacklisted[_from] && !blacklisted[msg.sender]);
        require((!partners[_from] && now >= publicRelease) || now >= partnersRelease);
        require(_amount > 0 && _amount <= balances[_from]);
        require(_amount <= allowed[_from][msg.sender]);
        balances[_from] = balances[_from].sub(_amount);
        balances[_to] = balances[_to].add(_amount);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        Transfer(_from, _to, _amount);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     *
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to be spent.
     */
    function approve(address _spender, uint256 _value) public returns (bool) {
        require(!freezed[msg.sender] && !blacklisted[msg.sender] && !blacklisted[_spender]);
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /**
     * approve should be called when allowed[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     */
    function increaseApproval (address _spender, uint _addedValue) public returns (bool success) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval (address _spender, uint _subtractedValue) public returns (bool success) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(uint256 _value) public {
        require((msg.sender != partnersWallet && now >= publicRelease) || now >= partnersRelease);
        require(_value > 0 && _value <= balances[msg.sender]);
        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
    }

    /**
     * @dev Function to mint tokens
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
        require(_to != partnersWallet);
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(_to, _amount);
        Transfer(address(0), _to, _amount);
        return true;
    }

    /**
     * @dev Function to mint reserved tokens to partners
     * @return A boolean that indicates if the operation was successful.
     */
    function mintPartners(uint256 amount) onlyOwner canMint public returns (bool) {
        require(now >= partnersMintLockEnd);
        require(reservedSupply > 0);
        require(amount <= reservedSupply);
        totalSupply = totalSupply.add(amount);
        reservedSupply = reservedSupply.sub(amount);
        balances[partnersWallet] = balances[partnersWallet].add(amount);
        Mint(partnersWallet, amount);
        Transfer(address(0), partnersWallet, amount);
        return true;
    }

    /**
     * Extends the lock periods by delay seconds.
     */
    function extendLockPeriods(uint delay) onlyOwner public {
        require(delay > 0);
        publicRelease = publicRelease.add(delay);
        partnersRelease = partnersRelease.add(delay);
        partnersMintLockEnd = partnersMintLockEnd.add(delay);
        assert(publicRelease <= partnersRelease);
        assert(partnersMintLockEnd < partnersRelease);
    }

}

