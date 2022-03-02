// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

interface IERC20 {

 function totalSupply() external view returns (uint256);

 function balanceOf(address account) external view returns (uint256);

 function transfer(address recipient, uint256 amount) external returns (bool);

 function allowance(address owner, address spender) external view returns (uint256);

 function approve(address spender, uint256 amount) external returns (bool);

 function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

 event Transfer(address indexed from, address indexed to, uint256 value);

 event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
 
 function add(uint256 a, uint256 b) internal pure returns (uint256) {
 uint256 c = a + b;
 require(c >= a, "SafeMath: addition overflow");

 return c;
 }
 function sub(uint256 a, uint256 b) internal pure returns (uint256) {
 return sub(a, b, "SafeMath: subtraction overflow");
 }
 function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
 require(b <= a, errorMessage);
 uint256 c = a - b;

 return c;
 }
 function mul(uint256 a, uint256 b) internal pure returns (uint256) {
 if (a == 0) {
 return 0;
 }

 uint256 c = a * b;
 require(c / a == b, "SafeMath: multiplication overflow");

 return c;
 }
 function div(uint256 a, uint256 b) internal pure returns (uint256) {
 return div(a, b, "SafeMath: division by zero");
 }
 function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
 require(b > 0, errorMessage);
 uint256 c = a / b;
 return c;
 }
 function mod(uint256 a, uint256 b) internal pure returns (uint256) {
 return mod(a, b, "SafeMath: modulo by zero");
 }
 function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
 require(b != 0, errorMessage);
 return a % b;
 }
}

contract Context {
 function _msgSender() internal view virtual returns (address payable) {
 return msg.sender;
 }

 function _msgData() internal view virtual returns (bytes memory) {
 this; 
 return msg.data;
 }
}

contract SCLR is IERC20, Context {
 
 using SafeMath for uint256;
 mapping (address => mapping (address => uint256)) private _allowances;
 
 address private _owner;
 string private _name ="Sch0lar";
 string private _symbol = "SCLR";
 uint8 private _decimals = 18;
 uint256 private _totalSupply = 1000000000*(10**uint256(decimals));
 uint8 decimals = 18;

 mapping (address => uint256) private _balances;

 mapping (address => mapping (address => uint256)) private _allowed;
 mapping (address => bool) _addressLocked;
 mapping (address => uint256) _finalSoldAmount;
 mapping (address => mapping(uint256 => bool)) reEntrance;
 
 uint256 private tokenPrice;
 uint256 private deploymentTime;
 uint256 private TreasuryAmount = 50000000;
 uint256 private TeamAmount = 150000000;
 uint256 private AdvisorsAmount = 40000000;
 uint256 private LiquidityAmount = 100000000;
 uint256 private EndowmentAmount = 40000000;
 uint256 private earlyInvestorsAmount = 120000000;
 uint256 private RewardsAmount = 150000000;
 uint256 private PresaleAmount = 100000000;
 uint256 private publicSaleAmount = 250000000; 
 
 address private Treasury =0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
 address private Team =0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
 address private Advisors =0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
 address private Liquidity =0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
 address private Endowment =0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
 address private earlyInvestors =0x17F6AD8Ef982297579C203069C1DbfFE4348c372;
 address private Rewards =0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678;
 address private Presale =0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7;
 address private publicSale =0x1aE0EA34a72D944a8C7603FfB3eC30a6669E454C;
  
 constructor () public {
 _owner = msg.sender;
 _balances[_owner] = _totalSupply;
 _transfer(_owner,Treasury,TreasuryAmount);
 _transfer(_owner,Team,TeamAmount);
 _transfer(_owner,Advisors,AdvisorsAmount); 
 _transfer(_owner,Rewards,RewardsAmount);
 _transfer(_owner,Liquidity,LiquidityAmount); 
 _transfer(_owner,Endowment,EndowmentAmount);
 _transfer(_owner,earlyInvestors,earlyInvestorsAmount);
 _transfer(_owner,Presale,PresaleAmount);
 _transfer(_owner,publicSale,publicSaleAmount);

 }
 function name() public view returns (string memory) {
 return _name;
 }
 function symbol() public view returns (string memory) {
 return _symbol;
 }

 function totalSupply() public view override returns (uint256) {
 return _totalSupply;
 }
 function balanceOf(address account) public view override returns (uint256) {
 return _balances[account];
 }
 function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
 _transfer(_msgSender(), recipient, amount);
 return true;
 }
 function allowance(address owner, address spender) public view virtual override returns (uint256) {
 return _allowances[owner][spender];
 }

 function approve(address spender, uint256 amount) public virtual override returns (bool) {
 _approve(_msgSender(), spender, amount);
 return true;
 }
 function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
 _transfer(sender, recipient, amount);
 _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
 return true;
 }
 function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
 _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
 return true;
 }
 function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
 _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
 return true;
 }
 function _transfer(address sender, address recipient, uint256 amount) internal virtual {
 require(sender != address(0), "ERC20: transfer from the zero address");
 require(recipient != address(0), "ERC20: transfer to the zero address");

 _beforeTokenTransfer(sender, recipient, amount);
 _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
 _balances[recipient] = _balances[recipient].add(amount);
 emit Transfer(sender, recipient, amount);
 }
 function _mint(address account, uint256 amount) internal virtual {
 require(account != address(0), "ERC20: mint to the zero address");

 _beforeTokenTransfer(address(0), account, amount);

 _totalSupply = _totalSupply.add(amount);
 _balances[account] = _balances[account].add(amount);
 emit Transfer(address(0), account, amount);
 }

 function _approve(address owner, address spender, uint256 amount) internal virtual {
 require(owner != address(0), "ERC20: approve from the zero address");
 require(spender != address(0), "ERC20: approve to the zero address");

 _allowances[owner][spender] = amount;
 emit Approval(owner, spender, amount);
 }
 function _setupDecimals(uint8 decimals_) internal {
 _decimals = decimals_;
 }
 function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}