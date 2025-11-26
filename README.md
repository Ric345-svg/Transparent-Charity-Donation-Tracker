# 🏥 Transparent Charity Donation Tracker

> A smart contract that ensures donations reach their intended beneficiaries through milestone-based fund release 💝

## 🎯 Problem Statement

Traditional charity donations lack transparency - donors can't verify if their funds actually reach the beneficiaries they intended to help. This creates trust issues and reduces donation confidence.

## ✨ Solution

Our smart contract implements a transparent, milestone-based donation system where:
- 📊 Donations are held in escrow until specific milestones are completed
- 🎯 Funds are released only when campaign owners prove milestone completion
- 🔍 Full transparency for all donors to track progress
- 💰 Automatic refunds if campaigns fail to meet their goals

## 🚀 Features

### For Campaign Creators
- 📝 Create campaigns with detailed descriptions and target amounts
- 🏁 Set up multiple milestones with specific funding requirements
- ⏰ Define campaign deadlines
- ✅ Mark milestones as completed to release funds
- 🔒 Secure ownership controls

### For Donors
- 💸 Donate STX tokens to campaigns
- 📈 Track real-time campaign progress
- 🔍 View milestone completion status
- 💫 Get refunds if campaigns are closed incomplete

### For Beneficiaries
- 💰 Withdraw funds as milestones are completed
- 🏆 Receive payments directly to their wallet
- 📋 Clear milestone requirements and progress tracking

## 🛠️ Contract Functions

### Public Functions

#### `create-campaign`
Creates a new charity campaign with specified number of milestones
```clarity
(create-campaign beneficiary title description target-amount deadline total-milestones)
```

#### `add-milestone`
Add a milestone to an existing campaign (campaign owner only)
```clarity
(add-milestone campaign-id milestone-id description amount)
```

#### `donate`
Donate STX tokens to a specific campaign
```clarity
(donate campaign-id amount)
```

#### `complete-milestone`
Mark a milestone as completed (campaign owner only)
```clarity
(complete-milestone campaign-id milestone-id)
```

#### `withdraw-milestone-funds`
Withdraw funds for completed milestones (beneficiary only)
```clarity
(withdraw-milestone-funds campaign-id milestone-id)
```

#### `close-campaign`
Close a campaign (owner only)
```clarity
(close-campaign campaign-id)
```

#### `refund-donation`
Request refund for closed incomplete campaigns
```clarity
(refund-donation campaign-id)
```

### Read-Only Functions

#### `get-campaign`
Get campaign details
```clarity
(get-campaign campaign-id)
```

#### `get-milestone`
Get milestone information
```clarity
(get-milestone campaign-id milestone-id)
```

#### `get-donation`
Get donation details for a specific donor
```clarity
(get-donation campaign-id donor)
```

#### `get-campaign-progress`
Get campaign progress percentages
```clarity
(get-campaign-progress campaign-id)
```

#### `is-milestone-exists`
Check if a milestone exists for a campaign
```clarity
(is-milestone-exists campaign-id milestone-id)
```

#### `get-total-campaign-funds`
Get total funds raised for a campaign
```clarity
(get-total-campaign-funds campaign-id)
```

## 🏗️ Usage Examples

### Creating a Campaign
```clarity
(contract-call? .charity-donation-tracker create-campaign 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  "Clean Water for Village"
  "Providing clean water access to rural communities"
  u1000000
  u1000
  u3
)
```

### Adding Milestones
```clarity
(contract-call? .charity-donation-tracker add-milestone u1 u1 "Install water pump" u400000)
(contract-call? .charity-donation-tracker add-milestone u1 u2 "Build distribution system" u400000)
(contract-call? .charity-donation-tracker add-milestone u1 u3 "Community training" u200000)
```

### Making a Donation
```clarity
(contract-call? .charity-donation-tracker donate u1 u50000)
```

### Completing a Milestone
```clarity
(contract-call? .charity-donation-tracker complete-milestone u1 u1)
```

### Withdrawing Funds
```clarity
(contract-call? .charity-donation-tracker withdraw-milestone-funds u1 u1)
```

## 🔐 Security Features

- **Access Control**: Only campaign owners can complete milestones
- **Fund Safety**: Donations held in contract escrow until milestone completion
- **Refund Protection**: Automatic refunds for failed campaigns
- **Double Donation Prevention**: One donation per donor per campaign
- **Deadline Enforcement**: Campaigns automatically close after deadline

## 📊 Data Structures

### Campaign
- Owner, beneficiary, title, description
- Target amount, raised amount
- Milestone tracking and completion status
- Activity status and timestamps

### Milestone
- Description and funding amount
- Completion status and timestamp
- Link to parent campaign

### Donation
- Donor address and amount
- Donation timestamp
- Campaign association

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation
1. Clone this repository
2. Navigate to project directory
3. Run `clarinet check` to validate contract
4. Use `clarinet console` for interactive testing

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy --testnet
```

## 📝 Error Codes

- `u100`: Not authorized
- `u101`: Campaign not found
- `u102`: Insufficient funds
- `u103`: Milestone not completed
- `u104`: Campaign closed
- `u105`: Invalid milestone
- `u106`: Already donated

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the MIT License.

## 🌟 Support

If you find this project helpful, please give it a star! ⭐

---

Built with ❤️ for transparent charity donations on Stacks blockchain
