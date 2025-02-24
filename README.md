# MaxSpend

A secure Ethereum smart contract that implements a shared wallet with customizable spending limits and daily restrictions.

Contract Address = "0x1a372464c6eedc5d8ff052bfe484c89d04824b10c8ef5ce0545923ed4727ae2b"

 
 Features

- Multi-user wallet with owner controls
- Configurable spending limits per user
- Daily spending restrictions
- Real-time balance tracking
- Event logging for deposits and withdrawals

 Functions

- `addSpender`: Add authorized users with spending limits
- `removeSpender`: Remove user access
- `withdraw`: Withdraw funds (within limits)
- `getBalance`: Check wallet balance

Security

- Owner-only administrative functions
- Daily spending limits
- Automatic limit reset after 24 hours
- Required authorization checks

