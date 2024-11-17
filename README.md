# Mempool Real-Time Live Tracker

A smart contract for the Stacks blockchain that provides real-time mempool tracking, fee recommendations, and transaction management capabilities.

## Overview

This smart contract enables real-time monitoring of the Stacks blockchain mempool, offering features such as:

- Transaction tracking and status management
- User watchlist functionality
- Fee statistics and recommendations
- Real-time mempool metrics
- Configurable fee thresholds

## Features

### Transaction Tracking

- Track individual transactions with detailed metadata
- Monitor transaction status (confirmed/unconfirmed)
- Calculate transaction priorities based on fee rates and sizes
- Estimate confirmation times based on network congestion

### User Watchlists

- Create and manage personal transaction watchlists
- Set custom alert thresholds
- Enable/disable notifications
- Support for up to 100 transactions per watchlist

### Fee Statistics

- Track average, minimum, and maximum fee rates
- Provide fee recommendations for different priority levels (low, medium, high)
- Historical fee data storage by block height

### Mempool Metrics

- Monitor mempool size and transaction count
- Track average confirmation times
- Calculate network congestion levels
- Real-time updates of mempool statistics

## Technical Specifications

### Constants

- Maximum transaction size: 1MB
- Maximum fee rate: 1,000,000
- Minimum fee rate: 1
- Maximum congestion level: 100
- Maximum confirmation time: 2 hours (7200 seconds)

### Data Structures

#### Tracked Transactions

```clarity
{
    fee-rate: uint,
    size: uint,
    priority: uint,
    timestamp: uint,
    confirmed: bool,
    category: string-ascii,
    prediction: uint
}
```

#### User Watchlists

```clarity
{
    tx-ids: (list 100 string-ascii),
    alert-threshold: uint,
    notifications-enabled: bool
}
```

#### Fee Statistics

```clarity
{
    avg-fee: uint,
    min-fee: uint,
    max-fee: uint,
    recommended-low: uint,
    recommended-medium: uint,
    recommended-high: uint,
    total-tx-count: uint
}
```

#### Mempool Metrics

```clarity
{
    size: uint,
    tx-count: uint,
    avg-confirmation-time: uint,
    congestion-level: uint
}
```

## Public Functions

### Transaction Management

- `track-transaction`: Add a new transaction to tracking
- `update-transaction-status`: Update confirmation status of a transaction
- `get-transaction-details`: Retrieve details of a tracked transaction

### Watchlist Management

- `add-to-watchlist`: Add transaction to user's watchlist
- `get-user-watchlist`: Retrieve user's watchlist

### Statistics and Metrics

- `update-fee-statistics`: Update block-height based fee statistics
- `update-mempool-metrics`: Update real-time mempool metrics
- `get-fee-statistics`: Retrieve fee statistics for a specific block height

### Administrative Functions

- `set-min-fee-threshold`: Update minimum fee threshold
- `transfer-ownership`: Transfer contract ownership

## Error Codes

| Code | Description            |
| ---- | ---------------------- |
| 1000 | Not authorized         |
| 1001 | Invalid parameters     |
| 1002 | Not found              |
| 1003 | Already exists         |
| 1004 | Invalid fee            |
| 1005 | Invalid size           |
| 1006 | Invalid threshold      |
| 1007 | Invalid stats          |
| 1008 | Invalid metrics        |
| 1009 | Invalid category       |
| 1010 | Invalid transaction ID |
| 1011 | Invalid user           |
| 1012 | Invalid height         |
| 1013 | Invalid owner          |

## Security Features

- Owner-only administrative functions
- Comprehensive input validation
- Threshold-based fee validation
- Transaction ID format verification
- Size and rate limitations

## Installation and Usage

1. Deploy the contract to the Stacks blockchain
2. Initialize with appropriate minimum fee threshold
3. Begin tracking transactions and updating mempool metrics
4. Monitor fee statistics and transaction statuses
5. Set up user watchlists as needed

## Security Considerations

- Only contract owner can update critical metrics
- All inputs are validated before processing
- Transaction IDs must be valid 64-character hex strings
- Fee rates must fall within acceptable ranges
- Size limitations prevent resource exhaustion
