pragma solidity ^0.5.7;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./livepeerInterface/IController.sol";
import "./livepeerInterface/IBondingManager.sol";
import "./livepeerInterface/IRoundsManager.sol";

contract TimeLockedLptOrder {

    using SafeMath for uint256;

    address internal constant ZERO_ADDRESS = address(0);

    string internal constant ERROR_SELL_ORDER_COMMITTED_TO = "LPT_ORDER_SELL_ORDER_COMMITTED_TO";
    string internal constant ERROR_SELL_ORDER_NOT_COMMITTED_TO = "LPT_ORDER_SELL_ORDER_NOT_COMMITTED_TO";
    string internal constant ERROR_COLLATERAL_TRANSFER_FAILED = "LPT_ORDER_COLLATERAL_TRANSFER_FAILED";
    string internal constant ERROR_PAYMENT_TRANSFER_FAILED = "LPT_ORDER_PAYMENT_TRANSFER_FAILED";
    string internal constant ERROR_LPT_TRANSFER_FAILED = "LPT_ORDER_LPT_TRANSFER_FAILED";
    string internal constant ERROR_INITIALISED_ORDER = "LPT_ORDER_INITIALISED_ORDER";
    string internal constant ERROR_UNINITIALISED_ORDER = "LPT_ORDER_UNINITIALISED_ORDER";
    string internal constant ERROR_COMMITMENT_WITHIN_UNBONDING_PERIOD = "LPT_ORDER_COMMITMENT_WITHIN_UNBONDING_PERIOD";
    string internal constant ERROR_NOT_BUYER = "LPT_ORDER_NOT_BUYER";

    struct LptSellOrder {
        uint256 lptValue;
        uint256 paymentValue; // In DAI
        uint256 collateralValue; // In DAI
        uint256 deliveredByBlock;
        address buyerAddress;
    }

    IController livepeerController;
    IERC20 daiToken;
    // One sell order per address
    mapping(address => LptSellOrder) public lptSellOrders;

    constructor(address _livepeerController, address _daiToken) public {
        livepeerController = IController(_livepeerController);
        daiToken = IERC20(_daiToken);
    }

    /*
    * @notice Create an LPT sell order, requires approval for this contract to spend `_collateralValue` amount of DAI.
    * @param _lptValue Value of LPT to sell
    * @param _paymentValue Value required in exchange for LPT
    * @param _collateralValue Value of collateral
    * @param _deliveredByBlock Order filled or cancelled by this block or the collateral can be claimed
    */
    function createLptSellOrder(uint256 _lptValue, uint256 _paymentValue, uint256 _collateralValue, uint256 _deliveredByBlock) public {
        LptSellOrder storage lptSellOrder = lptSellOrders[msg.sender];

        require(lptSellOrder.collateralValue == 0, ERROR_INITIALISED_ORDER);
        require(daiToken.transferFrom(msg.sender, address(this), _collateralValue), ERROR_COLLATERAL_TRANSFER_FAILED);

        lptSellOrders[msg.sender] = LptSellOrder(_lptValue, _paymentValue, _collateralValue, _deliveredByBlock, ZERO_ADDRESS);
    }

    /*
    * @notice Cancel an LPT sell order, must be executed by the sell order creator.
    */
    function cancelLptSellOrder() public {
        LptSellOrder storage lptSellOrder = lptSellOrders[msg.sender];

        require(lptSellOrder.buyerAddress == ZERO_ADDRESS, ERROR_SELL_ORDER_COMMITTED_TO);

        daiToken.transfer(msg.sender, lptSellOrder.collateralValue);
        delete lptSellOrders[msg.sender];
    }

    /*
    * @notice Commit to buy LPT, requires approval for this contract to spend the payment amount in DAI.
    * @param _sellOrderCreator Address of sell order creator
    */
    function commitToBuyLpt(address _sellOrderCreator) public {
        LptSellOrder storage lptSellOrder = lptSellOrders[_sellOrderCreator];

        require(lptSellOrder.lptValue > 0, ERROR_UNINITIALISED_ORDER);
        require(lptSellOrder.buyerAddress == ZERO_ADDRESS, ERROR_SELL_ORDER_COMMITTED_TO);
        require(lptSellOrder.deliveredByBlock.sub(_getUnbondingPeriodLength()) < block.number, ERROR_COMMITMENT_WITHIN_UNBONDING_PERIOD);
        require(daiToken.transferFrom(msg.sender, address(this), lptSellOrder.paymentValue), ERROR_PAYMENT_TRANSFER_FAILED);

        lptSellOrders[_sellOrderCreator].buyerAddress = msg.sender;
    }

    /*
    * @notice Claim collateral and payment after a sell order has been committed to but it hasn't been delivered by
    *         the block number specified.
    * @param _sellOrderCreator Address of sell order creator
    */
    function claimCollateralAndPayment(address _sellOrderCreator) public {
        LptSellOrder storage lptSellOrder = lptSellOrders[_sellOrderCreator];

        require(lptSellOrder.buyerAddress == msg.sender, ERROR_NOT_BUYER);
        require(lptSellOrder.deliveredByBlock < block.number);

        uint256 totalValue = lptSellOrder.paymentValue.add(lptSellOrder.collateralValue);
        daiToken.transfer(msg.sender, totalValue);
    }

    /*
    * @notice Fulfill sell order, requires approval for this contract spend the orders LPT value.
    *         Returns the collateral and payment to the LPT seller.
    */
    function fulfillSellOrder() public {
        LptSellOrder storage lptSellOrder = lptSellOrders[msg.sender];

        require(lptSellOrder.buyerAddress != ZERO_ADDRESS, ERROR_SELL_ORDER_NOT_COMMITTED_TO);

        IERC20 livepeerToken = IERC20(_getLivepeerContractAddress("LivepeerToken"));
        require(livepeerToken.transferFrom(msg.sender, lptSellOrder.buyerAddress, lptSellOrder.lptValue), ERROR_LPT_TRANSFER_FAILED);

        uint256 totalValue = lptSellOrder.paymentValue.add(lptSellOrder.collateralValue);
        daiToken.transfer(msg.sender, totalValue);
    }

    function _getLivepeerContractAddress(string memory _livepeerContract) internal view returns (address) {
        bytes32 contractId = keccak256(abi.encodePacked(_livepeerContract));
        return livepeerController.getContract(contractId);
    }

    function _getUnbondingPeriodLength() internal view returns (uint256) {
        IBondingManager bondingManager = IBondingManager(_getLivepeerContractAddress("BondingManager"));
        uint64 unbondingPeriodRounds = bondingManager.unbondingPeriod();

        IRoundsManager roundsManager = IRoundsManager(_getLivepeerContractAddress("RoundsManager"));
        uint256 roundLength = roundsManager.roundLength();

        return roundLength.mul(unbondingPeriodRounds);
    }
}
