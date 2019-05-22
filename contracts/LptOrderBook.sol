pragma solidity ^0.5.7;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./livepeerInterface/IController.sol";
import "./livepeerInterface/IBondingManager.sol";
import "./livepeerInterface/IRoundsManager.sol";

contract LptOrderBook {

    using SafeMath for uint256;

    address private constant ZERO_ADDRESS = address(0);

    string internal constant ERROR_BUY_ORDER_COMMITTED_TO = "LPT_ORDER_BUY_ORDER_COMMITTED_TO";
    string internal constant ERROR_BUY_ORDER_NOT_COMMITTED_TO = "LPT_ORDER_BUY_ORDER_NOT_COMMITTED_TO";
    string internal constant ERROR_NOT_SELLER = "LPT_ORDER_NOT_SELLER";

    string internal constant ERROR_DELIVERED_BY_IN_PAST = "LPT_ORDER_DELIVERED_BY_IN_PAST";
    string internal constant ERROR_SELL_ORDER_COMMITTED_TO = "LPT_ORDER_SELL_ORDER_COMMITTED_TO";
    string internal constant ERROR_SELL_ORDER_NOT_COMMITTED_TO = "LPT_ORDER_SELL_ORDER_NOT_COMMITTED_TO";
    string internal constant ERROR_INITIALISED_ORDER = "LPT_ORDER_INITIALISED_ORDER";
    string internal constant ERROR_UNINITIALISED_ORDER = "LPT_ORDER_UNINITIALISED_ORDER";
    string internal constant ERROR_COMMITMENT_WITHIN_UNBONDING_PERIOD = "LPT_ORDER_COMMITMENT_WITHIN_UNBONDING_PERIOD";
    string internal constant ERROR_NOT_BUYER = "LPT_ORDER_NOT_BUYER";
    string internal constant ERROR_STILL_WITHIN_LOCK_PERIOD = "LPT_ORDER_STILL_WITHIN_LOCK_PERIOD";

    struct LptBuyOrder {
        uint256 lptBuyValue;
        uint256 daiPaymentValue;
        uint256 daiCollateralValue;
        uint256 deliveredByBlock;
        address sellerAddress;
    }

    struct LptSellOrder {
        uint256 lptSellValue;
        uint256 daiPaymentValue;
        uint256 daiCollateralValue;
        uint256 deliveredByBlock;
        address buyerAddress;
    }

    IController livepeerController;
    IERC20 daiToken;
    
    mapping(address => LptBuyOrder) public lptBuyOrders; // One buy order per address for simplicity
    mapping(address => LptSellOrder) public lptSellOrders; // One sell order per address for simplicity

    constructor(address _livepeerController, address _daiToken) public {
        livepeerController = IController(_livepeerController);
        daiToken = IERC20(_daiToken);
    }

    /*
    * @notice Create an LPT sell order, requires approval for this contract to spend `_daiCollateralValue` amount of DAI.
    * @param _lptSellValue Value of LPT to sell
    * @param _daiPaymentValue Value required in exchange for LPT
    * @param _daiCollateralValue Value of collateral
    * @param _deliveredByBlock Order filled or cancelled by this block or the collateral can be claimed
    */
    function createLptSellOrder(uint256 _lptSellValue, uint256 _daiPaymentValue, uint256 _daiCollateralValue, uint256 _deliveredByBlock) public {
        LptSellOrder storage lptSellOrder = lptSellOrders[msg.sender];

        require(lptSellOrder.daiCollateralValue == 0, ERROR_INITIALISED_ORDER);
        require(_deliveredByBlock > block.number, ERROR_DELIVERED_BY_IN_PAST);

        daiToken.transferFrom(msg.sender, address(this), _daiCollateralValue);

        lptSellOrders[msg.sender] = LptSellOrder(_lptSellValue, _daiPaymentValue, _daiCollateralValue, _deliveredByBlock, ZERO_ADDRESS);
    }

    /*
    * @notice Cancel an LPT sell order, must be executed by the sell order creator.
    */
    function cancelLptSellOrder() public {
        LptSellOrder storage lptSellOrder = lptSellOrders[msg.sender];

        require(lptSellOrder.buyerAddress == ZERO_ADDRESS, ERROR_SELL_ORDER_COMMITTED_TO);

        daiToken.transfer(msg.sender, lptSellOrder.daiCollateralValue);
        delete lptSellOrders[msg.sender];
    }

    /*
    * @notice Commit to buy LPT, requires approval for this contract to spend the payment amount in DAI.
    * @param _sellOrderCreator Address of sell order creator
    */
    function commitToBuyLpt(address _sellOrderCreator) public {
        LptSellOrder storage lptSellOrder = lptSellOrders[_sellOrderCreator];

        require(lptSellOrder.lptSellValue > 0, ERROR_UNINITIALISED_ORDER);
        require(lptSellOrder.buyerAddress == ZERO_ADDRESS, ERROR_SELL_ORDER_COMMITTED_TO);
        require(lptSellOrder.deliveredByBlock.sub(_getUnbondingPeriodLength()) > block.number, ERROR_COMMITMENT_WITHIN_UNBONDING_PERIOD);

        daiToken.transferFrom(msg.sender, address(this), lptSellOrder.daiPaymentValue);

        lptSellOrder.buyerAddress = msg.sender;
    }

    /*
    * @notice Claim collateral and payment after a sell order has been committed to but it hasn't been delivered by
    *         the block number specified.
    * @param _sellOrderCreator Address of sell order creator
    */
    function claimSellOrderCollateralAndPayment(address _sellOrderCreator) public {
        LptSellOrder storage lptSellOrder = lptSellOrders[_sellOrderCreator];

        require(lptSellOrder.buyerAddress == msg.sender, ERROR_NOT_BUYER);
        require(lptSellOrder.deliveredByBlock < block.number, ERROR_STILL_WITHIN_LOCK_PERIOD);

        uint256 totalValue = lptSellOrder.daiPaymentValue.add(lptSellOrder.daiCollateralValue);
        daiToken.transfer(msg.sender, totalValue);
    }

    /*
    * @notice Fulfill sell order, requires approval for this contract spend the orders LPT value from the seller.
    *         Returns the collateral and payment to the LPT seller.
    */
    function fulfillSellOrder() public {
        LptSellOrder storage lptSellOrder = lptSellOrders[msg.sender];

        require(lptSellOrder.buyerAddress != ZERO_ADDRESS, ERROR_SELL_ORDER_NOT_COMMITTED_TO);

        IERC20 livepeerToken = IERC20(_getLivepeerContractAddress("LivepeerToken"));
        livepeerToken.transferFrom(msg.sender, lptSellOrder.buyerAddress, lptSellOrder.lptSellValue);

        uint256 totalValue = lptSellOrder.daiPaymentValue.add(lptSellOrder.daiCollateralValue);
        daiToken.transfer(msg.sender, totalValue);

        delete lptSellOrders[msg.sender];
    }

    /*
    * @notice Create an LPT buy order, requires approval for this contract to spend _daiPaymentValue amount of DAI.
    * @param _lptBuyValue Value of LPT to buy
    * @param _daiPaymentValue Value offered in exchange for LPT
    * @param _daiCollateralValue Value required of collateral
    * @param _deliveredByBlock Order filled or cancelled by this block or the collateral can be claimed
    */
    function createLptBuyOrder(uint256 _lptBuyValue, uint256 _daiPaymentValue, uint256 _daiCollateralValue, uint256 _deliveredByBlock) public {
        LptBuyOrder storage lptBuyOrder = lptBuyOrders[msg.sender];

        require(_deliveredByBlock > block.number, ERROR_DELIVERED_BY_IN_PAST);
        require(lptBuyOrder.daiPaymentValue == 0, ERROR_INITIALISED_ORDER);

        daiToken.transferFrom(msg.sender, address(this), _daiPaymentValue);

        lptBuyOrders[msg.sender] = LptBuyOrder(_lptBuyValue, _daiPaymentValue, _daiCollateralValue, _deliveredByBlock, ZERO_ADDRESS);
    }

    /*
    * @notice Cancel an LPT buy order, must be executed by the buy order creator.
    */
    function cancelLptBuyOrder() public {
        LptBuyOrder storage lptBuyOrder = lptBuyOrders[msg.sender];

        require(lptBuyOrder.sellerAddress == ZERO_ADDRESS, ERROR_BUY_ORDER_COMMITTED_TO);

        daiToken.transfer(msg.sender, lptBuyOrder.daiPaymentValue);
        delete lptBuyOrders[msg.sender];
    }

    /*
    * @notice Commit to sell LPT, requires approval for this contract to spend the collateral amount in DAI.
    * @param _buyOrderCreator Address of buy order creator
    */
    function commitToSellLpt(address _buyOrderCreator) public {
        LptBuyOrder storage lptBuyOrder = lptBuyOrders[_buyOrderCreator];

        require(lptBuyOrder.lptBuyValue > 0, ERROR_UNINITIALISED_ORDER);
        require(lptBuyOrder.sellerAddress == ZERO_ADDRESS, ERROR_BUY_ORDER_COMMITTED_TO);
        require(lptBuyOrder.deliveredByBlock.sub(_getUnbondingPeriodLength()) > block.number, ERROR_COMMITMENT_WITHIN_UNBONDING_PERIOD);

        daiToken.transferFrom(msg.sender, address(this), lptBuyOrder.daiCollateralValue);

        lptBuyOrder.sellerAddress = msg.sender;
    }

    /*
    * @notice Claim collateral and payment after a buy order has been committed to but it hasn't been delivered by
    *         the block number specified.
    */
    function claimBuyOrderPaymentAndCollateral() public {
        LptBuyOrder storage lptBuyOrder = lptBuyOrders[msg.sender];

        require(lptBuyOrder.sellerAddress != ZERO_ADDRESS, ERROR_BUY_ORDER_NOT_COMMITTED_TO);
        require(lptBuyOrder.deliveredByBlock < block.number, ERROR_STILL_WITHIN_LOCK_PERIOD);

        uint256 totalValue = lptBuyOrder.daiPaymentValue.add(lptBuyOrder.daiCollateralValue);
        daiToken.transfer(msg.sender, totalValue);
    }

    /*
    * @notice Fulfill buy order, requires approval for this contract spend the order's LPT value from the seller.
    *         Sends the collateral and payment to the LPT seller.
    * @param _buyOrderCreator Address of buy order creator
    */
    function fulfillBuyOrder(address _buyOrderCreator) public {
        LptBuyOrder storage lptBuyOrder = lptBuyOrders[_buyOrderCreator];

        require(lptBuyOrder.sellerAddress == msg.sender, ERROR_NOT_SELLER);

        IERC20 livepeerToken = IERC20(_getLivepeerContractAddress("LivepeerToken"));
        livepeerToken.transferFrom(msg.sender, _buyOrderCreator, lptBuyOrder.lptBuyValue);

        uint256 totalValue = lptBuyOrder.daiPaymentValue.add(lptBuyOrder.daiCollateralValue);
        daiToken.transfer(msg.sender, totalValue);

        delete lptBuyOrders[lptBuyOrder.sellerAddress];
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
