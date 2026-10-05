# Design

This repository started from a design spec written by the IdentityMD swarm
([`SWARM-SPEC-2026-10-05.md`](SWARM-SPEC-2026-10-05.md)). We reviewed it against what we have
measured on the live service, kept most of it, and changed five things. This file records each
decision and its reason, so the next version can revisit a decision without re-deriving it.

## The problem

A protocol that buys its own swarm price updates pays about 4.25 USD per update (0.5 IMD). Hourly,
that is **37,230 USD a year**, more than a 200 bps stability fee earns on 1M USD of debt. Several
protocols want the same figure, such as IMD/ETH from the same pool. If one contract verifies each
answer and every protocol reads it, five sponsors pay about 7,446 USD each. The figures come from
the spec, at 8.50 USD per IMD.

An attestation is signed for exactly one `verifyingContract`, so a shared value needs one shared
consumer. That consumer is the hub.

## Decisions

| # | Decision | Source | Reason |
|---|---|---|---|
| 1 | **Public reads.** Anyone may call `latest` and `checked` | spec | An allowlist blocks direct calls but not observation or republication. Members pay for the value being kept fresh, not for exclusive access to it. |
| 2 | **One contract, no admin.** The service signer is the only authority, a source constant | spec | Nothing to configure after deployment, nothing to capture. Rotating the key means deploying a new hub and migrating consumers. |
| 3 | **Questions are content-addressed and immutable.** `id = keccak256(abi.encode(question))` | spec | A question can never be rewritten under its consumers. Any change is a new id that consumers must adopt explicitly. |
| 4 | **Question binding by prefix splice.** Store the canonical document up to `,"window":{"fromBlock":` and splice in the signed window | spec + ours | The same mechanism our SwarmFeed already runs against live attestations. The service canonicalises with sorted keys, so `window` sorts last and the varying part is a pure suffix. `register` refuses a prefix that does not end at that marker. |
| 5 | **Floors are counts, not ratios** (`minPanel`, `minAgreed`) | **changed** | The spec required 80% agreement. On live attestations `agreed == quorum` (request e2c85027: 60 / 20 / 20), because the service signs once quorum is reached. A ratio floor only forces a higher request quorum, which gets requests refused. |
| 6 | **Each consumer applies its own policy against its own last accepted value** (`CoopConsumer`) | spec | Two members can read one hub and disagree. Comparing against the hub's previous value would let a run of in-cap steps walk a member past its cap between reads. |
| 7 | **No block-header anchor** | **changed** | The spec anchored the window to a consumer-supplied block header. That only works when the data and the hub share a chain, and ours do not: the questions read mainnet and are consumed elsewhere. Window advance plus span bounds plus signed issue time cover the same ground. |
| 8 | **Funding scales with the money; it is not all-or-nothing** | **changed** | The spec activated an epoch only when exactly n shares were sold and refunded everything otherwise. Here a pool simply pays a fixed bounty at most once per `paidInterval`. A half-funded question gets updates for half as long instead of none at all. |
| 9 | **No leases or bonds; a bounty for the first valid update per interval** | **changed** | The spec's lease and bond machinery existed because the request is bought off chain by an untrusted relayer. Most of it disappears once the hub buys its own requests through Intake (roadmap), so v0 ships the smallest version that works today. |
| 10 | **No clock trigger in the hub** | **changed** | When to buy an update belongs to whoever pays for it. The intended trigger is the self-funding v4 hook (a separate design), which buys an update when spot leaves a band. |
| 11 | **Freshness is signed issue time, never arrival time**, and issue time may not go backwards | spec | Relaying an old answer late must not make it look new. |
| 12 | **OEV is out of scope** | spec | Publication is permissionless, so the hub cannot sell exclusive update rights. Members that capture OEV elsewhere may fund their question's pool voluntarily. |

## What the hub checks on every `submit`

1. The question is registered.
2. The data chain and the answer type match the question.
3. `panelSize >= minPanel` and `minAgreed <= agreed <= panelSize`.
4. The attestation has not expired, was not issued in the future, and was not issued before the
   current observation.
5. The window span is within `[minSpan, maxSpan]` and `toBlock` moves forward.
6. `questionHash` equals keccak of the stored prefix with this window spliced in.
7. The request id has never been accepted, on any question.
8. The EIP-712 signature (domain "IdentityMD Oracle", version 2, this chain, this hub) recovers to
   the service signer. Signatures must be 65 bytes with low-s.

`test/LiveAttestation.t.sol` replays a real attestation signed by the production key, so checks 6
and 8 are proven against the live service and not only against a test key.

## Known limitations in v0

- **Bounty front-running.** The bounty goes to the `beneficiary` named in the transaction that
  lands, so a copier in a public mempool can take it. Submit through a private transaction route.
  The real fix is v1, where the hub buys its own requests and there is no relayer to pay.
- **Sponsorship is final.** `fund` has no refund path. Epoch accounting with refunds is a v1 item.
  Until then, fund in small amounts.
- **A single signing authority.** A compromised service key can sign any figure for a registered
  question. Consumers' deviation caps and agreement floors limit the damage per update; they do not
  remove it.
- **Answer types beyond `uint256`.** The answer-type enum is known for bool=0, address=1,
  bytes32=2 and uint256=3, recovered from live signatures. Array answers (`log-rank`,
  `v4-volume-rank`) are stored as raw `answer` bytes, but their enum values are unconfirmed.
- **Unaudited.** Testnet only.

## Roadmap

1. **Sepolia deployment** and one registered IMD/ETH question, its prefix generated with
   `oracle/question-prefix.mjs` from
   [infer-protocol](https://github.com/fa11up/infer-protocol) and verified against a bought
   request before any money goes in.
2. **v1: the hub buys its own updates through Intake** (IdentityMD's on-chain request contract,
   proposed upstream). Pools then pay the request fee directly, the relayer bounty and its
   front-running problem go away, and a request lands as a callback.
3. **Epochs with refunds**, so a sponsor can leave cleanly at an epoch boundary.
4. **The hook as trigger.** Accept update requests from a self-funding v4 hook that watches its
   pool and asks only when price leaves a band.

## Open questions for the IdentityMD developer

These are the spec's questions we could **not** answer ourselves. The struct, the hash vectors,
the meaning of `agreed` and the document shape are all settled by the live attestation.

1. When does Intake reach mainnet, can a contract pay for a request in IMD through it, and what
   are its retry and refund guarantees?
2. What is the plan for service key rotation or compromise, and what notice will immutable
   consumers get?
3. What are the answer-type enum values for `address[]` and `bytes32[]`?
4. Can a requester set an explicit `{fromBlock, toBlock}` window, or only a relative one?
