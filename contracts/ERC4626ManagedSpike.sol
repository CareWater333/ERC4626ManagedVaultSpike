ragma solidity >=0.8.0;

import {ERC4626} from "../utils/ERC4626.sol";

/// @notice Owner-managed vault conforming to ERC4626 both for making and receiving investments
/// @author CareWater (https://github.com/CareWater333/ERC4626ManagedVaultSpike)

/// Someday: add EIP2612 Permit for deposits and withdraws
/// Someday: figure out how to EIP2612 for invest and divest too
/// Todo: Use OpenZeppelin ERC20 to get onlyOwner

/*
Key things to think about:
If underlying asset values change dramatically, there will be an arb opportunity before they
get updated here. Not sure how to handle that. Can do more frequent updating with round-robin
but the problem still remains.

*/

contract ERC4626ManagedVaultSpike is ERC4626 {

    // Variables
    uint256 immutable endDate; // after EndDate anyone can call close()
    bool vaultClosed; // closed vault cannot deposit or invest and anyone can call divest
    struct investment {
        ERC4626 vault;
        uint256 shares;
        uint256 assets; // assets will change, shares should not
        uint256 lastUpdated;
    };
    investment[] investments;
    mapping(address => uint256) public investmentIndex; // lookup by vault
    uint256 investmentAssetsTotal;

    /* optimization to add:
    uint256 nextInvestmentToUpdate; // every tx updates at least one other investment too
    uint256 updateQuantum = 1000; // don't update if already updated this recently
    with function updateNextAssetValue() that does next in line
    */

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
        uint256 _endDate
    ) ERC4626(_asset, _name, _symbol) {
        endDate = _endDate;
        vaultClosed = false;
     }

    function totalAssets() returns (unit256) {
        return asset.balanceOf(this.address) + investmentAssetsTotal;
    }
    
    // Todo: check closed on maxMint and maxDeposit as well
    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
         require(!vaultClosed, "Cannot deposit after vault closed");
         return super.deposit(assets, receiver);
     }
  
   function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
         require(!vaultClosed, "Cannot mint after vault closed");
         return super.mint(shares, receiver);
   }

    function close() public {
        require(onlyOwner || block.timestamp > endDate, "Only Owner can close until endDate");
        vaultClosed = true;
    }

    function invest(ERC4626 _vault, uint256 _amount) public onlyOwner returns (uint256) {

        require(!vaultClosed, "Cannot invest after vault closed")
        require(_vault.asset = asset, "Investment asset does not match vault");

        uint8 index = investmentIndex[_vault];
        if (investments[index].vault != _vault) { // new investment vault, index was zero
            index = investments.length;
            investmentIndex[vault] = index;
            investments[index].vault = _vault;
        }

        uint 256 shares = _vault.deposit(_amount, this.address);
        updateAssetValueIndex(index);

        return shares;
    }

    funciton divest(ERC4626 _vault, uint256 _shares) public returns (uint256) {

        require(onlyOwner || vaultClosed, "Only Owner can divest until closed");

        uint8 index = investmentIndex[_vault];
        if (_shares > investments[index].shares) {
            _shares = _vault.maxRedeem(this.address); // maxRedeem if _shares > actual
        }
        uint256 assets = _vault.redeem(_shares, this.address, this.address);
        updateAssertValueIndex(index);

        return assets;
    }
}

function updateAssetValueIndex(uint8 index) internal returns (uint256) {
    uint256 oldAssets = investments[index].assets;

    // this is more of an assert, what's the best way to do this?
    // require(investments[index].vault == _vault, "Invalid vault, something went wrong")

    // update shares and assets
    investments[index].shares = _vault.balanceOf(this.address); // should be same as _vault.maxRedeem()
    investments[index].assets = _vault.convertToAssets(investments[index].shares); // should be same as _vault.maxWithdraw()
    investments[index].lastUpdated = block.timestamp;

    // update total
    investmentAssetsTotal += investments[index].assets - oldAssets;
    return investments[index].assets;
}

// anyone can update a single vault asset value
function updateAssetValue(ERC4626 _vault) public returns (uint256) {
    return updateAssetValueIndex(investmentIndex[_vault]);
}

// probably costs a lot of gas, but here just in case a full reset is needed somehow
function updateAllAssets() public returns uint256 {
    for(uint8 i=0; i<= investments.length; i++){
        updateAssetValueIndex(i);
    }
    return investmentAssetsTotal;
}
