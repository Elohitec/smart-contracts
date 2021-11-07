pragma solidity 0.5.17;

library Address {
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }
}

contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }
}

contract ReentrancyGuard {
    bool private _notEntered;

    constructor () internal {
        // Storing an initial non-zero value makes deployment a bit more
        // expensive, but in exchange the refund on every call to nonReentrant
        // will be lower in amount. Since refunds are capped to a percetange of
        // the total transaction's gas, it is best to keep them low in cases
        // like this one, to increase the likelihood of the full refund coming
        // into effect.
        _notEntered = true;
    }

    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_notEntered, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _notEntered = false;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _notEntered = true;
    }
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
}

interface ERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(ERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(ERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function callOptionalReturn(ERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract ICO is Context, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    // The  ELOH contract
    ERC20 private _eloh;

    // The usdt contract
    ERC20 private _usdt;

    // Address where funds are collected
    address payable private _wallet;

    // How many ELOH units a buyer gets per Usdt.
    // The rate is the conversion between Usdt and ELOH unit.
    uint256 private _usdtRate;

    // How many ELOH units a buyer gets per BNB.
    // The rate is the conversion between BNB and ELOH unit.
    uint256 private _bnbRate;

    // Amount of ELOH Delivered
    uint256 private _elohDelivered;

    event ElohPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    constructor (uint256 usdtRate, uint256 bnbRate, address payable wallet, ERC20 usdt, ERC20 eloh) public {
        require(usdtRate > 0, "ICO: usdtRate shouldn't be Zero");
        require(bnbRate > 0, "ICO: bnbRate shouldn't be Zero");
        require(wallet != address(0), "ICO: wallet is the Zero address");
        require(address(eloh) != address(0), "ICO: token is the Zero address");

        _usdtRate = usdtRate;
        _bnbRate = bnbRate;
        _wallet = wallet;
        _usdt = usdt;
        _eloh = eloh;
    }

    function elohAddress() public view returns (ERC20) {
        return _eloh;
    }

    function usdtAddress() public view returns (ERC20) {
        return _usdt;
    }

    function teamWallet() public view returns (address payable) {
        return _wallet;
    }

    function usdtRate() public view returns (uint256) {
        return _usdtRate;
    }

    function bnbRate() public view returns (uint256) {
        return _bnbRate;
    }

    function elohDelivered() public view returns (uint256) {
        return _elohDelivered;
    }

    function buyElohWithUsdt(uint256 usdtAmount) public nonReentrant {
        address beneficiary = _msgSender();
        uint256 ContractBalance = _eloh.balanceOf(address(this));
        uint256 allowance = _usdt.allowance(beneficiary, address(this));

        require(usdtAmount > 0, "You need to send at least one usdt");
        require(allowance >= usdtAmount, "Check the Usdt allowance");

        // calculate ELOH amount
        uint256 _elohAmount = _getUsdtRate(usdtAmount);

        _preValidatePurchase(beneficiary, _elohAmount);

        require(_elohAmount <= ContractBalance, "Not enough ELOH in the reserve");

        // update state
        _elohDelivered = _elohDelivered.add(_elohAmount);

        _usdt.safeTransferFrom(beneficiary, address(this), usdtAmount);

        _processPurchase(beneficiary, _elohAmount);

        emit ElohPurchased(_msgSender(), beneficiary, usdtAmount, _elohAmount);

        _updatePurchasingState(beneficiary, _elohAmount);

        _forwardUsdtFunds(usdtAmount);
        _postValidatePurchase(beneficiary, _elohAmount);
    }

    function () external payable {
        buyElohWithBNB();
    }

    function buyElohWithBNB() public nonReentrant payable {
        address beneficiary = _msgSender();
        uint256 bnbAmount = msg.value;
        uint256 ContractBalance = _eloh.balanceOf(address(this));

        require(bnbAmount > 0, "You need to send at least some BNB");

        // calculate ELOH amount
        uint256 _elohAmount = _getBnbRate(bnbAmount);

        _preValidatePurchase(beneficiary, _elohAmount);

        require(_elohAmount <= ContractBalance, "Not enough EloH in the reserve");

        // update state
        _elohDelivered = _elohDelivered.add(_elohAmount);

        _processPurchase(beneficiary, _elohAmount);

        emit ElohPurchased(_msgSender(), beneficiary, bnbAmount, _elohAmount);

        _updatePurchasingState(beneficiary, _elohAmount);

        _forwardBNBFunds();

        _postValidatePurchase(beneficiary, _elohAmount);
    }

    function _preValidatePurchase(address beneficiary, uint256 Amount) internal view {
        require(beneficiary != address(0), "ICO: beneficiary is the zero address");
        require(Amount != 0, "ICO: Amount is 0");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }

    function _postValidatePurchase(address beneficiary, uint256 Amount) internal view {
        // solhint-disable-previous-line no-empty-blocks
    }

    function _deliverEloh(address beneficiary, uint256 elohAmount) internal {
        _eloh.safeTransfer(beneficiary, elohAmount);
    }

    function _processPurchase(address beneficiary, uint256 elohAmount) internal {
        _deliverEloh(beneficiary, elohAmount);
    }
    
    function _updatePurchasingState(address beneficiary, uint256 Amount) internal {
        // solhint-disable-previous-line no-empty-blocks
    }

    function _getUsdtRate(uint256 usdtAmount) internal view returns (uint256) {
        return usdtAmount.mul(_usdtRate);
    }

    function _getBnbRate(uint256 bnbAmount) internal view returns (uint256) {
        return bnbAmount.mul(_bnbRate);
    }

    function _forwardUsdtFunds(uint256 usdtAmount) internal {
        _usdt.safeTransfer(_wallet, usdtAmount);
    }

    function _forwardBNBFunds() internal {
        _wallet.transfer(msg.value);
    }
}

contract LimitedUnitsIco is ICO {
    using SafeMath for uint256;

    uint256 private _maxElohUnits;

    constructor (uint256 maxElohUnits) public {
        require(maxElohUnits > 0, "Max Capitalization shouldn't be Zero");
        _maxElohUnits = maxElohUnits;
    }

    function maxElohUnits() public view returns (uint256) {
        return _maxElohUnits;
    }

    function icoReached() public view returns (bool) {
        return elohDelivered() >= _maxElohUnits;
    }

    function _preValidatePurchase(address beneficiary, uint256 Amount) internal view {
        super._preValidatePurchase(beneficiary, Amount);
        require(elohDelivered().add(Amount) <= _maxElohUnits, "Max ELOH Units exceeded");
    }
}

contract ElohIco is LimitedUnitsIco {

    uint256 internal constant _hundredMillion = 10 ** 8;
    uint256 internal constant _oneEloh = 10**18;
    uint256 internal constant _maxElohUnits = _hundredMillion * _oneEloh;
    uint256 internal constant _oneUsdtToEloH = 1;
     uint256 internal constant _oneBnbToEloH = 480;
    
    address payable _wallet = 0x19536Eb15bD786f4e11979054c2d1A21A129f8F9;
    ERC20 internal _usdt = ERC20(0x55d398326f99059fF775485246999027B3197955);
    ERC20 internal _eloh = ERC20(0xbD5a3749dd3D90558D70fed80D6Fd2a8847f0236);

    constructor () public
        ICO(_oneUsdtToEloH, _oneBnbToEloH, _wallet, _usdt, _eloh) 
        LimitedUnitsIco(_maxElohUnits)
    {

    }
}