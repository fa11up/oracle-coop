<!--
ARCHIVED SWARM SPEC — kept verbatim as the design input this repository started from.
Source: IdentityMD job 07705706-ffee-4e51-a501-c9404680a8d3, skill research-report, accepted 2026-10-05.
Artifact sha256 be9b6285d13b54a31c39b0d1dcee9bc0f350fb76b4870223ad5c077e97cb09ec (verified on retrieval).
Where this repository departs from it, docs/DESIGN.md says so and why.
-->

# Oracle cooperative specification

**Report date: 2026-10-05 (UTC).** Build one immutable, public-read hub that verifies each swarm attestation once and serves the same value to every participating protocol. Fund each question through prepaid, equal-share, 30-day subscriptions; require whoever wants additional updates to pay their entire incremental cost. Permissionless bonded relayers buy the off-chain request and receive a fixed success bounty, avoiding an invented on-chain payment integration. Keep questions immutable and member acceptance policies independent. Treat OEV as supplementary income, never the budget needed to keep prices fresh. **ASSUMPTION A1:** the supplied 0.5 IMD/request, approximately $4.25, and minute-scale response time describe the IdentityMD service; they were not independently verified. At those inputs, five equal sponsors reduce each protocol’s annual request bill from $37,230 to $7,446 before gas, relayer premiums, and failures. This is a design specification and interface, not a deployed or audited implementation.

## Decisions

| Question | Choice | Figure and status | Main reason |
|---|---|---|---|
| 1. Access | Public reads; subscriptions fund availability | Proposed read toll: 0; transaction gas remains | An allowlist excludes direct contract calls, not observation or republication |
| 2. Sharing | Equal prepaid subscription shares per question; extras paid individually | Derived: 8,760 requests/year; five sponsors pay $7,446 each at A1 | Predictable budget without measuring hidden reads or disputable secured value |
| 3. Questions | Immutable content-addressed definitions; explicit member opt-in | Proposed minimum agreement: 8,000 bps and at least 3 agreeing agents | Prevent question substitution while preserving independent risk tolerances |
| 4. Triggers | Hourly base opportunity, optional fully funded extras | Proposed: at most 24 base successes/day/question; 15-minute work lease | A member cannot charge its private urgency to the common account |
| 5. Failure | Keep last valid observation and its original times; fail closed locally | Proposed example member limits: 90 versus 120 minutes | Submission time must not disguise old evidence |
| 6. OEV | Member protocols capture it; voluntarily sponsor the co-op | Proposed contribution: 20% of net captured proceeds; baseline forecast: $0 | Public updates alone cannot enforce an exclusive liquidation right |

## 1. Access: sell availability, not secrecy

Chronicle documents read protection through a whitelist, permissioned mainnet access, and testnet self-whitelisting. That is a useful access-control comparison, not evidence of a particular commercial tariff. [Chronicle integration documentation](https://docs.chroniclelabs.org/Developers/start), read 2026-10-05.

A `msg.sender` allowlist can deny an unlisted protocol’s direct `STATICCALL` to a guarded getter. Every getter and fallback path would need the same protection. Off-chain users can still inspect storage, transaction calldata, logs, and signatures; an RPC simulation can also specify a whitelisted caller. Another contract cannot directly `SLOAD` the hub’s storage, so an unlisted on-chain user needs a republisher, proof mechanism, or cooperating whitelisted wrapper. That friction is real, but a member can publish the value or expose its own public getter. Gating provides a licensing and integration boundary, not confidentiality or a sustainable cryptographic monopoly. This is an engineering inference from public EVM state and caller-based checks.

Recommend public `latest` and `checked` reads. Members buy a scheduled service, audited accounting, and the ability to coordinate funding; nonmembers receive the positive externality. Voluntary sponsorship alone is not incentive-compatible for every possible participant. A minimum-funded campaign makes the failure visible: without enough prepaid shares, that period’s scheduled service does not activate. An anchor sponsor can buy multiple shares when its own avoided solo cost justifies doing so. Do not describe reputation or co-op branding as an enforceable payment mechanism.

Membership is an accounting relationship, not an oracle permission. All consumers bear the same signer and upstream-source risk. The co-op does not insure collateral or promise a redemption value. Its assets are native currency held for bounties and refunds; its liabilities are unspent subscription balances, reserved bounties, relayer bonds, and withdrawal credits. It issues no transferable token and lends none of those assets. Relayers bear failed-request expenses; member protocols and ultimately their contractual loss bearers bear bad debt from mistaken prices.

## 2. Cost-sharing and current comparators

### Economics and choice

**ASSUMPTION A2:** the assignment’s CDP has $1 million of debt outstanding for the entire year, charges 200 bps, and collects all accrued fees. Its $20,000 gross annual fee income is not profit or realized net yield. Combining A1 and A2 gives these reproducible calculations, using 365 days and excluding gas:

| Equal sponsors | Annual request cost per sponsor | Share of the example CDP’s gross fee income |
|---:|---:|---:|
| 1 | $37,230 | 186.15% |
| 2 | $18,615 | 93.075% |
| 5 | $7,446 | 37.23% |
| 10 | $3,723 | 18.615% |

The shared service consumes `24 × 365 × 0.5 = 4,380 IMD/year`. Thirty days costs 360 IMD, approximately $3,060 at A1; five equal shares are 72 IMD or $612. At $8.50/IMD these are arithmetic translations, not a live token quote. Doubling update frequency doubles request expenditure. Doubling IMD’s USD price doubles the dollar request bill. Two members barely cover the oracle from the example fee income and leave almost nothing for other expenses.

| Model | Benefit | Failure mode | Decision |
|---|---|---|---|
| Subscription | Known maximum outlay; funds fixed availability | Departures create renewal gaps | Use per question and period |
| Per-read | Charges apparent usage | View calls cannot mutate a meter; wrappers and caching bypass tolls | Reject |
| Pro rata secured value | Large beneficiaries contribute more | Debt, collateral and recursive TVL give different denominators; self-reporting is gameable | Optional negotiated sponsorship, not an automatic levy |

For production budgeting, quote a native-currency bounty `b` that relayers judge sufficient for A1, gas, financing, and failure risk. The hub neither assumes IMD decimals nor swaps assets using the price it is purchasing. **ASSUMPTION A3:** an independent relayer can purchase an IdentityMD request addressed to the hub and retrieve its attestation. This design deliberately pays for successful delivery, not an unverifiable expense receipt. A fixed native quote creates exchange-rate risk; sponsors may choose a new economic configuration and question ID for subsequent periods. No USD peg is promised.

### Evidence ledger

All pages below were read **2026-10-05**. “Current documentation” means the provider’s current published parameter, not an independently executed RPC measurement. Historical examples fall within 2024-10-05 through 2026-10-05. Undisclosed prices remain unknown; technical metrics are explicitly not tariffs.

| Network | Funding and usage model | Attributable figures and limits | Primary evidence |
|---|---|---|---|
| Chainlink feeds | Shared updates amortize delivery across consumers; operator billing is separate from reading | `latestRoundData` is a view, without a payable per-read fee argument. Billing exposes per-observation and per-transmission LINK settings; no universal sponsorship price was verified | [Data Feeds API](https://docs.chain.link/data-feeds/api-reference), current documentation |
| Chainlink SVR | Protocol and oracle network share liquidation-related proceeds | Historical six-month Aave agreement: 65% Aave / 35% Chainlink, proposed 2025-03-12; not asserted to be today’s universal split | [Aave agreement](https://governance.aave.com/t/arfc-addendum-aave-dao-chainlink-smart-value-recapture-svr/21358) |
| Pyth Core | Pull updates; distinguish contract update fee, transaction gas, and data access | Current documented update fee: **0** across mainnet EVM chains; `getUpdateFee` remains authoritative. Page attributes zeroing to OP-PIP-128 and the Core sunset | [Current fees](https://docs.pyth.network/price-feeds/core/current-fees) |
| API3 dAPIs | Prepaid plans estimate operating gas; others can use an active feed | Estimated operating cost or **$0.05/day**, whichever is higher; mainnet plans **3 months**, heartbeat **24 hours**, deviations **0.25%–5%** | [Market integration](https://docs.api3.org/dapps/integration/index.html); [activation and shared use](https://docs.api3.org/dapps/quickstart/) |
| API3 OEV | Partner dApps receive proceeds; provider retains a share | **80%** to dApps, remaining **20%** protocol fee, monthly reporting/payment | [OEV payment procedure](https://docs.api3.org/dapps/oev-rewards/) |
| Chronicle | Read allowlisting; mainnet access arranged with the provider | **No public dollar tariff verified**; whitelist is binary access, not a per-read billing formula | [Mainnet/testnet integration](https://docs.chroniclelabs.org/Developers/start) |
| RedStone | Pull consumers attach signed data and pay verification gas; gateway access is separately controlled | Current gateway limit **1 request/second/API key**; **no public subscription tariff verified**. Atom documentation requires **$5M market TVL** and describes auctions under **300 ms**; these are eligibility/latency figures, not prices | [Pull integration](https://docs.redstone.finance/docs/stage1-market-data/price-feeds/pull-model/); [Atom mechanics](https://docs.redstone.finance/docs/stage2-capital-efficiency/atom/what-is-atom/) |

Chainlink’s documented shared-resource model supports amortization, but does not publish a universal sponsor invoice. Treat “sponsorship” here as funding an update stream, not buying every read. A negotiated feed-support quote is still needed; node compensation settings do not equal a protocol’s commercial bill. [Shared data resource architecture](https://docs.chain.link/architecture-overview/architecture-decentralized-model). The Aave example is evidence of a concrete alternative financing arrangement, not an ordinary feed subscription quote. Chainlink’s current SVR documentation describes shared feeds and a revenue split without specifying a universal percentage. [SVR documentation](https://docs.chain.link/data-feeds/svr-feeds).

Pyth’s zero verification fee does not establish zero all-in cost or continuing delivery service. Its fee page explicitly references sunset; availability and replacement-product terms require separate diligence. Likewise, API3’s floor is not the price of an Ethereum feed under congestion. The defensible inference across these models is to share publication costs and separate delivery, retrieval, and OEV economics. The unresolved Chronicle and RedStone dollar tariffs are evidence gaps, not zeroes.

## 3. Questions, immutable identity, and independent acceptance

### Scope and evidence

**ASSUMPTION A4:** IdentityMD supports precisely the following re-runnable recipes, with signer re-execution; any other question uses voted panel evidence. **ASSUMPTION A5:** a panel previously returned a price wrong by 256×. Neither service behavior nor that incident was independently reproduced.

| Recipe under A4 | Output | Co-op treatment |
|---|---|---|
| `log-sum`, `log-count` | `uint256` | Carry exact event/filter/window definitions; counts are not prices |
| `univ4-spot {poolManager,poolId,invert?,samples}` | `uint256`; odd samples 1–61 | Primary candidate for a specific pool’s quote; pin orientation and units |
| `call-compare` | Boolean | Carry as a separate assertion feed; pin view calldata, threshold and comparator |
| `log-rank`, `v4-volume-rank` | `address[]` or `bytes32[]` | Separate typed feeds; bounded list length, deterministic tie rules |
| Other questions | Panel evidence | Advisory namespace; no default permission for collateral decisions |

An IMD/ETH market price and one pool’s IMD/ETH spot are different products. Start with the exact pool observation if its liquidity and manipulation analysis justify use; do not label it a market-wide price. Sampling 61 points is not proof of a TWAP, independence, or manipulation resistance. Pin the recipe’s actual aggregation and sample-block selection. A boolean comparison cannot be repurposed into a numeric price. Panel agreement is not cryptographic proof that a price is correct.

**ASSUMPTION A6:** the service signs the stated fields under EIP-712 domain name `IdentityMD Oracle`, version `2`, requester-selected chain ID and consumer, using service key `0x5598aa9146215bc13eb26f2c692ad1461fd32982`. The hub’s sole authority constant is that key. **ASSUMPTION A7:** `questionHash` is the canonical complete-document hash including block bounds; `agreed` is a count comparable with `panelSize`. Exact schema types, encodings, and agreement semantics need developer vectors. EIP-712 defines domain separation and field hashing, but does not itself provide application replay protection. [EIP-712 specification](https://eips.ethereum.org/EIPS/eip-712), read 2026-10-05.

### Append-only registration

Anyone may register a question at their own gas cost. Registration confers no spending access to another question, endorsement, or ability to migrate consumers. There is no mutable name-to-ID alias. Consumers select a complete ID, inspect its document, and explicitly choose whether to fund it. Duplicate identical registrations revert; unrelated registration never iterates existing questions.

Store immutable byte fragments `prefix`, `between`, and `suffix`. The renderer produces `prefix || decimal(fromBlock) || between || decimal(toBlock) || suffix`, with minimal unsigned ASCII decimals. The fragments contain every other field: schema version, chain, recipe, evidence class, pool/filter/call details, units, orientation and aggregation. They must constitute one canonical document with exactly two numeric holes. Reject duplicate keys, extra window fields, malformed encodings, unsupported recipe/type combinations, and excessive size. This renderer is a proposed compatibility contract, **ASSUMPTION A8:** the actual canonicalizer permits these exact splice positions. Service-issued golden vectors are a production prerequisite; an invented JSON example is not a verified schema.

`questionId = keccak256(abi.encode(block.chainid, address(this), config))`, including length-delimited fragments, fixed security limits, and subscription economics. Retain the full fragments on chain. No setter exists. A change creates another ID, with separate funding and explicit consumer adoption. At every submission recompute `questionHash` from the stored fragments and the signed bounds; matching the signer and hub alone is insufficient.

### Consumer independence

The hub stores typed answer bytes, numeric figure, question hash, request and job identifiers, block bounds/hash, agreement counts, issued/expiry times, observation time, acceptance time, and sequence number. Evidence class derives from the pinned document, never from an unsigned submitter flag. **ASSUMPTION A9:** signing a chain-recipe document implies the service actually re-executed it; the supplied field list has no separate signed evidence-mode field. A signature verifies attribution, not computation or panel independence.

Base validation requires `0 < quorum <= agreed <= panelSize`, at least three agreeing agents, and `agreed × 10,000 >= panelSize × 8,000`. Cap all panel counts at 65,535 and use overflow-safe arithmetic. Member A may require 90-minute observation age, 90% agreement and a 5% deviation limit; B may require 120 minutes, 80% and 15%. These are illustrative design settings, not risk-approved CDP parameters. Each member checks against its own last accepted value, not merely the immediately previous hub update, preventing gradual stepping around its cap. A cap violation rejects the value; it never silently clamps it. Bootstrap and recovery after a long halt require the member’s explicit risk procedure.

## 4. Triggers and protection against budget abuse

Use a deterministic hourly base slot and permissionless relayers. A clock makes work eligible; it cannot send a transaction or invoke an off-chain API. Monitoring processes watch eligible funded slots, acquire a lease, buy the request, retrieve the answer, and submit it. Any member may run one. No keeper address is privileged.

Each immutable question configuration defines a bounty `b`, target share count `n` (1–64), and price `s = ceil(720b/n)` in native wei for a 30-day epoch. Enrollment closes when the epoch starts; only exactly `n` purchased shares activates its 720-slot budget. A sponsor may buy multiple shares. Late members enroll for the next epoch. Underfunded epochs refund all contributions and buy nothing. This cliff trades flexibility for an auditable maximum liability. Rounding surplus is part of the refundable residual.

Anyone can lease the current base slot with bond `b`; missed slots cannot be bought retroactively. Only one live base lease exists per question. Its closing block is fixed at `block.number - 64` on acquisition, and the opening block follows the pinned window length, 1–128 blocks. Require both arithmetic bounds and a closing block later than the latest accepted one. These are proposed Ethereum-style confirmation settings, not a finality guarantee; deploying on a different chain needs a reviewed header/confirmation policy.

The opener provides the closing header, whose hash must equal nonzero `blockhash(toBlock)`. Decode and save its timestamp and hash at lease creation, before the blockhash ages out. The answer later must match this saved anchor. Solidity documents the 256-block availability limit; saving an authenticated anchor avoids depending on it remaining available during the service delay. [Solidity block variables](https://docs.soliditylang.org/en/latest/units-and-global-variables.html), read 2026-10-05. Strict header decoding is chain-specific; arbitrary caller-supplied timestamps are never accepted.

A lease expires after 15 minutes or at the slot boundary, whichever comes first; refuse acquisition with less than 15 minutes left. One replacement lease may be acquired for that slot after expiry. The first valid answer earns at most one bounty. Anyone may relay it, but credit goes to the recorded worker, making transaction copying unprofitable. Expiry slashes the worker’s bond into that epoch’s residual; no failed-request reimbursement comes from subscribers. Refusal and latency are worker risks priced into `b`. A compromised signer remains able to forge qualifying successes; bonding does not solve that.

Price-movement watchers may request extras, but an untrusted “price moved” assertion never unlocks the base budget. Extras escrow their own bounty, use distinct request tickets and bonds, and cannot occupy the base lease. Limit each payer to one outstanding extra per question; Sybils cannot consume common funds. If an extra publishes a newer closing block, cancel any superseded base lease, return its bond, and release its reservation without paying its bounty. This prevents a stale answer blocking progress, although the worker may lose an already-paid service fee. Arbitrage or political pressure cannot increase the 720-bounty base ceiling.

## 5. Refusal, delay, exit, and stale values

| Situation | Hub behavior | Member responsibility |
|---|---|---|
| Refusal or no quorum | No valid publication, no bounty; lease times out | Keep monitoring and enforce local age limit |
| Late answer | No payment after ticket expiry; may be published unpaid if still valid and newer | Judge observation age and expiry, not arrival time |
| Member leaves | Current share stays committed; next period is not renewed | Forecast the next period’s funding gap |
| Underfunded next epoch | Automatic inactivity; contributor refunds available | Select a reviewed fallback or suspend risky actions |
| Expired/stale observation | Raw getter still reports it and original metadata | Reject debt increases, collateral withdrawals and unsafe liquidations |
| Source manipulation or real crash | Signature may remain valid; local deviation checks can halt | Diagnose; never assume every large move is an oracle error |
| Chain reorganization | Saved anchor is only as strong as confirmation policy | Account for reorg/sequencer risk independently |

`latest` is an observation API, not a safety certificate. `checked` rejects absent observations, future issue times, `now >= expiresAt`, excess observation age, insufficient agreement, wrong evidence/type, and configured numeric limits. Record `receivedAt` separately. The authentic closing-header timestamp is `observedAt`; `issuedAt` must be at least that timestamp and no later than the current time. A bounded source window is also required, because a fresh window end does not make all samples fresh. Each member can impose a stricter window bound.

**ASSUMPTION A10:** service `issuedAt` and `expiresAt` are Unix seconds and `blockHash` identifies `toBlock`. The hub requires `expiresAt > issuedAt` and a maximum validity interval of two hours. Expiration cannot be extended by replaying an answer. An unpaid publication verifies a recent header directly; a leased answer uses its saved anchor. Both paths enforce strictly increasing `toBlock` and unique `requestId` and `panelJobId` within this hub.

Safe actions, such as repayment and adding collateral, should remain available in member protocols during an oracle halt. Fallback prices require separate provenance and freshness checks. Do not silently reuse a panel value as a chain-evidence fallback. A conservative halt may still produce bad debt; minute-scale asynchronous delivery is unsuitable for protocols requiring block-scale liquidation response.

After epoch end, expire outstanding tickets and compute each share’s refund from the unspent residual: contributions plus slashed base bonds minus paid bounties. Each sponsor withdraws `floor(residual × ownedShares / n)` once; rounding dust stays isolated in that epoch. Underfunded epochs refund exact contributions. No contribution withdrawal can impair an existing lease. Current-period commitments survive exit; no departing member acquires claims on other questions or historical OEV.

## 6. OEV: capture belongs with the exposed protocols

A liquidation bonus compensates real liquidation costs; surplus after those costs can be competed away through searcher bids. The exposed member protocol should control how that surplus supports its users, reserves, or oracle budget. Recommend a voluntary 20% contribution of net captured proceeds to its question’s next funding period, with 80% retained by the member. This is a proposed cooperative agreement, not a verified IdentityMD fee split or an enforceable hub tax.

API3’s documented 80% dApp reward illustrates revenue financing, but its OEV system distinguishes dApp-specific feeds from a shared base feed. That separation is important: rights attached to one consumer do not automatically sell control over every other consumer’s liquidation. [API3 OEV feed architecture](https://docs.api3.org/oev/in-depth/data-feeds/), read 2026-10-05. RedStone Atom documents atomic update-and-liquidation settlement with fallback publication if no valid bid arrives; its eligibility figure in the comparator table also shows why a small CDP cannot assume access to every commercial OEV product.

The proposed hub has unrestricted valid publication. Once a signature is available, anyone can publish it and anyone can read it. Therefore the hub cannot credibly auction exclusive update rights, stop copying a leaked bundle, or guarantee recapture across unmodified member protocols. Version one accepts OEV-funded subscriptions from members whose existing liquidation systems or private bundles already earn revenue. It does not add an auction contract or delay a price to create scarcity. No OEV forecast reduces minimum subscription funding.

An eventual stronger auction requires member-level liquidation rights and atomic bid payment, price acceptance, and execution, plus a short fallback deadline. That is a separately reviewed member integration, not a hidden fifth deployment in this launch. **ASSUMPTION A11:** no IdentityMD private-delivery or exclusive-attestation facility has been verified. Relayers may still earn incidental OEV; the base bounty buys timely publication, not ownership of every downstream economic opportunity.

## Contracts

### Deployment and authority

Deploy exactly **one contract, `OracleCoopHub`**. No proxy, factory, external verifier, token, adapter, or auction contract is required. Existing member protocols call it directly. Hashing, signature recovery, rendering, header parsing and checked-read logic are internal code, not linked deployed libraries. Constructor-supplied bootstrap configurations can register initial questions and fund initial shares in that same deployment. All structural links and the EIP-712 consumer identity are complete on constructor return. There are no initializer, ownership-transfer, authorization, or approval calls afterward. Ordinary future subscriptions, request tickets and publications are runtime use, not launch setup.

The sole privileged address is the A6 service signer, fixed in implementation source as `address constant SERVICE_SIGNER = address(bytes20(hex"5598aa9146215bc13eb26f2c692ad1461fd32982"));`. There is no administrator, upgrade authority, fee recipient, privileged keeper, or signer-rotation function. Subscription owners and bonded workers have only rights over their own funds/tickets, not system roles. No privileged address is accepted in a constructor or substituted with a dummy value. Signer retirement requires deploying a new hub and explicit consumer migration; until then this one may stop receiving updates.

Constructor specification: `constructor(Bootstrap[] memory initial) payable`. Each entry contains `QuestionConfig config`, `uint64 epoch`, and `uint16 shares`; every purchased share belongs to the constructor caller, without administrative powers. Require exact aggregate payment; permit zero shares and empty bootstrap. Establish an epoch origin at deployment and use the same internal validation as registration/enrollment. Bootstrap may fund epoch zero during construction; later enrollment is only for future epochs. Emit registration/subscription events. Absence of a verified production document permits a safely empty deployment, not a fabricated usable feed.

### Solidity interface boundary

This interface specifies the co-op ABI, not the unavailable service wire ABI. `wireAttestation` must be decoded by a fixed internal decoder matching developer-supplied EIP-712 vectors. It is not an arbitrary verifier callback. The decoder must cover **requestId, chainId, questionHash, answerType, answer, figure, fromBlock, toBlock, blockHash, panelJobId, panelSize, quorum, agreed, issuedAt, expiresAt**. Exact field widths, dynamic-field types and primary struct name are unresolved A6/A7 dependencies; deployment for real funds is blocked until confirmed.

```solidity
pragma solidity ^0.8.24;

interface IOracleCoopHub {
    struct QuestionConfig {
        bytes prefix;
        bytes between;
        bytes suffix;
        uint8 recipe;
        uint8 answerKind;
        uint8 evidenceClass;
        uint8 decimals;
        uint16 windowBlocks;
        uint256 bountyWei;
        uint16 targetShares;
    }
    struct Bootstrap {
        QuestionConfig config;
        uint64 epoch;
        uint16 shares;
    }
    struct Observation {
        uint64 sequence;
        bytes32 requestId;
        bytes32 panelJobId;
        bytes32 questionHash;
        bytes32 blockHash;
        bytes answer;
        uint256 figure;
        uint256 fromBlock;
        uint256 toBlock;
        uint256 panelSize;
        uint256 quorum;
        uint256 agreed;
        uint256 observedAt;
        uint256 issuedAt;
        uint256 expiresAt;
        uint256 receivedAt;
    }
    struct Policy {
        uint256 maxAge;
        uint16 minAgreementBps;
        uint16 minAgreed;
        uint16 maxWindowBlocks;
        uint16 maxDeviationBps;
        uint256 previousAcceptedFigure;
        uint256 minFigure;
        uint256 maxFigure;
        uint8 requiredEvidenceClass;
        uint8 requiredAnswerKind;
    }
    struct EpochAccount {
        uint256 paid;
        uint256 spent;
        uint256 reserved;
        uint256 residual;
        uint16 subscribedShares;
        bool active;
        bool settled;
    }
    function registerQuestion(QuestionConfig calldata config)
        external returns (bytes32 questionId);
    function question(bytes32 id) external view
        returns (QuestionConfig memory);
    function documentHash(bytes32 id, uint256 from, uint256 to)
        external view returns (bytes32);
    function subscribe(bytes32 id, uint64 epoch, uint16 shares)
        external payable;
    function epochAccount(bytes32 id, uint64 epoch)
        external view returns (EpochAccount memory);
    function ownedShares(bytes32 id, uint64 epoch, address account)
        external view returns (uint16);
    function openBase(bytes32 id, bytes calldata closingHeader)
        external payable returns (bytes32 ticket);
    function openExtra(bytes32 id, uint256 bountyWei,
        bytes calldata closingHeader) external payable returns (bytes32 ticket);
    function submit(bytes32 ticket, bytes calldata wireAttestation,
        bytes calldata signature) external;
    function publish(bytes32 id, bytes calldata wireAttestation,
        bytes calldata signature, bytes calldata closingHeader) external;
    function expire(bytes32 ticket) external;
    function cancelSuperseded(bytes32 ticket) external;
    function settleEpoch(bytes32 id, uint64 epoch) external;
    function claimRefund(bytes32 id, uint64 epoch) external;
    function credit(address account) external view returns (uint256);
    function withdraw(uint256 amount, address payable recipient) external;
    function latest(bytes32 id) external view returns (Observation memory);
    function checked(bytes32 id, Policy calldata policy)
        external view returns (Observation memory);

    event QuestionRegistered(bytes32 indexed id, bytes32 configHash);
    event Subscribed(bytes32 indexed id, uint64 indexed epoch,
        address indexed sponsor, uint16 shares, uint256 paid);
    event TicketOpened(bytes32 indexed ticket, bytes32 indexed id,
        address indexed worker, uint256 fromBlock, uint256 toBlock,
        uint256 deadline, uint256 bountyWei, bool extra);
    event Published(bytes32 indexed id, bytes32 indexed requestId,
        bytes32 indexed ticket, uint64 sequence, uint256 toBlock);
    event TicketClosed(bytes32 indexed ticket, uint8 reason,
        uint256 bountyCredit, uint256 bondCredit);
    event EpochSettled(bytes32 indexed id, uint64 indexed epoch,
        uint256 residual);
    event RefundCredited(bytes32 indexed id, uint64 indexed epoch,
        address indexed sponsor, uint256 amount);
    event Withdrawn(address indexed account, address indexed recipient,
        uint256 amount);
}
```

IDs in `Observation` are normalized 32-byte identifiers; if service IDs are dynamic, hash their canonical bytes consistently and retain raw bytes in transaction data. This normalization must never replace the service’s original EIP-712 field hashing.

### Storage, functions and access rules

Store configs by ID; observations and last block by ID; global used request/job hashes; epoch accounts and purchased-share/refund flags; base-slot attempts and paid flags; ticket anchors, deadlines, worker, sponsor, bounty, bond and terminal state; outstanding-extra index; aggregate liabilities and withdrawal credits. All counters have checked bounds. No unbounded loop over questions, members or expired tickets is allowed.

| Functions | Caller and validation | State/event effect |
|---|---|---|
| `registerQuestion`, `question`, `documentHash` | Public; registration validates canonical grammar, caps fragments at 8 KiB total and answers at 4 KiB | Append-only registration event; views change nothing |
| `subscribe`, account/share getters | Anyone buys own shares, exact payment, before period start, never above target | Ring-fenced contribution and `Subscribed` |
| `openBase` | Anyone; active epoch, current eligible slot, exact bond `b`, valid header and no live base lease | Reserve `b`, store authenticated anchor, `TicketOpened` |
| `openExtra` | Anyone; positive bounty at least base `b`, exact `2 × bounty` payment | Caller is payer and worker; half bounty, half bond; independent ticket |
| `submit` | Anyone carrying valid matching attestation before deadline | Mark identifiers used, publish, credit recorded worker bounty and bond, close ticket |
| `publish` | Anyone; full validation including recent header; no bounty | New observation; never pays unsolicited requests |
| `expire`, `cancelSuperseded` | Anyone; objective deadline or advanced block predicate | Release reservation; terminal state once; expiry bond to epoch residual, or extra payer’s credit; supersession returns bond |
| `settleEpoch`, `claimRefund` | Anyone settles after end; claimant only claims its own shares | Require zero reservations; compute residual once, then individual pull credit |
| `withdraw` | Only caller’s existing credit, nonzero valid recipient | CEI, reentrancy guard, checked transfer, `Withdrawn` |
| `latest`, `checked` | Public; unknown ID rejects | No global freshness flag or hidden policy mutation |

Extra expiry returns its unpaid bounty to its payer; since payer is also worker, its bond returns as well. Its penalty is the request cost and time, not a transfer to unrelated subscribers. Base expiry slashing is funded only by the worker. Superseded extra tickets also refund both components. `publish` can supersede a leased answer without taking its bounty; cancellation is permissionless and bounded per ticket. Supersession means `latest.toBlock >= ticket.toBlock`, including equal-block unpaid publication; its slot closes without another base lease.

Additional invariants: contract balance covers all liabilities; forced native transfers do not create shares or spending capacity; question accounts never cross-subsidize; every bounty consumes one reservation exactly once; a replay cannot pay, refresh or regress a value. Domain chain equals `block.chainid` in both domain and signed struct, and verifying contract equals this hub. Reject malformed/high-s signatures and zero recovery. Typed answer and figure must agree under the pinned encoding, with zero prices rejected but legitimate zero counts allowed. Arrays are limited to 64 entries; configured decimals are limited to 0–36. `checked` uses overflow-safe ratio math and rejects a zero numeric baseline; nonnumeric policies must disable numeric deviation checks. The member supplies its own trusted baseline, so this stateless helper cannot enforce correct integration by itself.

## Foundry test plan

These are named acceptance tests for the future implementation; they have **not** been executed against deployed contracts. Use deterministic service fixtures, local mocked headers and time/block manipulation, malicious recipients, and independent canonicalization reference vectors. Never obtain the real service private key. Test-only signing keys belong in harnesses; also require at least one real service-issued positive vector against the production constant.

| Test name | Required assertion or adversarial case |
|---|---|
| `test_ConstructorOnlyLaunch` | One creation, no follow-up calls; bootstrap configs/funding readable; no owner, initializer or external links |
| `test_ConstructorRejectsWrongPayment` | Underpayment, overpayment, oversized shares/configs and duplicates revert atomically |
| `test_PublicReadsAndRepublication` | Unfunded contract can read and republish; no confidentiality claim |
| `test_QuestionCannotBeRewritten` | Same ID immutable; changed units, pool, orientation or prefix creates distinct ID and ledger |
| `test_GoldenCanonicalQuestions` | Service and independent renderer match byte-for-byte over digit boundaries and both block bounds |
| `test_RejectQuestionInjection` | Duplicate keys, extra fields/windows, noncanonical numbers and alternate encodings reject |
| `test_RejectDifferentQuestionForSameConsumer` | Genuine signer and correct hub do not rescue a wrong document hash |
| `test_EIP712DomainAndEveryField` | Wrong chain, consumer, name, version, type hash or mutation of each signed field fails |
| `test_RejectMalformedAndMalleableSignature` | High-s, short/long signature, bad v and zero recovery reject |
| `test_ProductionSignerFixture` | Real positive attestation validates; test-key fixture fails production code |
| `test_AgreementFloorBoundaries` | Below 80%, fewer than three agreeing, zero panel and impossible quorum/counts reject |
| `test_NoEvidenceUpgrade` | Panel question cannot pass a chain-only policy, even at unanimous agreement |
| `test_RecipeAndAnswerTypes` | All six recipes match allowed kinds; bool-as-price, wrong scale, oversized ranking and figure mismatch reject |
| `test_HeaderAnchorAndReorg` | Wrong header/hash/number/time fails; stored anchor survives 256-block aging; document reorg limitation |
| `test_RejectReplayAndBlockRegression` | Duplicate request/job, equal closing block, older block and bad opening bounds reject |
| `test_IssueExpiryAndObservationAge` | Future issue, issue before observation, expired signature and excess lifetime reject; arrival does not refresh age |
| `test_IndependentMemberPolicies` | Same update passes B and fails A; alternating small moves cannot bypass A’s cumulative baseline cap |
| `test_SubscriptionActivationAndRounding` | Exactly n prepaid shares activate; n−1 refunds; rounding never exceeds assets |
| `test_ExitCannotUnfundLease` | Committed share survives exit; next epoch requires renewed payment |
| `test_BaseSlotAndRetryLimits` | Only current slot, one live lease, at most two attempts and one payment; no catch-up spending |
| `test_ExtraCannotDrainCommonPool` | Many Sybil extras and fabricated movement claims leave base budget intact |
| `test_CopiedSubmissionCreditsWorker` | Front-running caller cannot redirect bounty or bond |
| `test_TimeoutLateAndRefused` | Timeout releases reservation once; late submit unpaid; publication still needs full validation |
| `test_SupersededLeaseRefund` | Newer extra/publication permits cancellation without base payment or wrongful slashing |
| `test_RefundAndSettlementOnce` | Live reservations prevent settlement; individual claim cannot be replayed or claim another sponsor’s share |
| `test_ReentrantAndRevertingRecipient` | No double withdrawal; failed transfer retains credit; other users remain live |
| `test_ForcedNativeTransferAndOverflow` | Forced balance changes cannot alter shares; extreme counts, prices and products fail safely |
| `test_ZeroOEVLiveness` | Funded base slots work with no OEV; unbundled valid publication remains available |
| `invariant_AccountingAndIsolation` | Random enroll/open/submit/expire/refund/withdraw order preserves liabilities and question isolation |
| `invariant_ObservationAuthenticity` | Every stored sequence traces to a valid document/domain; accepted closing blocks strictly increase |

Fuzz byte boundaries, timestamps, epochs, counts, rounding and terminal-state permutations. Use a ghost ledger independent of implementation accounting. Compile the eventual implementation with a pinned compiler and vendored libraries, then run unit, fuzz and invariant suites offline. Slither/Mythril and independent review remain implementation-stage checks. Local checks passed: section order, arithmetic, 14 distinct cited source pages, 30 unique test names, and interface compilation using Solidity 0.8.24. Source claims were reviewed against the retrieved pages. These checks cannot establish oracle correctness or economic sustainability.

## Risks ranked by severity

| Severity | Risk and loss path | Mitigation and remaining exposure |
|---|---|---|
| Critical | Signer compromise, false re-execution, or coordinated wrong answer leads to correlated liquidations/bad debt | Pinned recipes, agreement floors, independent member checks and debt caps; still one signing authority |
| Critical | Thin pool manipulation or 256× scaling/orientation error survives an authentic signature | Pin units and pool, golden vectors, independent plausibility checks and liquidity study; multi-sampling alone is insufficient |
| High | Undocumented canonicalization/type/evidence semantics make verification incompatible or unsafe | Real fixtures and developer confirmation are release prerequisites; this report does not resolve them |
| High | Minute latency, stale windows, reorgs or a halt prevent timely liquidation | Header anchors and member-specific checks; price-sensitive actions can halt, but insolvency remains possible |
| High | Funding collapse, currency moves or failed-request losses deter relayers | Prepayment, visible activation cliff, multiple workers, next-period quotes; no guaranteed taker |
| High | Accounting/reentrancy or malformed-header bugs lose prepaid assets | One bounded ledger, pull withdrawals, strict decoding and adversarial tests; implementation still unaudited |
| Medium | Free riding leaves an anchor sponsor funding everyone | Contractual commitments and explicit renewal thresholds; public state makes exclusion incomplete |
| Medium | Malicious leasing, duplicate off-chain purchases, supersession and censorship waste time | Bonds, retry limits, separate extras and permissionless publication; liveness attacks still cost subscribers time |
| Medium | Deviation caps freeze a real crash and delay recovery | Member-specific recovery and conservative actions; no automatic clamping or panel substitution |
| Medium | OEV extraction causes withholding or unfair subsidy between protocols | No launch auction gate; count zero expected OEV; only voluntary realized contributions |
| Low | Configuration proliferation, stranded dust and source-document drift | Content-addressed IDs, bounded calls, disclosed dust and dated evidence; discovery remains off chain |

## Open questions for the IdentityMD developer

1. Can you provide the exact EIP-712 primary type, field types, domain fields, answer encodings, and a real signed positive/negative fixture for service key `0x5598aa9146215bc13eb26f2c692ad1461fd32982`?
2. Can you provide canonical question documents and hash vectors for every supported recipe, including exact block-window splice positions and duplicate-key handling?
3. Does `agreed` mean an integer count, what does `quorum` mean, and what prevents one agent or correlated backend from occupying multiple panel seats?
4. Does signing a chain-recipe question guarantee re-execution without panel fallback, and how can a consumer detect a violated guarantee?
5. What are `univ4-spot`’s exact sampling blocks, aggregation, decimal scaling and inversion rules, and how are empty liquidity, pool hooks and manipulated samples handled?
6. Which chain, PoolManager and IMD/ETH pool should the first feed describe, and what confirmation depth and header format does that chain require?
7. Are `blockHash`, `issuedAt` and `expiresAt` respectively the closing-block hash and Unix-second timestamps, and can a signed answer legitimately outlive two hours?
8. Can any relayer buy a request naming this hub, retrieve its attestation, and deduplicate retries; what are the actual refusal, latency, refund and request-ID guarantees?
9. Is 0.5 IMD still the complete request charge, which token/decimals or account credits pay it, and is there a supported receipt or prepaid billing interface?
10. Can you supply the 256× incident’s question, answer, recipe/evidence mode and postmortem so the corresponding failure can be reproduced?
11. What happens when the service signing key rotates or is compromised, and what migration notice can immutable consumers expect?
12. Is there a supported private delivery or OEV integration, and would it preserve unrestricted timely fallback publication without an extra deployment or privileged updater?
13. Which protocols will prepay the first period, what latency and deviation limits can each tolerate, and who will buy missing shares if one leaves?
