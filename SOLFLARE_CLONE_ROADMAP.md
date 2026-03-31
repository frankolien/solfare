# Solflare Clone - Complete Build Roadmap

> You are here: Phase 1 (Wallet Creation) is mostly done.
> This guide tells you WHAT to build and in WHAT ORDER - no code, just the algorithm.

---

## Phase 1: Wallet Foundation (DONE)

**Goal:** User can create a wallet, back up their recovery phrase, and secure it.

### What you built:
- Generate a 12/24-word mnemonic (BIP39)
- Derive a Solana keypair from the mnemonic (ED25519 + HD key derivation)
- Show the user their recovery phrase
- Confirm the user wrote it down (confirm recovery phrase screen)
- Set up a passcode to protect the wallet
- Optional biometric setup
- Store the wallet securely on device (flutter_secure_storage)
- Splash screen and onboarding flow
- Basic homepage that shows wallet info

### What you learned:
- How BIP39 mnemonics work (entropy -> words -> seed)
- How HD key derivation works (seed -> master key -> child keys using derivation path)
- How Solana uses ED25519 keypairs (private key signs, public key = your address)
- How Base58 encoding turns raw bytes into a readable Solana address
- How flutter_secure_storage keeps secrets safe on device

---

## Phase 2: Read Blockchain Data

**Goal:** Your app can READ data from the Solana blockchain. No sending yet - just looking.

### Step 1: Understand Solana RPC
- Solana nodes expose a JSON-RPC API
- You send HTTP POST requests with a method name and params
- The node responds with blockchain data
- Devnet is your playground (free, test SOL, no real money)

### Step 2: Fetch Wallet Balance
- Call `getBalance` RPC method with your wallet's public key
- Response comes back in **lamports** (1 SOL = 1,000,000,000 lamports)
- Convert lamports to SOL for display
- Show balance on homepage

### Step 3: Request Devnet Airdrop
- Call `requestAirdrop` RPC method
- This gives you free test SOL on devnet
- Use it to test everything without real money
- Show success/failure feedback to user

### Step 4: Fetch Transaction History
- Call `getSignaturesForAddress` to get list of transaction signatures
- For each signature, call `getTransaction` to get full details
- Parse out: sender, receiver, amount, timestamp, status
- Display as a scrollable list on homepage

### Step 5: Fetch Token Accounts (SPL Tokens)
- Call `getTokenAccountsByOwner` to see what tokens the wallet holds
- Each token account tells you: which token (mint address), how many
- You'll need token metadata to show names/logos (comes later)

### What you'll learn:
- How JSON-RPC works (it's just HTTP POST with a specific format)
- How Solana stores balances (accounts model, not UTXO like Bitcoin)
- What lamports are and why blockchains use smallest units
- How transaction signatures work as unique IDs
- What SPL tokens are (Solana's version of ERC-20)

---

## Phase 3: Send SOL

**Goal:** User can send SOL from their wallet to another address.

### Step 1: Build the Send Screen UI
- Input field for recipient address (public key)
- Input field for amount in SOL
- Show current balance so user knows what they have
- "Max" button to send entire balance (minus fee)
- Validate the recipient address is a valid Solana public key (Base58, 32 bytes)

### Step 2: Understand Solana Transactions
- A transaction contains: instructions, recent blockhash, fee payer, signatures
- For sending SOL, you need a **SystemProgram.transfer** instruction
- The recent blockhash acts as a "nonce" to prevent replay attacks (expires in ~60 seconds)
- The fee payer is the sender (you)
- Transaction fees on Solana are tiny (~0.000005 SOL)

### Step 3: Build the Transaction
- Fetch a recent blockhash from `getLatestBlockhash`
- Construct a transfer instruction (from, to, lamports)
- Combine into a transaction message
- Serialize the message into bytes

### Step 4: Sign the Transaction
- Load the private key from secure storage
- Sign the serialized transaction bytes with ED25519
- Attach the signature to the transaction

### Step 5: Send and Confirm
- Call `sendTransaction` RPC with the signed, serialized transaction (base64 encoded)
- Get back a transaction signature (the tx ID)
- Call `confirmTransaction` or poll `getSignatureStatuses` to wait for confirmation
- Show success/failure to user with the signature as a link to Solana Explorer

### Step 6: Confirmation Screen
- Show transaction details (to, amount, fee, signature)
- Link to view on Solana Explorer
- Button to go back to homepage
- Auto-refresh balance after confirmation

### What you'll learn:
- How Solana transactions are structured (instructions, blockhash, signatures)
- What the SystemProgram is (Solana's built-in program for basic operations)
- How transaction signing works (proving you own the private key)
- How transaction confirmation works (finalized vs confirmed vs processed)
- What transaction fees are and how they work on Solana

---

## Phase 4: SPL Tokens

**Goal:** User can view and send any SPL token (USDC, BONK, etc.)

### Step 1: Understand SPL Token Program
- SPL Token is Solana's standard for fungible tokens (like ERC-20 on Ethereum)
- Each token has a **mint address** (the token's identity)
- Each wallet has **token accounts** (one per token they hold)
- Token accounts are separate from your main SOL account

### Step 2: Fetch Token Balances
- Use `getTokenAccountsByOwner` to find all token accounts
- For each, get the mint address and balance
- Token balances use **decimals** (USDC has 6, so 1000000 = 1 USDC)

### Step 3: Get Token Metadata
- Use the Metaplex Token Metadata program or a metadata API
- Fetch: token name, symbol, logo image URL, decimals
- Cache this locally so you don't re-fetch every time
- Display tokens with their logos in a list

### Step 4: Send SPL Tokens
- Similar to sending SOL but uses the **Token Program** instead of SystemProgram
- Need to check if recipient has a token account for that token
- If not, you may need to create an **Associated Token Account** (ATA) for them
- Creating an ATA costs a small amount of SOL (rent)
- Build, sign, send just like Phase 3 but with token transfer instruction

### Step 5: Token List Screen
- Show all tokens the wallet holds with balances and USD values
- Sort by value or alphabetically
- Pull-to-refresh to update balances
- Tap a token to see its details and transaction history

### What you'll learn:
- How the SPL Token Program works
- What Associated Token Accounts (ATAs) are and why they exist
- How token decimals work
- How Metaplex metadata program stores token info
- The difference between native SOL and SPL tokens

---

## Phase 5: Price Data and Portfolio

**Goal:** Show real USD values and portfolio tracking.

### Step 1: Fetch Token Prices
- Use CoinGecko or Jupiter Price API to get USD prices
- Map token mint addresses to price data
- Cache prices locally with a TTL (don't spam the API)

### Step 2: Portfolio Value
- Calculate: each token balance x price = value
- Sum all values = total portfolio value
- Show on homepage as the main number

### Step 3: Price Charts
- Fetch historical price data (24h, 7d, 30d, 1y)
- Display as a line chart on the token detail screen
- Show price change percentage with green/red colors

### Step 4: Price Change Notifications (Optional)
- Track price changes in background
- Show percentage change badges on token list

### What you'll learn:
- How crypto price APIs work
- Caching strategies for API data
- How to build financial UIs (charts, formatters, currency display)

---

## Phase 6: Swap (DEX Integration)

**Goal:** User can swap one token for another directly in the app.

### Step 1: Understand DEX Aggregators
- Jupiter is Solana's main DEX aggregator
- It finds the best price across all Solana DEXes (Raydium, Orca, etc.)
- You send it: input token, output token, amount
- It returns: a transaction you can sign and send

### Step 2: Build Swap UI
- "From" token selector with amount input
- "To" token selector showing estimated output
- Show exchange rate, price impact, minimum received
- Slippage tolerance setting (0.5%, 1%, custom)

### Step 3: Get Swap Quote
- Call Jupiter Quote API with input/output mint and amount
- Display the quote: expected output, price impact, route
- Show which DEXes the swap will route through

### Step 4: Execute Swap
- Call Jupiter Swap API to get the transaction
- Deserialize the transaction
- Sign it with user's keypair
- Send and confirm
- Refresh token balances after

### Step 5: Swap History
- Track completed swaps locally
- Show: tokens swapped, amounts, rate, timestamp

### What you'll learn:
- How DEX aggregators work
- What liquidity pools are
- What slippage and price impact mean
- How complex transactions with multiple instructions work
- How Jupiter's API abstracts away DEX complexity

---

## Phase 7: NFTs and Collectibles

**Goal:** User can view their NFTs and send them.

### Step 1: Understand Solana NFTs
- NFTs on Solana are just SPL tokens with supply of 1
- Metadata is stored via Metaplex standard
- Images/media are stored off-chain (Arweave, IPFS, or regular URLs)

### Step 2: Fetch NFTs
- Use `getTokenAccountsByOwner` filtered for NFTs (amount = 1, decimals = 0)
- For each, fetch Metaplex metadata (name, image URI, attributes)
- Load and cache images

### Step 3: NFT Gallery
- Grid view of NFT images
- Tap to see full details (name, description, attributes, collection)
- Show which collection it belongs to

### Step 4: Send NFTs
- Same as sending an SPL token but amount is always 1
- Recipient needs an ATA for the NFT's mint
- Build, sign, send the transfer transaction

### What you'll learn:
- How NFTs work on Solana (Metaplex standard)
- Difference between on-chain and off-chain metadata
- How Arweave/IPFS provide permanent storage
- How collections group NFTs together

---

## Phase 8: Staking

**Goal:** User can stake SOL to earn rewards.

### Step 1: Understand Solana Staking
- Staking = delegating SOL to a validator to help secure the network
- You earn ~6-8% APY in rewards
- Staked SOL is locked - unstaking takes ~2-3 days (deactivation period)
- You create a **stake account** and delegate it to a validator

### Step 2: Fetch Validators
- Call `getVoteAccounts` to get list of active validators
- Show: name, commission %, total stake, APY estimate
- Sort by performance/commission

### Step 3: Stake SOL
- Create a stake account (SystemProgram.createAccount)
- Initialize it (StakeProgram.initialize)
- Delegate to chosen validator (StakeProgram.delegate)
- This is a multi-instruction transaction

### Step 4: View Stakes
- Fetch user's stake accounts
- Show: validator, amount staked, status (activating/active/deactivating), rewards earned

### Step 5: Unstake
- Deactivate stake account (StakeProgram.deactivate)
- Wait for deactivation (1-2 epochs, ~2-3 days)
- Withdraw back to main wallet (StakeProgram.withdraw)

### What you'll learn:
- How Proof of Stake consensus works
- What validators do and how they're chosen
- What epochs are on Solana
- How stake accounts differ from regular accounts
- How staking rewards are distributed

---

## Phase 9: WalletConnect / dApp Browser

**Goal:** User can connect their wallet to web3 dApps.

### Step 1: Understand Wallet Adapters
- dApps need to request your wallet to sign transactions
- WalletConnect is a protocol for this communication
- Your wallet acts as a signer - the dApp builds the transaction, you approve and sign it

### Step 2: Deep Link Handling
- Register your app to handle Solana deep links
- Parse incoming transaction requests
- Show the user what they're approving

### Step 3: Transaction Approval Screen
- Parse and display the transaction details in human-readable format
- Show: what programs are being called, estimated cost, risk level
- Approve or reject buttons
- Sign and return the signature to the dApp

### Step 4: dApp Browser (Optional)
- Embed a WebView that injects a wallet provider
- User can browse dApps directly in your app
- Intercept signing requests from the web page

### What you'll learn:
- How wallet-dApp communication works
- What deep links are and how mobile apps use them
- How to parse and display arbitrary Solana transactions
- Security considerations (showing users exactly what they're signing)

---

## Phase 10: Multi-Wallet and Import

**Goal:** User can manage multiple wallets and import existing ones.

### Step 1: Import via Recovery Phrase
- Accept a 12 or 24-word mnemonic
- Validate words against BIP39 wordlist
- Derive the same keypair and show the address
- Store alongside other wallets

### Step 2: Import via Private Key
- Accept a Base58-encoded private key
- Derive the public key from it
- No mnemonic to store - just the keypair

### Step 3: Multiple Wallets
- Store multiple wallets in secure storage with labels
- Wallet switcher UI
- Each wallet has its own balances, tokens, transactions
- One "active" wallet at a time

### Step 4: HD Wallet Derivation Paths
- From one mnemonic, derive multiple wallets using different paths
- Solana uses: m/44'/501'/0'/0' for first wallet, m/44'/501'/1'/0' for second, etc.
- Let user add accounts from same seed phrase

### What you'll learn:
- How HD wallets derive multiple keys from one seed
- What derivation paths mean (BIP44 standard)
- How to manage multiple secure storage entries
- UX patterns for multi-account wallets

---

## Phase 11: Security Hardening

**Goal:** Make the wallet production-grade secure.

### Step 1: Encryption at Rest
- Encrypt private keys with user's passcode before storing
- Use AES-256 encryption
- The passcode derives an encryption key (PBKDF2 or Argon2)

### Step 2: Biometric Authentication
- Gate sensitive actions behind biometric (send, sign, export keys)
- Not just app unlock - per-action authentication for high-risk operations

### Step 3: Auto-Lock
- Lock the app after X minutes of inactivity
- Clear sensitive data from memory when locked
- Require passcode/biometric to unlock

### Step 4: Transaction Simulation
- Before signing, simulate the transaction using `simulateTransaction` RPC
- Show the user what will change (balance changes, token transfers)
- Flag suspicious transactions (draining all tokens, interacting with unknown programs)

### Step 5: Phishing Protection
- Warn when sending to a new address for the first time
- Address book for saved/trusted addresses
- Domain verification for dApp connections

### What you'll learn:
- How encryption protects data at rest
- Key derivation functions (turning a passcode into an encryption key)
- Mobile security best practices
- How transaction simulation prevents mistakes
- Common crypto scam patterns and how to defend against them

---

## Phase 12: Polish and Production

**Goal:** Make it feel like a real, polished app.

### Step 1: Mainnet Support
- Switch from devnet to mainnet-beta
- Handle network switching (devnet for testing, mainnet for real)
- Real money = real consequences, triple-check everything

### Step 2: Error Handling
- Network errors (no internet, RPC timeout)
- Insufficient balance errors
- Transaction failure reasons
- User-friendly error messages (not raw error dumps)

### Step 3: Performance
- Cache aggressively (balances, token metadata, prices)
- Lazy load token images
- Pagination for transaction history
- Background refresh

### Step 4: UI/UX Polish
- Loading skeletons instead of spinners
- Pull-to-refresh everywhere
- Haptic feedback on important actions
- Smooth animations and transitions
- Dark mode

### Step 5: Testing
- Unit tests for BLoC logic
- Unit tests for data sources (mock HTTP)
- Widget tests for key screens
- Integration tests for critical flows (create wallet, send SOL)

### What you'll learn:
- The difference between devnet and mainnet
- Production error handling patterns
- Mobile performance optimization
- Testing strategies for Flutter apps
- What makes a wallet feel trustworthy

---

## Solana Concepts You'll Master Along The Way

| Phase | Concept |
|-------|---------|
| 1 | Keypairs, mnemonics, HD derivation, Base58 |
| 2 | RPC API, accounts model, lamports, signatures |
| 3 | Transactions, instructions, blockhash, signing, SystemProgram |
| 4 | SPL Token Program, ATAs, mint addresses, decimals |
| 5 | Price oracles, portfolio math |
| 6 | DEXes, liquidity pools, slippage, Jupiter |
| 7 | Metaplex, NFT standards, off-chain storage |
| 8 | Proof of Stake, validators, epochs, stake accounts |
| 9 | Wallet adapters, deep links, dApp communication |
| 10 | BIP44 derivation paths, multi-account management |
| 11 | Encryption, simulation, phishing defense |
| 12 | Mainnet, production ops, testing |

---

## How Solana Actually Works (Mental Model)

```
Everything on Solana is an ACCOUNT.

Account = {
    address (public key),
    owner (which program controls it),
    lamports (SOL balance),
    data (arbitrary bytes),
    executable (is it a program?)
}

Your wallet? An account.
A token balance? An account.
An NFT? An account.
A stake? An account.
A program (smart contract)? An account.

Transactions contain INSTRUCTIONS.
Instructions tell PROGRAMS to modify ACCOUNTS.

"Send 1 SOL" =
    Instruction to SystemProgram:
    "transfer 1000000000 lamports from Account A to Account B"

"Send USDC" =
    Instruction to TokenProgram:
    "transfer 1000000 from TokenAccount A to TokenAccount B"

Programs are stateless. All state lives in accounts.
This is fundamentally different from Ethereum where contracts hold their own state.
```

Good luck - you're building something real.
