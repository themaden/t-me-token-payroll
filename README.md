Time-Token Payroll (Streaming Payments)

Real-time, on-chain payroll: salaries stream every second instead of monthly payouts.
Employees can withdraw the accrued balance anytime; employers fund a contract once per pay period.

Think “Spotify stream” but for money. 🎶💸

✨ Features

Per-second streaming of stablecoins (Mock USDC for local dev; USDC on testnets/mainnet).

Pull model for employees: withdraw the earned amount anytime.

Employer-funded pay periods to ensure solvency.

Minimal, auditable core:

createStream(employee, token, deposit, start, stop)

balanceOf(streamId) → (earned, withdrawable)

withdraw(streamId, amount)

cancel(streamId) with pro-rata settlement

Foundry toolchain (forge/anvil/cast), OpenZeppelin ERC-20 utils.

🏗️ Architecture
Employer (funds deposit) ──▶ TimeStream (escrow & schedule) ──▶ Employee (withdraw)
                                 │
                                 └── IERC20 stablecoin (e.g., USDC)


Rate calculation: ratePerSecond = deposit / (stop - start) (integer division; remainder discarded).

Escrowed amount: contract transfers exactly ratePerSecond * duration up-front from employer to itself.

📦 Tech Stack

Solidity ^0.8.24

Foundry (forge, anvil, cast)

OpenZeppelin Contracts (IERC20, SafeERC20)

(Optional) jq for parsing broadcast output

📁 Repository Layout
.
├─ src/
│  ├─ TimeStream.sol      # core streaming payroll contract
│  └─ MockUSDC.sol        # 6-decimals ERC20 for local testing
├─ scripts/
│  ├─ Deploy.s.sol        # deploys MockUSDC + TimeStream
│  └─ CreateDemo.s.sol    # mints, approves and creates a 30d stream
├─ test/
│  └─ TimeStream.t.sol    # example test (warp time + withdraw)
├─ foundry.toml
└─ README.md

⚙️ Prerequisites

Ubuntu (or WSL), Git, build tools:

sudo apt update
sudo apt install -y build-essential pkg-config libssl-dev git curl jq


Foundry:

curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
forge --version && anvil --version && cast --version

🚀 Quick Start (Local)

Clone & build

git clone <your-repo-url> time-token-payroll
cd time-token-payroll
forge build


Run a local chain

anvil
# keep this terminal open (chainId=31337)


Environment variables (create .env in repo root)

# Employer = Anvil Account #0 (private key)
EMPLOYER_PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Employee = Anvil Account #1 (ADDRESS, not private key)
EMPLOYEE_ADDR=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

# Will be filled after deploy:
USDC_ADDR=
TIMESTREAM_ADDR=


Load it into your shell:

set -a; source ./.env; set +a


Deploy contracts (MockUSDC + TimeStream)

SENDER_ADDR=$(cast wallet address --private-key $EMPLOYER_PK)

forge script scripts/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --sender $SENDER_ADDR \
  --private-key $EMPLOYER_PK


Copy the printed addresses (or parse from broadcast JSON) and update .env:

# Example (your addresses will differ)
USDC_ADDR=0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
TIMESTREAM_ADDR=0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9

set -a; source ./.env; set +a


Verify there’s bytecode (not just 0x):

cast code $USDC_ADDR --rpc-url http://127.0.0.1:8545 | head
cast code $TIMESTREAM_ADDR --rpc-url http://127.0.0.1:8545 | head


Create a demo stream (scripted)

forge script scripts/CreateDemo.s.sol:CreateDemo \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast
# Logs will show StreamID, start & stop timestamps


Withdraw as employee (after start time)

# Example: withdraw 50 mUSDC (USDC has 6 decimals)
cast send $TIMESTREAM_ADDR \
  "withdraw(uint256,uint256)" 1 50000000 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d


If you see bad amount, wait until the stream has started or withdraw a smaller amount.

🔬 Tests
forge test -vv


The example test warps time forward, checks balanceOf, and performs a partial withdraw.

🧩 Contracts Overview
TimeStream.sol

createStream(address employee, IERC20 token, uint256 deposit, uint40 start, uint40 stop) returns (uint256 id)
Transfers required = ratePerSecond * duration from employer to the contract and starts the schedule.

balanceOf(uint256 id) view returns (uint256 earned, uint256 withdrawable)
Calculates what’s been earned and what can be withdrawn now.

withdraw(uint256 id, uint256 amount)
Employee pulls funds they’ve earned.

cancel(uint256 id)
Either party can cancel; employee receives earned-but-unwithdrawn, employer gets the refund for the remaining period.

Important notes

Rounding down: ratePerSecond = deposit / duration. Any remainder is excluded to keep accounting exact.

Escrow amount equals ratePerSecond * duration. Provide enough deposit to cover the full period at the chosen granularity.

MockUSDC.sol

6-decimals ERC-20 for local development.

mint(address to, uint256 amount) exposed for testing.

🖥️ Manual Flow (without the demo script)
# 1) Mint 3000 mUSDC to employer
EMPLOYER=$(cast wallet address --private-key $EMPLOYER_PK)
cast send $USDC_ADDR "mint(address,uint256)" $EMPLOYER 3000000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $EMPLOYER_PK

# 2) Approve TimeStream to spend deposit
cast send $USDC_ADDR "approve(address,uint256)" $TIMESTREAM_ADDR 3000000000 \
  --rpc-url http://127.0.0.1:8545 --private-key $EMPLOYER_PK

# 3) Create a 30-day stream starting in 60 seconds
START=$(($(date +%s) + 60))
STOP=$(($START + 30*24*60*60))

cast send $TIMESTREAM_ADDR \
  "createStream(address,address,uint256,uint40,uint40)" \
  $EMPLOYEE_ADDR $USDC_ADDR 3000000000 $START $STOP \
  --rpc-url http://127.0.0.1:8545 --private-key $EMPLOYER_PK

# 4) Check balances
cast call $TIMESTREAM_ADDR "balanceOf(uint256)(uint256,uint256)" 1 \
  --rpc-url http://127.0.0.1:8545

🌐 Testnet Deployment (Optional: Sepolia)

Get an RPC URL and fund employer with test ETH.

SEPOLIA_RPC=https://eth-sepolia.g.alchemy.com/v2/<KEY>


Deploy:

forge script scripts/Deploy.s.sol:Deploy \
  --rpc-url $SEPOLIA_RPC \
  --broadcast \
  --sender $(cast wallet address --private-key $EMPLOYER_PK) \
  --private-key $EMPLOYER_PK


Update .env with the new addresses and repeat the Create Demo flow against $SEPOLIA_RPC.

Employees withdrawing on testnet need a bit of test ETH for gas unless you add a Paymaster (gasless UX).

🛠️ Troubleshooting

call to non-contract address
You restarted Anvil; addresses changed. Redeploy and update .env (check with cast code <addr>).

default sender warning
Provide both --sender and --private-key, or call vm.startBroadcast(pk) inside the script (env-driven).

contract source info format must be <path>:<contractname>
Use scripts/Deploy.s.sol:Deploy (note the :ContractName suffix).

bad amount on withdraw
Stream hasn’t started or you’re withdrawing more than withdrawable. Wait or request a smaller amount.

Address vs private key mix-up
Address = 40 hex chars, Private key = 64 hex. Don’t paste PK into an address field.

🔒 Security & Production Notes

This is a reference/MVP implementation. Before mainnet:

Add pause/resume, allowlists, and emergency escape hatches.

Review reentrancy (we use ReentrancyGuard) and overflow/underflow (Solidity 0.8+ checked math).

Consider tax/benefit deductions, holidays, and overtime modules.

Audit the code and integrate with a vetted streaming protocol (e.g., Superfluid/Sablier) if desired.

🗺️ Roadmap

Pause/Resume per stream

Deductions module (tax, benefits, fees)

Gasless withdraw via Paymaster

Next.js UI: view stream status, withdraw now, employer dashboard

Cross-chain streaming (intent-based execution)

📜 License

MIT

🙏 Acknowledgements

OpenZeppelin Contracts

Foundry (Paradigm)

Community inspiration from streaming protocols (Superfluid, Sablier)