# Campaign Funding Smart Contract

A decentralized crowdfunding platform built on the Stacks blockchain that enables milestone-based funding campaigns with democratic governance and automatic refunds.

## Overview

This smart contract allows creators to launch funding campaigns with specific targets and deadlines. Backers can invest in campaigns and participate in milestone approval votes. The contract ensures funds are only released when milestones are approved by the community, providing protection for both creators and backers.

## Key Features

- **Milestone-Based Funding**: Funds are released incrementally based on approved project phases
- **Democratic Governance**: Backers vote on milestone completion using weighted voting (based on investment amount)
- **Automatic Refunds**: If funding goal isn't met by deadline, backers can claim full refunds
- **Secure Fund Management**: Funds are held in the contract until properly released
- **Investment Tracking**: Complete transparency of all contributions and campaign progress

## Contract Functions

### Setup Functions

#### `setup-campaign(target, timeframe)`
Initializes a new funding campaign.
- `target`: Funding goal in microSTX
- `timeframe`: Campaign duration in blocks (max 52,560 blocks ≈ 1 year)
- Only callable once per contract deployment
- Sets the caller as campaign creator

### Investment Functions

#### `make-investment(value)`
Allows users to invest in the active campaign.
- `value`: Investment amount in microSTX
- Must be > 0 and not exceed remaining funding goal
- Transfers STX to contract and tracks contributor
- Only works during active campaign period

#### `claim-refund()`
Enables backers to recover investments from failed campaigns.
- Only available after campaign deadline if goal not met
- Returns full investment amount to backer
- Removes backer from contributor records

### Governance Functions

#### `initiate-ballot()`
Starts a voting period for milestone approval.
- Only callable by campaign creator
- Resets vote counters
- Changes campaign status to "voting"

#### `cast-ballot(support)`
Allows backers to vote on current milestone.
- `support`: true for approval, false for rejection
- Vote weight equals investment amount
- Only contributors can vote during voting periods

#### `conclude-ballot()`
Finalizes the voting process and determines outcome.
- Only callable by campaign creator
- Approves milestone if approval votes > rejection votes
- Advances to next phase on approval
- Returns error code on rejection

### Management Functions

#### `create-phase(description, value)`
Defines project milestones and their funding amounts.
- `description`: UTF-8 description (max 256 characters)
- `value`: Funding amount for this phase
- Only callable by campaign creator

#### `extract-funds(value)`
Allows creator to withdraw approved funds.
- `value`: Amount to withdraw in microSTX
- Cannot exceed total collected amount
- Only callable by campaign creator

### Read-Only Functions

#### `get-campaign-info()`
Returns comprehensive campaign details including owner, goals, raised amounts, deadline, status, and current milestone.

#### `get-investment(backer)`
Returns the total investment amount for a specific backer.

#### `get-phase(phase-id)`
Returns milestone details for a specific phase ID.

## Campaign States

- **`not_started`**: Initial state before campaign setup
- **`active`**: Campaign is running and accepting investments
- **`voting`**: Milestone voting period is active

## Error Codes

- `u100`: Unauthorized access
- `u101`: Contract already initialized
- `u102`: Record not found
- `u103`: Campaign has expired
- `u104`: Funding target not met
- `u105`: Insufficient balance
- `u106`: Invalid amount/value
- `u107`: Invalid timeframe
- `u108`: Ballot/vote rejected
- `u109`: Invalid description length

## Usage Example

1. **Deploy Contract**: Creator deploys and calls `setup-campaign`
2. **Accept Investments**: Backers call `make-investment` during active period
3. **Create Milestones**: Creator defines project phases with `create-phase`
4. **Vote on Progress**: Creator initiates voting, backers vote on milestone completion
5. **Release Funds**: Upon approval, creator can withdraw funds for that phase
6. **Repeat**: Process continues for each milestone until project completion

## Security Features

- Time-locked campaigns with automatic expiration
- Weighted democratic voting prevents manipulation
- Funds held in contract escrow until milestone approval
- Automatic refund mechanism for failed campaigns
- Creator authorization checks for all management functions

## Requirements

- Stacks blockchain environment
- STX tokens for investments
- Clarity smart contract runtime
