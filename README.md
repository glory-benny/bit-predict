# 📈 BitPredict: Decentralized Price Prediction Markets on Stacks

**BitPredict** is a trustless prediction market protocol built on the [Stacks](https://www.stacks.co/) Layer 2 blockchain, leveraging Bitcoin’s security. It allows users to stake STX tokens on the directional movement of asset prices. Market outcomes are verified via a trusted oracle, and rewards are distributed proportionally to correct predictions, with transparent fee deductions for sustainability.

---

## ⚙️ Overview

* **Network:** Stacks Blockchain (secured by Bitcoin)
* **Token Used:** STX (Stacks Token)
* **Core Language:** Clarity (Stacks Smart Contracts)
* **Model:** Binary Prediction Markets (Up/Down)
* **Custody:** Non-custodial; funds managed by smart contract
* **Oracle:** Trusted off-chain data source authorized on-chain

---

## 🏗️ Protocol Architecture

```text
+-------------------+         +-----------------------+
|   User Wallets    | <-----> |     BitPredict SC     |
+-------------------+         +-----------------------+
                                    |     ▲
                                    |     |
                                    ▼     |
                          +------------------------+
                          |     Price Oracle       |
                          | (Externally Updated)   |
                          +------------------------+

[Key Flow]
1. Admin deploys & creates market → `create-market`
2. Users predict up/down & stake → `make-prediction`
3. Oracle submits final price     → `resolve-market`
4. Winners claim STX payouts      → `claim-winnings`
```

---

## ✨ Key Features

| Feature                        | Description                                     |
| ------------------------------ | ----------------------------------------------- |
| 🔒 **Trustless**               | All logic enforced by smart contracts           |
| 💰 **Proportional Rewards**    | Rewards distributed based on stake ratio        |
| 🧾 **Fee Transparency**        | 2% default protocol fee, configurable           |
| 🔐 **Oracle-Gated Resolution** | Only authorized oracles can settle markets      |
| 📈 **Multi-Market Support**    | Unlimited concurrent prediction markets         |
| ⚔️ **Anti-Manipulation**       | Claimable only post-resolution with validations |
| ⚙️ **Governable Parameters**   | Admin-controlled fees, minimums, oracle         |

---

## 📚 Functions Summary

### 🧾 Public Market Functions

| Function          | Description                                     |
| ----------------- | ----------------------------------------------- |
| `create-market`   | Admin-only, sets up a new prediction market     |
| `make-prediction` | Users stake STX on "up" or "down"               |
| `resolve-market`  | Oracle resolves market with final price         |
| `claim-winnings`  | Users claim rewards if they predicted correctly |

### 🔍 Read-only Queries

| Function               | Description                          |
| ---------------------- | ------------------------------------ |
| `get-market`           | Fetch details of a specific market   |
| `get-user-prediction`  | Get a user's prediction for a market |
| `get-contract-balance` | View contract's STX holdings         |

### 🛠️ Admin Functions

| Function             | Description                      |
| -------------------- | -------------------------------- |
| `set-oracle-address` | Update the authorized oracle     |
| `set-minimum-stake`  | Adjust minimum required stake    |
| `set-fee-percentage` | Change platform fee (max 100%)   |
| `withdraw-fees`      | Admin withdraws accumulated fees |

---

## 🧪 Example Workflow

1. **Deploy Contract** as admin
2. **Create Market**

   ```clojure
   (create-market u35000 u11000 u11500)
   ```

3. **Users Predict**

   ```clojure
   (make-prediction u0 "up" u1000000)
   ```

4. **Oracle Resolves**

   ```clojure
   (resolve-market u0 u36000)
   ```

5. **Users Claim Winnings**

   ```clojure
   (claim-winnings u0)
   ```

---

## 🔐 Security Considerations

* Funds only leave the contract on valid predictions with verified outcomes.
* Oracle access is strictly permissioned.
* Prediction records prevent multiple claims (via `claimed` flag).
* All STX transfers use `try!` with `as-contract` for safe execution.

## 📬 Contact & Community

* 🧠 Contribute on GitHub
* 💬 Join the Stacks Discord: [https://discord.com/invite/stacks](https://discord.com/invite/stacks)
* 🔔 For oracle setup or integration inquiries, reach out via [Stacks Forum](https://forum.stacks.org/)
