// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.0;

interface ISwapContractMin {
    function getCurrentPriceLP() external view returns (uint256);

    function getDepositFeeRate(address _token, uint256 _amountOfFloat)
        external
        view
        returns (uint256);

    function getFloatReserve(address _tokenA, address _tokenB)
        external
        view
        returns (uint256 reserveA, uint256 reserveB);
}
