// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.17;

import "../Errors.sol";
import "./LogExpMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/* solhint-disable private-vars-leading-underscore */

library FixedPoint {
  using SafeCast for uint256;
  using SafeCast for int256;

  uint256 internal constant ONE = 1e18; // 18 decimal places
  uint256 internal constant TWO = 2 * ONE;
  uint256 internal constant FOUR = 4 * ONE;
  uint256 internal constant MAX_POW_RELATIVE_ERROR = 10000; // 10^(-14)

  // Minimum base for the power function when the exponent is 'free' (larger than ONE).
  uint256 internal constant MIN_POW_BASE_FREE_EXPONENT = 0.7e18;

  function abs(int256 a) internal pure returns (uint256 result) {
    // Equivalent to:
    // result = a > 0 ? ua.toInt256() : uint256(-a)
    assembly {
      let s := sar(255, a)
      result := sub(xor(a, s), s)
    }
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    // Fixed Point addition is the same as regular checked addition

    uint256 c = a + b;
    _require(c >= a, Errors.ADD_OVERFLOW);
    return c;
  }

  function add(int256 a, int256 b) internal pure returns (int256) {
    int256 c = a + b;
    _require((b >= 0 && c >= a) || (b < 0 && c < a), Errors.ADD_OVERFLOW);
    return c;
  }

  function add(uint256 a, int256 b) internal pure returns (int256) {
    return add(a.toInt256(), b);
  }

  function add(int256 a, uint256 b) internal pure returns (int256) {
    return add(a, b.toInt256());
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    // Fixed Point addition is the same as regular checked addition

    _require(b <= a, Errors.SUB_OVERFLOW);
    uint256 c = a - b;
    return c;
  }

  function sub(int256 a, int256 b) internal pure returns (int256) {
    int256 c = a - b;
    _require((b >= 0 && c <= a) || (b < 0 && c > a), Errors.SUB_OVERFLOW);
    return c;
  }

  function sub(uint256 a, int256 b) internal pure returns (int256) {
    return sub(a.toInt256(), b);
  }

  function sub(int256 a, uint256 b) internal pure returns (int256) {
    return sub(a, b.toInt256());
  }

  function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 product = a * b;
    _require(a == 0 || product / a == b, Errors.MUL_OVERFLOW);

    return product / ONE;
  }

  function mulDown(int256 a, int256 b) internal pure returns (int256) {
    int256 product = a * b;
    _require(a == 0 || product / a == b, Errors.MUL_OVERFLOW);

    return product / int256(ONE);
  }

  function mulDown(uint256 a, int256 b) internal pure returns (int256) {
    return mulDown(a.toInt256(), b);
  }

  function mulDown(int256 a, uint256 b) internal pure returns (int256) {
    return mulDown(a, b.toInt256());
  }

  function mulUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
    uint256 product = a * b;
    _require(a == 0 || product / a == b, Errors.MUL_OVERFLOW);

    // The traditional divUp formula is:
    // divUp(x, y) := (x + y - 1) / y
    // To avoid intermediate overflow in the addition, we distribute the division and get:
    // divUp(x, y) := (x - 1) / y + 1
    // Note that this requires x != 0, if x == 0 then the result is zero
    //
    // Equivalent to:
    // result = product == 0 ? 0 : ((product - 1) / FixedPoint.ONE) + 1;
    assembly {
      result := mul(iszero(iszero(product)), add(div(sub(product, 1), ONE), 1))
    }
  }

  function mulUp(int256 a, int256 b) internal pure returns (int256 result) {
    int256 product = a * b;
    _require(a == 0 || product / a == b, Errors.MUL_OVERFLOW);

    // The traditional divUp formula is:
    // divUp(x, y) := (x + y - 1) / y
    // To avoid intermediate overflow in the addition, we distribute the division and get:
    // divUp(x, y) := (x - 1) / y + 1
    // Note that this requires x != 0, if x == 0 then the result is zero
    //
    // Equivalent to:
    // result = product == 0 ? 0 : ((product - 1) / FixedPoint.ONE) + 1;
    assembly {
      result := mul(iszero(iszero(product)), add(div(sub(product, 1), ONE), 1))
    }
  }

  function mulUp(uint256 a, int256 b) internal pure returns (int256) {
    return mulUp(a.toInt256(), b);
  }

  function mulUp(int256 a, uint256 b) internal pure returns (int256) {
    return mulDown(a, b.toInt256());
  }

  function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
    _require(b != 0, Errors.ZERO_DIVISION);

    uint256 aInflated = a * ONE;
    _require(a == 0 || aInflated / a == ONE, Errors.DIV_INTERNAL); // mul overflow

    return aInflated / b;
  }

  function divDown(int256 a, int256 b) internal pure returns (int256) {
    _require(b != 0, Errors.ZERO_DIVISION);

    int256 aInflated = a * int256(ONE);
    _require(a == 0 || aInflated / a == int256(ONE), Errors.DIV_INTERNAL); // mul overflow

    return aInflated / b;
  }

  function divDown(uint256 a, int256 b) internal pure returns (int256) {
    return divDown(a.toInt256(), b);
  }

  function divDown(int256 a, uint256 b) internal pure returns (int256) {
    return divDown(a, b.toInt256());
  }

  function divUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
    _require(b != 0, Errors.ZERO_DIVISION);

    uint256 aInflated = a * ONE;
    _require(a == 0 || aInflated / a == ONE, Errors.DIV_INTERNAL); // mul overflow

    // The traditional divUp formula is:
    // divUp(x, y) := (x + y - 1) / y
    // To avoid intermediate overflow in the addition, we distribute the division and get:
    // divUp(x, y) := (x - 1) / y + 1
    // Note that this requires x != 0, if x == 0 then the result is zero
    //
    // Equivalent to:
    // result = a == 0 ? 0 : (a * FixedPoint.ONE - 1) / b + 1;
    assembly {
      result := mul(
        iszero(iszero(aInflated)),
        add(div(sub(aInflated, 1), b), 1)
      )
    }
  }

  /**
   * @dev Returns x^y, assuming both are fixed point numbers, rounding down. The result is guaranteed to not be above
   * the true value (that is, the error function expected - actual is always positive).
   */
  function powDown(uint256 x, uint256 y) internal pure returns (uint256) {
    // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
    // and 80/20 Weighted Pools
    if (y == ONE) {
      return x;
    } else if (y == TWO) {
      return mulDown(x, x);
    } else if (y == FOUR) {
      uint256 square = mulDown(x, x);
      return mulDown(square, square);
    } else {
      uint256 raw = LogExpMath.pow(x, y);
      uint256 maxError = add(mulUp(raw, MAX_POW_RELATIVE_ERROR), uint256(1));

      if (raw < maxError) {
        return 0;
      } else {
        return sub(raw, maxError);
      }
    }
  }

  /**
   * @dev Returns x^y, assuming both are fixed point numbers, rounding up. The result is guaranteed to not be below
   * the true value (that is, the error function expected - actual is always negative).
   */
  function powUp(uint256 x, uint256 y) internal pure returns (uint256) {
    // Optimize for when y equals 1.0, 2.0 or 4.0, as those are very simple to implement and occur often in 50/50
    // and 80/20 Weighted Pools
    if (y == ONE) {
      return x;
    } else if (y == TWO) {
      return mulUp(x, x);
    } else if (y == FOUR) {
      uint256 square = mulUp(x, x);
      return mulUp(square, square);
    } else {
      uint256 raw = LogExpMath.pow(x, y);
      uint256 maxError = add(mulUp(raw, MAX_POW_RELATIVE_ERROR), uint256(1));

      return add(raw, maxError);
    }
  }

  /**
   * @dev Returns the complement of a value (1 - x), capped to 0 if x is larger than 1.
   *
   * Useful when computing the complement for values with some level of relative error, as it strips this error and
   * prevents intermediate negative values.
   */
  function complement(uint256 x) internal pure returns (uint256 result) {
    // Equivalent to:
    // result = (x < ONE) ? (ONE - x) : 0;
    assembly {
      result := mul(lt(x, ONE), sub(ONE, x))
    }
  }

  /**
   * @dev Returns the largest of two numbers of 256 bits.
   */
  function max(uint256 a, uint256 b) internal pure returns (uint256 result) {
    // Equivalent to:
    // result = (a < b) ? b : a;
    assembly {
      result := sub(a, mul(sub(a, b), lt(a, b)))
    }
  }

  /**
   * @dev Returns the smallest of two numbers of 256 bits.
   */
  function min(uint256 a, uint256 b) internal pure returns (uint256 result) {
    // Equivalent to `result = (a < b) ? a : b`
    assembly {
      result := sub(a, mul(sub(a, b), gt(a, b)))
    }
  }
}
