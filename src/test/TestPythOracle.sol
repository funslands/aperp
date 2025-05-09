// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract TestPythOracle is IPyth {

    mapping(bytes32=> PythStructs.Price) public prices;

    function getPriceUnsafe(
        bytes32 id
    ) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view override returns (PythStructs.Price memory price) {
        (age);
        return prices[id];
    }

    function getEmaPriceUnsafe(
        bytes32 id
    ) external view override returns (PythStructs.Price memory price) {
        return prices[id];
    }

    function getEmaPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view override returns (PythStructs.Price memory price) {
        (age);
        return prices[id];
    }

    error InvalidFee();
    function updatePriceFeeds(bytes[] calldata updateData) public payable {
        uint len = updateData.length;
        require(msg.value >= len, InvalidFee());
        for(uint i=0; i<len; i++) {
            (bytes32 feedId, int64 price) = abi.decode(updateData[i], (bytes32, int64));
            prices[feedId] = PythStructs.Price({
                price: price,
                conf: 1,
                expo: -8,
                publishTime: block.timestamp
            });
        }
    }
    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    ) external payable {
        (priceIds, publishTimes);
        updatePriceFeeds(updateData);
    }

    function getUpdateFee(
        bytes[] calldata updateData
    ) external override view returns (uint feeAmount) {
        (block.timestamp);
        return updateData.length;
    }

    function parsePriceFeedUpdates(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) public payable override returns (PythStructs.PriceFeed[] memory priceFeeds) {
        (priceIds, minPublishTime, maxPublishTime);
        updatePriceFeeds(updateData);
        uint len = updateData.length;
        priceFeeds = new PythStructs.PriceFeed[](len);
        for (uint i=0; i<len; i++) {
            PythStructs.Price memory p = prices[priceIds[i]];
            priceFeeds[i] = PythStructs.PriceFeed({
                id: priceIds[i],
                price: p,
                emaPrice: p
            });
        }
    }

    function parsePriceFeedUpdatesUnique(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64 minPublishTime,
        uint64 maxPublishTime
    ) external payable override returns (PythStructs.PriceFeed[] memory priceFeeds) {
        return parsePriceFeedUpdates(updateData, priceIds, minPublishTime, maxPublishTime);
    }
}