// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title OracleCoopHub
/// @notice One shared consumer of IdentityMD swarm oracle attestations. Each question is verified once
/// here and read by every protocol that wants it, and anyone may fund a question's update bounty.
/// @dev Design decisions and what this version deliberately leaves out are in docs/DESIGN.md.
///
/// THE ONE AUTHORITY is the service signer, a source constant. There is no owner, no admin, no
/// upgrade path, no setter and no fee. A question, once registered, can never change: a different
/// question is a different id that consumers must adopt explicitly.
///
/// WHAT A STORED OBSERVATION PROVES, and nothing more: the service signed this figure as the answer
/// to exactly this question document over a window that moved forward, with at least this many panel
/// members agreeing. Whether that figure is safe to act on (age, deviation from the last value you
/// accepted, your own agreement floor) is each consumer's decision; see CoopConsumer.
contract OracleCoopHub {
    // ------------------------------------------------------------------ types

    /// @dev Field-for-field the plane's signed struct, EIP-712 domain "IdentityMD Oracle" version 2.
    struct Attestation {
        bytes32 requestId;
        uint256 chainId; // the chain the question is ABOUT, not the chain this hub runs on
        bytes32 questionHash;
        uint8 answerType; // bool=0, address=1, bytes32=2, uint256=3 (recovered from live signatures)
        bytes answer;
        uint256 figure;
        uint64 fromBlock;
        uint64 toBlock;
        bytes32 blockHash;
        bytes32 panelJobId;
        uint16 panelSize;
        uint16 quorum;
        uint16 agreed;
        uint64 issuedAt;
        uint64 expiresAt;
    }

    /// @notice Everything that defines a question. Its id is the hash of all of it.
    struct Question {
        /// Canonical question document up to and including `,"window":{"fromBlock":`. The hub splices
        /// the attestation's signed fromBlock/toBlock back in and recomputes the hash the service signed.
        bytes prefix;
        /// Chain the question reads (`chainId` in the signed struct).
        uint64 dataChainId;
        uint8 answerType;
        /// Window span bounds in data-chain blocks.
        uint64 minSpan;
        uint64 maxSpan;
        /// Hard floors, as COUNTS. `agreed` equals `quorum` on live attestations, so a ratio floor would
        /// only force a higher request quorum and get requests refused.
        uint16 minPanel;
        uint16 minAgreed;
        /// Bounty paid from this question's pool for an update, at most once per `paidInterval` seconds
        /// of signed issue time. Zero bounty means the question is published but never paid for.
        uint128 bountyWei;
        uint32 paidInterval;
    }

    struct Observation {
        uint64 sequence;
        uint64 fromBlock;
        uint64 toBlock;
        uint64 issuedAt;
        uint64 expiresAt;
        uint64 receivedAt;
        uint16 panelSize;
        uint16 agreed;
        bytes32 requestId;
        uint256 figure;
        bytes answer;
    }

    // ------------------------------------------------------------------ constants

    /// @notice The IdentityMD oracle service key. The only privileged address in this contract.
    address public constant SERVICE_SIGNER = 0x5598Aa9146215Bc13eb26f2c692Ad1461Fd32982;

    /// @notice Smallest panel the plane accepts for an oracle request (`/requests/capabilities`).
    uint16 public constant PLANE_MIN_PANEL = 5;
    /// @notice Shortest paid interval; the plane schedules oracle questions no more often than this.
    uint32 public constant MIN_PAID_INTERVAL = 600;
    uint256 public constant MAX_PREFIX_BYTES = 8192;

    bytes32 public constant ATTESTATION_TYPEHASH = keccak256(
        "OracleAttestation(bytes32 requestId,uint256 chainId,bytes32 questionHash,uint8 answerType,bytes answer,uint256 figure,uint64 fromBlock,uint64 toBlock,bytes32 blockHash,bytes32 panelJobId,uint16 panelSize,uint16 quorum,uint16 agreed,uint64 issuedAt,uint64 expiresAt)"
    );
    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes private constant _WINDOW_MARKER = ',"window":{"fromBlock":';
    uint256 private constant _HALF_CURVE_ORDER = 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;

    // ------------------------------------------------------------------ state

    mapping(bytes32 id => Question) private _questions;
    mapping(bytes32 id => Observation) private _latest;
    /// @notice Unspent bounty funds per question. Sponsorship is final in this version (docs/DESIGN.md).
    mapping(bytes32 id => uint256) public pool;
    /// @notice Signed issue time of the last update a bounty was paid for.
    mapping(bytes32 id => uint64) public lastPaidAt;
    /// @notice Request ids already accepted, across every question.
    mapping(bytes32 requestId => bool) public usedRequests;
    /// @notice Bounties earned and not yet withdrawn.
    mapping(address account => uint256) public credit;

    // ------------------------------------------------------------------ events and errors

    event QuestionRegistered(bytes32 indexed id, address indexed registrant, uint64 dataChainId, uint8 answerType);
    event Funded(bytes32 indexed id, address indexed sponsor, uint256 amount);
    event Published(bytes32 indexed id, bytes32 indexed requestId, uint64 sequence, uint64 toBlock, uint256 figure);
    event BountyCredited(bytes32 indexed id, address indexed beneficiary, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);

    error InvalidQuestion();
    error AlreadyRegistered(bytes32 id);
    error UnknownQuestion(bytes32 id);
    error ZeroAmount();
    error WrongDataChain();
    error WrongAnswerType();
    error PanelTooSmall();
    error NotEnoughAgreement();
    error InvalidTimestamp();
    error ExpiredAttestation();
    error ReplayedAttestation();
    error InvalidWindow();
    error WindowSpanOutOfRange(uint64 span);
    error WindowNotAdvancing(uint64 toBlock, uint64 lastAccepted);
    error WrongQuestion(bytes32 expected, bytes32 given);
    error InvalidSignature();
    error NoObservation();
    error StaleObservation(uint64 issuedAt);
    error TransferFailed();

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("IdentityMD Oracle"),
                keccak256("2"),
                block.chainid,
                address(this)
            )
        );
    }

    // ------------------------------------------------------------------ questions

    /// @notice A question's id: the hash of its whole definition, so it cannot be rewritten.
    function questionId(Question calldata q) public pure returns (bytes32) {
        return keccak256(abi.encode(q));
    }

    /// @notice Register a question. Permissionless; registering confers no rights over it.
    function register(Question calldata q) external returns (bytes32 id) {
        _validate(q);
        id = questionId(q);
        if (_questions[id].prefix.length != 0) revert AlreadyRegistered(id);
        _questions[id] = q;
        emit QuestionRegistered(id, msg.sender, q.dataChainId, q.answerType);
    }

    function question(bytes32 id) external view returns (Question memory) {
        return _known(id);
    }

    /// @notice The questionHash this hub accepts for question `id` over a given window.
    /// @dev Public so anyone can check, before paying for a request, that the payload they are about to
    /// buy is the question this hub pins. One character of difference is an attestation the hub refuses.
    function expectedQuestionHash(bytes32 id, uint64 fromBlock, uint64 toBlock) public view returns (bytes32) {
        return
            keccak256(abi.encodePacked(_known(id).prefix, _decimal(fromBlock), ',"toBlock":', _decimal(toBlock), "}}"));
    }

    // ------------------------------------------------------------------ funding

    /// @notice Add to a question's bounty pool. Final: there is no refund path in this version.
    function fund(bytes32 id) external payable {
        _known(id);
        if (msg.value == 0) revert ZeroAmount();
        pool[id] += msg.value;
        emit Funded(id, msg.sender, msg.value);
    }

    // ------------------------------------------------------------------ publishing

    /// @notice Publish an attestation for question `id`. Anyone may call.
    /// @param beneficiary Credited with the bounty if this update is the first paid one in its interval.
    /// @return paid Whether a bounty was credited.
    /// @dev The bounty is paid to whoever lands the transaction, so a public mempool lets a copier take
    /// it. Submit through a private transaction route. Intake removes the problem (docs/DESIGN.md).
    function submit(bytes32 id, Attestation calldata a, bytes calldata sig, address beneficiary)
        external
        returns (bool paid)
    {
        Question storage q = _known(id);
        Observation storage prev = _latest[id];
        _checkPolicy(q, a);
        _checkWindow(id, q, a, prev.toBlock);
        // Signed issue time never goes backwards either, or a consumer's view of age could.
        if (a.issuedAt < prev.issuedAt) revert InvalidTimestamp();
        if (usedRequests[a.requestId]) revert ReplayedAttestation();
        if (_recover(digest(a), sig) != _attester()) revert InvalidSignature();
        usedRequests[a.requestId] = true;

        uint64 sequence = prev.sequence + 1;
        _latest[id] = Observation({
            sequence: sequence,
            fromBlock: a.fromBlock,
            toBlock: a.toBlock,
            issuedAt: a.issuedAt,
            expiresAt: a.expiresAt,
            receivedAt: uint64(block.timestamp),
            panelSize: a.panelSize,
            agreed: a.agreed,
            requestId: a.requestId,
            figure: a.figure,
            answer: a.answer
        });
        emit Published(id, a.requestId, sequence, a.toBlock, a.figure);

        paid = _payBounty(id, q, a.issuedAt, beneficiary);
    }

    /// @notice EIP-712 digest of an attestation under this hub's domain.
    function digest(Attestation calldata a) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _structHash(a)));
    }

    // ------------------------------------------------------------------ reading

    /// @notice The last accepted observation, with no freshness judgement. Prefer `checked`.
    function latest(bytes32 id) external view returns (Observation memory) {
        _known(id);
        return _latest[id];
    }

    /// @notice The latest figure, refused if older than `maxAge` seconds of signed issue time or backed
    /// by fewer than `minAgreed` agreeing members. Arrival time never refreshes age.
    function checked(bytes32 id, uint256 maxAge, uint16 minAgreed)
        external
        view
        returns (uint256 figure, uint64 issuedAt, uint64 sequence)
    {
        _known(id);
        Observation storage o = _latest[id];
        if (o.sequence == 0) revert NoObservation();
        if (block.timestamp > o.issuedAt && block.timestamp - o.issuedAt > maxAge) revert StaleObservation(o.issuedAt);
        if (o.agreed < minAgreed) revert NotEnoughAgreement();
        return (o.figure, o.issuedAt, o.sequence);
    }

    // ------------------------------------------------------------------ withdrawals

    function withdraw() external {
        uint256 amount = credit[msg.sender];
        if (amount == 0) revert ZeroAmount();
        credit[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }

    // ------------------------------------------------------------------ internals

    /// @dev The signer this hub trusts. VIRTUAL only so a test harness can sign with a known key; a
    /// deployed hub has no path to change it. Any subclass under src/ must be read with that in mind.
    function _attester() internal view virtual returns (address) {
        return SERVICE_SIGNER;
    }

    function _validate(Question calldata q) private pure {
        bytes calldata p = q.prefix;
        uint256 m = _WINDOW_MARKER.length;
        if (p.length <= m || p.length > MAX_PREFIX_BYTES) revert InvalidQuestion();
        if (keccak256(p[p.length - m:]) != keccak256(_WINDOW_MARKER)) revert InvalidQuestion();
        if (q.minPanel < PLANE_MIN_PANEL || q.minAgreed == 0 || q.minAgreed > q.minPanel) revert InvalidQuestion();
        if (q.minSpan == 0 || q.maxSpan < q.minSpan) revert InvalidQuestion();
        if (q.bountyWei != 0 && q.paidInterval < MIN_PAID_INTERVAL) revert InvalidQuestion();
    }

    function _known(bytes32 id) private view returns (Question storage q) {
        q = _questions[id];
        if (q.prefix.length == 0) revert UnknownQuestion(id);
    }

    function _checkPolicy(Question storage q, Attestation calldata a) private view {
        if (a.chainId != q.dataChainId) revert WrongDataChain();
        if (a.answerType != q.answerType) revert WrongAnswerType();
        if (a.panelSize < q.minPanel) revert PanelTooSmall();
        if (a.agreed < q.minAgreed || a.agreed > a.panelSize) revert NotEnoughAgreement();
        if (block.timestamp > a.expiresAt) revert ExpiredAttestation();
        if (a.issuedAt > block.timestamp || a.issuedAt > a.expiresAt) revert InvalidTimestamp();
    }

    /// @dev The span is bounded so a "window median" cannot be a single block or a month, and toBlock
    /// must advance so a freshly signed answer cannot cover an old window chosen by its buyer.
    function _checkWindow(bytes32 id, Question storage q, Attestation calldata a, uint64 lastToBlock) private view {
        if (a.toBlock < a.fromBlock) revert InvalidWindow();
        uint64 span = a.toBlock - a.fromBlock;
        if (span < q.minSpan || span > q.maxSpan) revert WindowSpanOutOfRange(span);
        if (a.toBlock <= lastToBlock) revert WindowNotAdvancing(a.toBlock, lastToBlock);
        bytes32 expected = expectedQuestionHash(id, a.fromBlock, a.toBlock);
        if (a.questionHash != expected) revert WrongQuestion(expected, a.questionHash);
    }

    function _payBounty(bytes32 id, Question storage q, uint64 issuedAt, address beneficiary) private returns (bool) {
        uint256 bounty = q.bountyWei;
        if (bounty == 0 || beneficiary == address(0) || pool[id] < bounty) return false;
        uint64 last = lastPaidAt[id];
        if (last != 0 && issuedAt < last + q.paidInterval) return false;
        pool[id] -= bounty;
        lastPaidAt[id] = issuedAt;
        credit[beneficiary] += bounty;
        emit BountyCredited(id, beneficiary, bounty);
        return true;
    }

    /// @dev Two `abi.encode` calls concatenated: every field is one static word, so this is
    /// byte-identical to encoding all sixteen at once and stays clear of stack-too-deep.
    function _structHash(Attestation calldata a) private pure returns (bytes32) {
        return keccak256(
            bytes.concat(
                abi.encode(
                    ATTESTATION_TYPEHASH,
                    a.requestId,
                    a.chainId,
                    a.questionHash,
                    a.answerType,
                    keccak256(a.answer),
                    a.figure,
                    a.fromBlock
                ),
                abi.encode(
                    a.toBlock, a.blockHash, a.panelJobId, a.panelSize, a.quorum, a.agreed, a.issuedAt, a.expiresAt
                )
            )
        );
    }

    function _recover(bytes32 d, bytes calldata sig) private pure returns (address signer) {
        if (sig.length != 65) revert InvalidSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        if (uint256(s) > _HALF_CURVE_ORDER || (v != 27 && v != 28)) revert InvalidSignature();
        signer = ecrecover(d, v, r, s);
        if (signer == address(0)) revert InvalidSignature();
    }

    /// @dev Minimal decimal ASCII, because the window's numbers appear in the hashed JSON as digits.
    function _decimal(uint64 value) private pure returns (bytes memory out) {
        if (value == 0) return "0";
        uint64 digits;
        for (uint64 v = value; v != 0; v /= 10) {
            ++digits;
        }
        out = new bytes(digits);
        for (uint64 v = value; v != 0; v /= 10) {
            out[--digits] = bytes1(uint8(48 + (v % 10)));
        }
    }
}
