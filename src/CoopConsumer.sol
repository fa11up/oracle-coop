// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OracleCoopHub} from "./OracleCoopHub.sol";

/// @title CoopConsumer
/// @notice Base for a protocol that reads a co-op question. Each member keeps ITS OWN last accepted
/// value and applies its own age, agreement and deviation limits, so two members can read the same
/// hub and still disagree about whether a figure is safe.
/// @dev The deviation bound is measured against THIS consumer's last accepted value, not against the
/// hub's previous observation. Otherwise a run of updates, each inside the cap relative to the one
/// before, could walk a member's price past its cap between two of its own reads.
///
/// Call `_refresh()` only from price-sensitive paths (borrowing, withdrawing against collateral,
/// liquidating). Safe actions such as repaying or adding collateral should not depend on it, so they
/// keep working while the oracle is halted or refused.
abstract contract CoopConsumer {
    OracleCoopHub public immutable hub;
    bytes32 public immutable questionId;
    uint256 public immutable maxAge;
    uint256 public immutable maxDeviationBps;
    uint16 public immutable minAgreed;

    uint64 public lastSequence;
    uint256 private _value;
    uint64 private _issuedAt;

    event CoopValueAccepted(uint64 sequence, uint256 value, uint64 issuedAt);

    error InvalidConsumerConfig();
    error CoopValueStale();
    error CoopValueThin();
    error CoopZeroValue();
    error CoopExcessDeviation(uint256 current, uint256 proposed);

    constructor(OracleCoopHub hub_, bytes32 questionId_, uint256 maxAge_, uint256 maxDeviationBps_, uint16 minAgreed_) {
        if (address(hub_) == address(0) || maxAge_ == 0 || maxDeviationBps_ > 10_000 || minAgreed_ == 0) {
            revert InvalidConsumerConfig();
        }
        hub_.question(questionId_); // reverts on an unknown question
        hub = hub_;
        questionId = questionId_;
        maxAge = maxAge_;
        maxDeviationBps = maxDeviationBps_;
        minAgreed = minAgreed_;
    }

    /// @notice This consumer's accepted value and its signed issue time, with no freshness judgement.
    function coopValue() public view returns (uint256 value, uint64 issuedAt) {
        return (_value, _issuedAt);
    }

    /// @dev Pull the hub's newest observation if there is one, accept it against this consumer's own
    /// limits, and return a value that is fresh by this consumer's standard or revert.
    /// A deviation beyond the cap REVERTS rather than clamping: the price-sensitive action fails closed.
    /// Once this consumer's own value ages past maxAge the cap no longer applies and the next value
    /// re-anchors it, so an immutable consumer cannot be frozen forever by a genuine large move.
    function _refresh() internal returns (uint256) {
        OracleCoopHub.Observation memory o = hub.latest(questionId);
        if (o.sequence > lastSequence) {
            if (o.agreed < minAgreed) revert CoopValueThin();
            if (o.figure == 0) revert CoopZeroValue();
            if (lastSequence != 0 && !_tooOld(_issuedAt)) {
                uint256 change = o.figure > _value ? o.figure - _value : _value - o.figure;
                if (change > _bound(_value)) revert CoopExcessDeviation(_value, o.figure);
            }
            lastSequence = o.sequence;
            _value = o.figure;
            _issuedAt = o.issuedAt;
            emit CoopValueAccepted(o.sequence, o.figure, o.issuedAt);
        }
        if (lastSequence == 0 || _tooOld(_issuedAt)) revert CoopValueStale();
        return _value;
    }

    /// @dev floor(value * maxDeviationBps / 10_000) without the overflow a direct product can hit.
    function _bound(uint256 value) private view returns (uint256) {
        return (value / 10_000) * maxDeviationBps + ((value % 10_000) * maxDeviationBps) / 10_000;
    }

    function _tooOld(uint64 t) private view returns (bool) {
        return block.timestamp > t && block.timestamp - t > maxAge;
    }
}
