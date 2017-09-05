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

    // Add adress member and value for further freeze
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
    function unfrozen() onlyOwner {
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
    function Token(string _name, string _symbol, uint8 _decimals, uint _totalSupply) {
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

    // mint tokens
    function mint(uint _value) onlyOwner {
        totalSupply = totalSupply.add(_value);
        balances[msg.sender] = balances[msg.sender].add(_value);
    }
}

// Helper contracts
contract HelperIco{
    using SafeMath for uint;
    
    uint bonus1;
    uint bonus2;
    
    // Constructor
    function HelperIco(uint _bonus1, uint _bonus2){
        bonus1 = _bonus1;
        bonus2 = _bonus2;
    }
    
    // calc tokens per 1 etherium
    function calcTokens(uint _value, uint tokens_per_eth) returns(uint) {
        return _value.mul(tokens_per_eth).div(1 ether);
    }

    // calculate the bonus from the total issued number of coins
    function bonus(uint totalSupply, uint _amount) returns(uint) {
        uint value = totalSupply + _amount;
        return _amount + calcBonus(value, _amount);
    }

    // calc bonus
    function calcBonus(uint value, uint _amount) returns(uint) {
        if(value < bonus1) {
            return _amount.div(2) ; // 50%
        }
        if(value < bonus2) {
           return _amount.div(4); // 25%
        }
        return 0;
    }
    
    // calculate the number of tokens on the issue for percent
    function calcPayToCommand(uint totalSupply, uint percent_frozen_tokens) returns(uint)  {
        return (totalSupply.div(70)).mul(percent_frozen_tokens); // (total / 100) * FROZEN_TOKEN_PER
    }
}

// ICO Basic contract
contract ICO is Ownable {
    uint sale_period;

    uint public start;
    uint public end;
    bool public is_closed;

    // constructor
    function ICO() {
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
contract FrozenTokenIco is ICO {
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

// ICO contract for sale tokens from emission contract
contract TokenIco is FrozenTokenIco {
    using SafeMath for uint;

    string constant TOKEN_NAME =           "WALTIX";
    string constant TOKEN_SYMBOL =           "WLTX";
    uint8  constant TOKEN_DECIMALS =       8;
    uint   constant SALE_PERIOD =          90 days;
    uint   constant MIN_INVEST =           0.1 ether;
    uint   constant BONUS_PART_ONE =       500000000000000;  // 5 000 000 tokens
    uint   constant BONUS_PART_TWO =       1500000000000000; // 15 000 000 tokens
    uint            TOKENS_PER_ETHER =     38000000000;  // 380 tokens
    uint   constant BOUNTY_TOKEN_PERCENT = 30;
    
    // Constructor
    function TokenIco() {
        sale_period = SALE_PERIOD;
        token = new Token(TOKEN_NAME, TOKEN_NAME, TOKEN_DECIMALS, 0);
        hIco = new HelperIco(BONUS_PART_ONE, BONUS_PART_TWO);
    }

    // Change price 1ETH = N WLTX
    function changeCountTokenPerEther(uint _value)onlyOwner whileIco {
        TOKENS_PER_ETHER = _value;
    }

    // function pay tokens
    function() payable whileIco {
        require(msg.value >= MIN_INVEST);

        owner.transfer(msg.value);

        uint tokens = hIco.bonus(
            token.totalSupply(), 
            hIco.calcTokens(msg.value, TOKENS_PER_ETHER));
            
        token.mint(tokens);
        token.transfer(msg.sender, tokens);
    }

    // Close ICO
    function closeIco() onlyOwner {
        require (start != 0);
        require(!is_closed);
        
        token.mint(hIco.calcPayToCommand(token.totalSupply(), BOUNTY_TOKEN_PERCENT));

        is_closed = true;
    }
}