deployed contract: https://sepolia.etherscan.io/address/0xf2695bfb1ddd9da0781b5e5290895022192753eb

## How It Works

1. **Creating a Voting**: An admin creates a voting with a description, threshold, and duration
2. **Pledging Tokens**: Users pledge tokens for or against a proposal, specifying an amount and stake duration
3. **Voting Power Calculation**: Voting power = amount × duration² 
4. **Finalization**: 
   - Automatic: When either the "for" or "against" votes reach the threshold
   - Manual: By admin or oracle after the deadline has passed
5. **NFT Minting**: An NFT is minted to the contract with metadata about the voting result
6. **Token Recovery**: Users can unpledge their tokens after their stake period ends

## Key Functions

### For Admins

- `createVoting(string description, uint256 votingThreshold, uint32 votingDuration)`: Create a new voting proposal
- `finalizeVotingByDeadline(uint256 votingId)`: Finalize a voting after its deadline

### For Users

- `pledge(uint256 votingId, uint256 amount, uint32 stakeDuration, bool isFor)`: Stake tokens to vote
- `unpledge(uint256 votingId, uint voteId)`: Recover staked tokens after stake period

## Voting Power Mechanism

The voting power is calculated as:
```
votingPower = stakeAmount * stakeDuration * stakeDuration
```

This mechanism encourages users to commit for longer periods, giving more weight to those with longer-term alignment.

## NFT Metadata

Each voting result is recorded as an NFT with metadata in the following format:
```json
{
  "description": "Voting description",
  "votedFor": "Total voting power for",
  "votedAgainst": "Total voting power against",
  "result": "Passed/Failed"
}
```

These NFTs serve as permanent, immutable records of voting results and are owned by the contract itself.
