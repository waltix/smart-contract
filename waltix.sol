pragma solidity ^0.4.11;

library SafeMath {
    function mul(uint a, uint b) internal returns (uint) {
        uint c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }

    function div(uint a, uint b) internal returns (uint) {
        uint c = a / b;
        return c;
    }

    function sub(uint a, uint b) internal returns (uint) {
        require(b <= a);
        return a - b;
    }

    function add(uint a, uint b) internal returns (uint) {
        uint c = a + b;
        require(c >= a);
        return c;
    }

    function max64(uint64 a, uint64 b) internal constant returns (uint64) {
        return a >= b ? a : b;
    }

    function min64(uint64 a, uint64 b) internal constant returns (uint64) {
        return a < b ? a : b;
    }

    function max256(uint256 a, uint256 b) internal constant returns (uint256) {
        return a >= b ? a : b;
    }

    function min256(uint256 a, uint256 b) internal constant returns (uint256) {
        return a < b ? a : b;
    }
}

// Base contract for owner
contract Ownable {
    address owner;

    // Set owner
    function Ownable() {
        owner = msg.sender;
    }

    // Modifier chack only owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}

// Abstract contract ERC223 
contract ERC223Basic {
    uint public totalSupply;
    mapping(address => uint) balances;

    string public name;
    string public symbol;
    uint8 public decimals;

    function balanceOf(address who) constant returns (uint);
    function transfer(address to, uint value);
    function transfer(address to, uint value, bytes data);
    event Transfer(address indexed from, address indexed to, uint value, bytes indexed data);
}

// Abstract contract ERC223ReceivingContract 
contract ERC223ReceivingContract {
    function tokenFallback(address _from, uint _value, bytes _data);
}

// FrozenToken is contract for frozen 
// and distribution of coins among the team members
contract FrozenToken is ERC223Basic, Ownable {
    using SafeMath for uint;
    
    address[] storeAddresses;
    mapping(address => uint) frozen;
    uint defrost_date;

    // Add adress member and value for freeze
    function addFrozenTo(address to, uint value) onlyOwner {
        balances[msg.sender] = balances[msg.sender].sub(value);
        frozen[to] = frozen[to].add(value);
        storeAddresses.push(to);
    }

    // freeze tokens
    function freeze(uint _period) onlyOwner {
        require(defrost_date == 0);
        defrost_date = now + _period;
    }

    // unfrozen tokens
    function unfrozen() {
        require(defrost_date != 0);
        require(defrost_date < now);

        for(uint i = 0; i < storeAddresses.length; i++) {
            var to = storeAddresses[i];
            var value = frozen[to];

            frozen[to] = frozen[to].sub(value);
            balances[to] = balances[to].add(value);
        }
    }

    // balance of freeze tokens
    function frozenOf(address _owner) constant returns (uint balance) {
        return frozen[_owner];
    }
}

// Emission contract
contract Token is FrozenToken {
    using SafeMath for uint;
    
    // Constructor
    function Token(
        string _name, 
        string _symbol, 
        uint8 _decimals, 
        uint _totalSupply) 
    {
        name =_name;
        symbol =_symbol;
        decimals =_decimals;

        totalSupply = _totalSupply;
        balances[owner] = totalSupply;
    }
    
    // balance of tokens
    function balanceOf(address _owner) constant returns (uint balance) {
        return balances[_owner];
    }

    // transfer tokens to address
    function transfer(address to, uint value, bytes data) {
        require(value > 0);
        require(balances[msg.sender] >= value && balances[to] + value >= balances[to]);

        uint codeLength;
        assembly {
            codeLength := extcodesize(to)
        }

        balances[msg.sender] = balances[msg.sender].sub(value);
        balances[to] = balances[to].add(value);
        if(codeLength > 0) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(to);
            receiver.tokenFallback(msg.sender, value, data);
        }
        Transfer(msg.sender, to, value, data);
    }

    // transfer tokens to address
    function transfer(address to, uint value) {
        require(value > 0);
        require(balances[msg.sender] >= value && balances[to] + value >= balances[to]);

        uint codeLength;
        bytes memory empty;

        assembly {
            codeLength := extcodesize(to)
        }

        balances[msg.sender] = balances[msg.sender].sub(value);
        balances[to] = balances[to].add(value);
        if(codeLength > 0) {
            ERC223ReceivingContract receiver = ERC223ReceivingContract(to);
            receiver.tokenFallback(msg.sender, value, empty);
        }
        Transfer(msg.sender, to, value, empty);
    }

    // change owner
    function changeOwner(address newOwner) onlyOwner {
        require(newOwner != address(0));
        
        balances[newOwner] = balances[owner];
        balances[owner] = 0;
        owner = newOwner;
    }
}

// Helper contracts
contract HelperIco {
    using SafeMath for uint;
    
    // calc tokens per 1 etherium
    function calcTokens(uint _value, uint tokens_per_eth) internal returns(uint) {
        return _value.mul(tokens_per_eth).div(1 ether);
    }

    // calculate the bonus from the total issued number of coins
    function bonus(
        uint _was_sale, 
        uint _amount, 
        uint _amount_bonus, 
        uint _bonus_percent) internal returns(uint) 
    {
        uint value = _was_sale + _amount;
        return _amount + calcBonus(value, _amount, _amount_bonus, _bonus_percent);
    }

    // calc bonus
    function calcBonus(
        uint _value, 
        uint _amount, 
        uint _amount_bonus, 
        uint _bonus_percent) private returns(uint) 
    {
        if(_value < _amount_bonus) {
            if(_bonus_percent == 50) {
                return _amount.div(2) ; // 50%
            }
            if(_bonus_percent == 25) {
                return _amount.div(4) ; // 25%
            }
        }
        return 0;
    }
}

// ICO Basic contract
contract BaseICO is Ownable {

    uint sale_period;
    uint public start;
    uint public end;
    bool public is_closed;

    // constructor
    function BaseICO() {
        is_closed = false;
    }

    // modificator while ICO
    modifier whileIco() {
        require(((now > start) && (now < end )) && !is_closed);
        _;
    }

    // start ICO
    function startIco() onlyOwner {
        require (start == 0);
        require (sale_period != 0);

        start = now;
        end   = now + sale_period;
    }

    // abstract function close ICO
    function closeIco();
}

// Contract managed frozen tokens
contract FrozenTokenIco is BaseICO {
    Token public token;
    HelperIco hIco;

    // Add adress member and value for further freeze
    function addFrozenTo(address to, uint value) onlyOwner {
        token.addFrozenTo(to, value);
    }

    // freeze tokens
    function freeze(uint _period) onlyOwner {
        token.freeze(_period);
    }

    // unfrozen tokens
    function unfrozen() {
        token.unfrozen();
    }

    // transfer tokens to address
    function transfer(address to, uint value) onlyOwner {
        token.transfer(to, value);
    }

    // balance of freeze tokens
    function frozenOf(address _owner) constant returns (uint balance) {
        return token.frozenOf(_owner);
    }
}

contract PreIco is BaseICO, HelperIco {
    using SafeMath for uint;

    Token public  token;
    Ico   public  ico;
    uint  private was_sale = 0;

    // Token details
    string constant TOKEN_NAME =           "Waltix";
    string constant TOKEN_SYMBOL =         "WLTX";
    uint8  constant TOKEN_DECIMALS =       8;    

    uint   constant SALE_PERIOD =          30 days; // period pre ICO
    uint   constant MIN_INVEST =           0.1 ether; // minimum invest
    uint            TOTAL =                5000000000000000; //50_000_000 total supply
    uint            TOKENS_PER_ETHER =     29800000000;  // X tokens per 1 ethereum
    uint   constant BONUS =                500000000000000; // 5_000_000 bonus 50%
    uint   constant BONUS_PERCENT =        50;
    uint   constant MAX_SALE =             500000000000000; // 5_000_000       

     function PreIco() {
        sale_period = SALE_PERIOD;
        token = new Token(TOKEN_NAME, TOKEN_NAME, TOKEN_DECIMALS, TOTAL);
    }

    // Change price 1ETH = N WLTX
    function changeCountTokenPerEther(uint _value)onlyOwner whileIco {
        TOKENS_PER_ETHER = _value;
    }

    // function pay tokens
    function() payable whileIco {
        require(msg.value >= MIN_INVEST);

        uint tokens = 
            bonus(
                    was_sale, 
                    calcTokens(msg.value, TOKENS_PER_ETHER),
                    BONUS,
                    BONUS_PERCENT
                );

        uint will_be_sold = was_sale + tokens;
        require(will_be_sold <= MAX_SALE);

        owner.transfer(msg.value);
        token.transfer(msg.sender, tokens);
        was_sale = was_sale + tokens;
    }

    // Close ICO
    function closeIco() onlyOwner {
        require (start != 0);
        require(!is_closed);
        
        ico = new Ico(token, owner, was_sale);
        token.changeOwner(ico);
        is_closed = true;
    }
}

// ICO contract for sale tokens from emission contract
contract Ico is FrozenTokenIco, HelperIco {
    using SafeMath for uint;

    uint  private was_sale = 0;
    uint  private was_sale_pre_ico;

    uint   constant SALE_PERIOD =          90 days;    // period ICO
    uint   constant MIN_INVEST =           0.1 ether; // minimum invest
    uint   constant BONUS =                1000000000000000; // 10 000 000 bonus 25%
    uint            TOKENS_PER_ETHER =     29800000000;  // X tokens per 1 ether
    uint   constant BONUS_PERCENT =        25; // bonus percent
    uint   constant MAX_SALE =             3500000000000000; // 35_000_000 will be sold 
    
    // Constructor
    function Ico(Token _token, address _owner, uint _was_sale_pre_ico) {
        sale_period =      SALE_PERIOD;
        owner =            _owner;
        token =            _token;
        was_sale_pre_ico = _was_sale_pre_ico;
    }

    // function pay tokens
    function() payable whileIco {
        require(msg.value >= MIN_INVEST);

        uint tokens = 
            bonus(
                    was_sale, 
                    calcTokens(msg.value, TOKENS_PER_ETHER),
                    BONUS,
                    BONUS_PERCENT
                );

        uint will_be_sold = was_sale_pre_ico + was_sale + tokens;
        require(will_be_sold <= MAX_SALE);

        owner.transfer(msg.value);
        token.transfer(msg.sender, tokens);
        was_sale = was_sale + tokens;
    }

    // Close ICO
    function closeIco() onlyOwner {
        require (start != 0);
        require(!is_closed);
        is_closed = true;
    }

    // Change price 1ETH = N WLTX
    function changeCountTokenPerEther(uint _value)onlyOwner whileIco {
        TOKENS_PER_ETHER = _value;
    }
}