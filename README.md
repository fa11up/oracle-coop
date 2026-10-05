# oracle-coop

A shared, immutable consumer for [IdentityMD](https://imd.fun) swarm oracle attestations. Many
protocols read the same question, a price for example. Each answer is verified once, and its cost is
split between whoever wants it kept fresh.

> **Status: v0, unaudited, testnet only.** Read [`docs/DESIGN.md`](docs/DESIGN.md) before relying
> on anything here.

## Why

A swarm price update costs about 4.25 USD. Bought hourly by one protocol, that is about
**37,230 USD a year**. The same IMD/ETH figure is wanted by several protocols at once, and an
attestation is signed for exactly one contract, so the way to share it is one shared contract.
Five sponsors pay about **7,446 USD each**.

## How it works

```
register(question) ──► id = keccak256(question)       anyone; immutable; no rights conferred
fund(id)           ──► pool[id] += msg.value          anyone; pays the update bounty
submit(id, att, sig, beneficiary)                     anyone; verifies, stores, maybe pays
latest(id) / checked(id, maxAge, minAgreed)           anyone; public reads
```

A **question** fixes everything that defines an answer: the canonical question-document prefix,
the data chain, the answer type, the window span bounds, the panel and agreement floors (as
counts), and the bounty schedule. Its id is the hash of all of it, so it can never change.

`submit` accepts an attestation only if the service signed it for **this hub**, it answers
**exactly this question** over a window that **moves forward**, enough panel members agreed, and
its request id is new. The hub rebuilds the question's hash itself; a genuine signature for any
other question is refused.

Each member protocol inherits [`CoopConsumer`](src/CoopConsumer.sol), which keeps its **own** last
accepted value and applies its own age, agreement and deviation limits. Two members can read one
hub and reach different conclusions about the same figure.

```solidity
contract MyVault is CoopConsumer {
    constructor(OracleCoopHub hub, bytes32 imdEthQuestion)
        CoopConsumer(hub, imdEthQuestion, 2 hours, 2_000 /* 20% */, 15 /* agreeing members */)
    {}

    function borrow(uint256 amount) external {
        uint256 price = _refresh(); // reverts if stale, thin, or past this vault's deviation cap
        // ...
    }

    function repay(uint256 amount) external {
        // no oracle read: safe actions keep working while the price is halted
    }
}
```

## Verified against the live service

[`test/LiveAttestation.t.sol`](test/LiveAttestation.t.sol) replays a real attestation signed by the
production service key (request `e2c85027`, 2026-10-04) and shows that:

- the hub accepts it;
- its prefix splice reproduces the live `questionHash`;
- the same signature is refused by a hub at any other address;
- the signature does not answer a different question registered on the same hub.

## Build and test

```bash
git clone --recurse-submodules https://github.com/fa11up/oracle-coop
cd oracle-coop
forge test
```

## Provenance

The design began as a spec written by the IdentityMD swarm, archived verbatim in
[`docs/SWARM-SPEC-2026-10-05.md`](docs/SWARM-SPEC-2026-10-05.md). We kept most of it and changed
five things on the evidence of the live service; each change is recorded in
[`docs/DESIGN.md`](docs/DESIGN.md). The verification core (question splice, window rules, signature
recovery) comes from `SwarmFeed` in
[infer-protocol](https://github.com/fa11up/infer-protocol), where it already accepts live
attestations on chain.

## License

MIT
