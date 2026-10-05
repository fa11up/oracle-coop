// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {OracleCoopHub} from "../src/OracleCoopHub.sol";
import {CoopConsumer} from "../src/CoopConsumer.sol";

/// @dev Signs with a test key. The production signer path is proven separately in LiveAttestation.t.sol.
contract HubHarness is OracleCoopHub {
    address private immutable _signer;

    constructor(address signer_) {
        _signer = signer_;
    }

    function _attester() internal view override returns (address) {
        return _signer;
    }
}

contract Member is CoopConsumer {
    constructor(OracleCoopHub hub_, bytes32 id_, uint256 maxAge_, uint256 dev_, uint16 minAgreed_)
        CoopConsumer(hub_, id_, maxAge_, dev_, minAgreed_)
    {}

    function read() external returns (uint256) {
        return _refresh();
    }
}

contract Reverter {
    function pull(OracleCoopHub hub) external {
        hub.withdraw();
    }

    receive() external payable {
        revert("no");
    }
}

contract OracleCoopHubTest is Test {
    uint256 constant SIGNER_PK = 0xA11CE;
    address signer;
    HubHarness hub;
    bytes32 id;
    uint64 nextTo = 1_000;
    uint256 nonce;

    bytes constant PREFIX =
        '{"answerType":"uint256","chainId":1,"question":"Median IMD/ETH spot over the window","v":1,"window":{"fromBlock":';

    function setUp() public {
        vm.warp(1_800_000_000);
        signer = vm.addr(SIGNER_PK);
        hub = new HubHarness(signer);
        id = hub.register(_question(0, 0));
    }

    // ------------------------------------------------------------------ helpers

    function _question(uint128 bounty, uint32 interval) internal pure returns (OracleCoopHub.Question memory) {
        return OracleCoopHub.Question({
            prefix: PREFIX,
            dataChainId: 1,
            answerType: 3,
            minSpan: 300,
            maxSpan: 1200,
            minPanel: 25,
            minAgreed: 15,
            bountyWei: bounty,
            paidInterval: interval
        });
    }

    function _att(bytes32 qid, uint256 figure) internal returns (OracleCoopHub.Attestation memory a) {
        nextTo += 600;
        a = OracleCoopHub.Attestation({
            requestId: keccak256(abi.encode("req", ++nonce)),
            chainId: 1,
            questionHash: hub.expectedQuestionHash(qid, nextTo - 600, nextTo),
            answerType: 3,
            answer: abi.encode(figure),
            figure: figure,
            fromBlock: nextTo - 600,
            toBlock: nextTo,
            blockHash: keccak256(abi.encode(nextTo)),
            panelJobId: keccak256(abi.encode("job", nonce)),
            panelSize: 60,
            quorum: 20,
            agreed: 20,
            issuedAt: uint64(block.timestamp),
            expiresAt: uint64(block.timestamp + 1 days)
        });
    }

    function _sign(OracleCoopHub h, OracleCoopHub.Attestation memory a, uint256 pk)
        internal
        view
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, h.digest(a));
        return abi.encodePacked(r, s, v);
    }

    function _submit(bytes32 qid, OracleCoopHub.Attestation memory a) internal returns (bool) {
        return hub.submit(qid, a, _sign(hub, a, SIGNER_PK), address(this));
    }

    /// @dev Signs BEFORE arming expectRevert: signing calls hub.digest(), an external call that would
    /// otherwise consume the expectation.
    function _submitExpecting(bytes32 qid, OracleCoopHub.Attestation memory a, bytes memory err) internal {
        bytes memory sig = _sign(hub, a, SIGNER_PK);
        vm.expectRevert(err);
        hub.submit(qid, a, sig, address(this));
    }

    // ------------------------------------------------------------------ registration

    function test_RegisterIsContentAddressedAndImmutable() public {
        OracleCoopHub.Question memory q = _question(0, 0);
        assertEq(hub.questionId(q), id);
        vm.expectRevert(abi.encodeWithSelector(OracleCoopHub.AlreadyRegistered.selector, id));
        hub.register(q);
        q.minAgreed = 16;
        assertTrue(hub.register(q) != id, "any change is a new question");
    }

    function test_RegisterRejectsBadConfig() public {
        OracleCoopHub.Question memory q = _question(0, 0);
        q.prefix = bytes('{"question":"no window marker"');
        vm.expectRevert(OracleCoopHub.InvalidQuestion.selector);
        hub.register(q);

        q = _question(0, 0);
        q.minPanel = 4;
        vm.expectRevert(OracleCoopHub.InvalidQuestion.selector);
        hub.register(q);

        q = _question(0, 0);
        q.minAgreed = 26;
        vm.expectRevert(OracleCoopHub.InvalidQuestion.selector);
        hub.register(q);

        q = _question(0, 0);
        q.minSpan = 0;
        vm.expectRevert(OracleCoopHub.InvalidQuestion.selector);
        hub.register(q);

        q = _question(1 ether, 599); // a bounty paid more often than the plane can even schedule
        vm.expectRevert(OracleCoopHub.InvalidQuestion.selector);
        hub.register(q);
    }

    function test_UnknownQuestionReverts() public {
        bytes32 nope = keccak256("nope");
        vm.expectRevert(abi.encodeWithSelector(OracleCoopHub.UnknownQuestion.selector, nope));
        hub.fund{value: 1}(nope);
        vm.expectRevert(abi.encodeWithSelector(OracleCoopHub.UnknownQuestion.selector, nope));
        hub.latest(nope);
    }

    // ------------------------------------------------------------------ verification

    function test_AcceptsValidAttestation() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        _submit(id, a);
        OracleCoopHub.Observation memory o = hub.latest(id);
        assertEq(o.sequence, 1);
        assertEq(o.figure, 3e15);
        assertEq(o.toBlock, a.toBlock);
        assertEq(o.receivedAt, block.timestamp);
        assertTrue(hub.usedRequests(a.requestId));
    }

    /// @notice The audit-HIGH shape: a genuine signature, addressed to this hub, answering a question
    /// of the buyer's choosing. Only question binding stops it.
    function test_RejectsGenuineSignatureForAnotherQuestion() public {
        OracleCoopHub.Attestation memory a = _att(id, 1);
        a.questionHash = keccak256("whatever the buyer asked");
        _submitExpecting(
            id,
            a,
            abi.encodeWithSelector(
                OracleCoopHub.WrongQuestion.selector,
                hub.expectedQuestionHash(id, a.fromBlock, a.toBlock),
                a.questionHash
            )
        );
    }

    function test_RejectsWrongSigner() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        bytes memory sig = _sign(hub, a, 0xBAD);
        vm.expectRevert(OracleCoopHub.InvalidSignature.selector);
        hub.submit(id, a, sig, address(this));
    }

    function test_RejectsSignatureForAnotherHub() public {
        HubHarness other = new HubHarness(signer);
        other.register(_question(0, 0));
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        bytes memory sigForOther = _sign(other, a, SIGNER_PK);
        vm.expectRevert(OracleCoopHub.InvalidSignature.selector);
        hub.submit(id, a, sigForOther, address(this));
    }

    function test_RejectsMalleableSignature() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, hub.digest(a));
        uint256 n = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141;
        bytes memory flipped = abi.encodePacked(r, bytes32(n - uint256(s)), v == 27 ? uint8(28) : uint8(27));
        vm.expectRevert(OracleCoopHub.InvalidSignature.selector);
        hub.submit(id, a, flipped, address(this));
    }

    function test_RejectsReplay() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        _submit(id, a);
        // Same request id, re-signed over a later window: still refused.
        a.fromBlock += 600;
        a.toBlock += 600;
        a.questionHash = hub.expectedQuestionHash(id, a.fromBlock, a.toBlock);
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.ReplayedAttestation.selector));
    }

    function test_RejectsNonAdvancingWindow() public {
        OracleCoopHub.Attestation memory first = _att(id, 3e15);
        _submit(id, first);
        OracleCoopHub.Attestation memory old = _att(id, 3e15);
        old.fromBlock = first.fromBlock - 1;
        old.toBlock = first.toBlock - 1;
        old.questionHash = hub.expectedQuestionHash(id, old.fromBlock, old.toBlock);
        _submitExpecting(
            id, old, abi.encodeWithSelector(OracleCoopHub.WindowNotAdvancing.selector, old.toBlock, first.toBlock)
        );
    }

    function test_RejectsSpanOutOfRange() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        a.fromBlock = a.toBlock - 1; // a single-block "median"
        a.questionHash = hub.expectedQuestionHash(id, a.fromBlock, a.toBlock);
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.WindowSpanOutOfRange.selector, uint64(1)));
    }

    /// @notice Floors are counts. 20 agreeing of 60 passes a floor of 15, as live answers need it to.
    function test_EnforcesCountsNotRatio() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        a.agreed = 14;
        a.quorum = 14;
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.NotEnoughAgreement.selector));
        a.agreed = 15;
        a.quorum = 15;
        _submit(id, a);
    }

    function test_RejectsThinPanelAndImpossibleCounts() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        a.panelSize = 24;
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.PanelTooSmall.selector));
        a.panelSize = 30;
        a.agreed = 31;
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.NotEnoughAgreement.selector));
    }

    function test_RejectsWrongDataChainAndAnswerType() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        a.chainId = 8453;
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.WrongDataChain.selector));
        a.chainId = 1;
        a.answerType = 0;
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.WrongAnswerType.selector));
    }

    function test_RejectsExpiredFutureAndBackdated() public {
        OracleCoopHub.Attestation memory a = _att(id, 3e15);
        a.expiresAt = uint64(block.timestamp - 1);
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.ExpiredAttestation.selector));

        a = _att(id, 3e15);
        a.issuedAt = uint64(block.timestamp + 1);
        _submitExpecting(id, a, abi.encodeWithSelector(OracleCoopHub.InvalidTimestamp.selector));

        a = _att(id, 3e15);
        _submit(id, a);
        OracleCoopHub.Attestation memory older = _att(id, 3e15);
        older.issuedAt = a.issuedAt - 1; // later window, earlier issue time
        _submitExpecting(id, older, abi.encodeWithSelector(OracleCoopHub.InvalidTimestamp.selector));
    }

    // ------------------------------------------------------------------ funding

    function test_BountyPaidOncePerInterval() public {
        bytes32 paidId = hub.register(_question(0.01 ether, 3600));
        hub.fund{value: 0.05 ether}(paidId);

        assertTrue(_submit(paidId, _att(paidId, 3e15)), "first update paid");
        assertEq(hub.credit(address(this)), 0.01 ether);

        vm.warp(block.timestamp + 1800);
        assertFalse(_submit(paidId, _att(paidId, 3e15)), "inside the interval: published, unpaid");
        assertEq(hub.latest(paidId).sequence, 2);

        vm.warp(block.timestamp + 1800);
        assertTrue(_submit(paidId, _att(paidId, 3e15)), "next interval paid");
        assertEq(hub.pool(paidId), 0.03 ether);
    }

    function test_EmptyPoolStillPublishes() public {
        bytes32 paidId = hub.register(_question(0.01 ether, 3600));
        assertFalse(_submit(paidId, _att(paidId, 3e15)));
        assertEq(hub.latest(paidId).sequence, 1);
        assertEq(hub.credit(address(this)), 0);
    }

    function test_PoolsAreIsolated() public {
        bytes32 a = hub.register(_question(0.01 ether, 3600));
        OracleCoopHub.Question memory qb = _question(0.01 ether, 3600);
        qb.minSpan = 301;
        bytes32 b = hub.register(qb);
        hub.fund{value: 0.01 ether}(a);
        assertFalse(_submit(b, _att(b, 3e15)), "b cannot spend a's pool");
        assertEq(hub.pool(a), 0.01 ether);
    }

    function test_WithdrawPullsCreditOnce() public {
        bytes32 paidId = hub.register(_question(0.01 ether, 3600));
        hub.fund{value: 0.01 ether}(paidId);
        OracleCoopHub.Attestation memory a = _att(paidId, 3e15);
        address relayer = makeAddr("relayer");
        hub.submit(paidId, a, _sign(hub, a, SIGNER_PK), relayer);

        vm.prank(relayer);
        hub.withdraw();
        assertEq(relayer.balance, 0.01 ether);
        vm.prank(relayer);
        vm.expectRevert(OracleCoopHub.ZeroAmount.selector);
        hub.withdraw();
    }

    function test_FailedTransferKeepsCredit() public {
        bytes32 paidId = hub.register(_question(0.01 ether, 3600));
        hub.fund{value: 0.01 ether}(paidId);
        Reverter r = new Reverter();
        OracleCoopHub.Attestation memory a = _att(paidId, 3e15);
        hub.submit(paidId, a, _sign(hub, a, SIGNER_PK), address(r));
        vm.expectRevert(OracleCoopHub.TransferFailed.selector);
        r.pull(hub);
        assertEq(hub.credit(address(r)), 0.01 ether);
    }

    // ------------------------------------------------------------------ reading

    function test_CheckedRejectsMissingStaleAndThin() public {
        vm.expectRevert(OracleCoopHub.NoObservation.selector);
        hub.checked(id, 1 hours, 15);

        _submit(id, _att(id, 3e15));
        hub.checked(id, 1 hours, 15);
        vm.expectRevert(OracleCoopHub.NotEnoughAgreement.selector);
        hub.checked(id, 1 hours, 21);

        uint64 issued = hub.latest(id).issuedAt;
        vm.warp(block.timestamp + 1 hours + 1);
        vm.expectRevert(abi.encodeWithSelector(OracleCoopHub.StaleObservation.selector, issued));
        hub.checked(id, 1 hours, 15);
    }

    function testFuzz_SpliceMatchesDocument(uint64 from, uint64 to) public view {
        bytes memory doc = bytes.concat(PREFIX, bytes(vm.toString(from)), ',"toBlock":', bytes(vm.toString(to)), "}}");
        assertEq(hub.expectedQuestionHash(id, from, to), keccak256(doc));
    }

    // ------------------------------------------------------------------ consumers

    /// @notice A member compares against ITS OWN last accepted value, so updates that are each inside
    /// the cap relative to the hub's previous one cannot walk the member past its cap between reads.
    function test_ConsumerCapIsCumulativeAgainstItsOwnValue() public {
        Member m = new Member(hub, id, 2 hours, 2_000, 15);
        _submit(id, _att(id, 100e15));
        assertEq(m.read(), 100e15);

        _submit(id, _att(id, 118e15)); // +18% on the hub's previous
        _submit(id, _att(id, 139e15)); // +17.8% on the hub's previous, +39% on the member's
        vm.expectRevert(abi.encodeWithSelector(CoopConsumer.CoopExcessDeviation.selector, 100e15, 139e15));
        m.read();
    }

    function test_ConsumersDisagreeIndependently() public {
        Member strict = new Member(hub, id, 2 hours, 500, 15);
        Member loose = new Member(hub, id, 2 hours, 2_000, 15);
        _submit(id, _att(id, 100e15));
        strict.read();
        loose.read();
        _submit(id, _att(id, 110e15));
        assertEq(loose.read(), 110e15);
        vm.expectRevert(abi.encodeWithSelector(CoopConsumer.CoopExcessDeviation.selector, 100e15, 110e15));
        strict.read();
    }

    function test_ConsumerReanchorsOnceItsOwnValueIsStale() public {
        Member m = new Member(hub, id, 1 hours, 2_000, 15);
        _submit(id, _att(id, 100e15));
        m.read();
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(CoopConsumer.CoopValueStale.selector);
        m.read();
        _submit(id, _att(id, 300e15)); // a genuine large move after a halt
        assertEq(m.read(), 300e15);
    }

    function test_ConsumerRejectsUnknownQuestionAndBadConfig() public {
        vm.expectRevert();
        new Member(hub, keccak256("nope"), 1 hours, 2_000, 15);
        vm.expectRevert(CoopConsumer.InvalidConsumerConfig.selector);
        new Member(hub, id, 0, 2_000, 15);
    }
}
