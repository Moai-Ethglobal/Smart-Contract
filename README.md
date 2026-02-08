MOAI


MoaiFactory deployed at: 0x5143cbB43ba26b57dF3F5F8Dd95C702c81b9531F https://testnet.arcscan.app/address/0x5143cbB43ba26b57dF3F5F8Dd95C702c81b9531F?tab=index
Moai deployed at: 0xD3d49D38dd4aa792f7ad124016D652521312a5C0 https://testnet.arcscan.app/address/0x5143cbB43ba26b57dF3F5F8Dd95C702c81b9531F?tab=contract

Friends form savings circles with shared emergency reserves for financial and emotional support.
A moai is a group of individulas who trust each other and share liflong bonds that helps them feel connected, battling loneliness and financial hardships throughout their oldage.

The concept has been in practice for decades in okinawa,Japan contibuting to the longevity of people in the region. A variation of this can also be found in the villages of tamil nadu known as Women self help group.

Key Features:
🔄 Automated Round-Robin - Fair distribution system
💰 Emergency Reserve - 30% pooled for member emergencies
🗳️ Democratic Governance - 51% voting on all decisions by all members
🔒 Trustless - Smart contracts enforce all rules
📊 Transparent - All transactions on-chain

Anyone can create a group(called a moai).They send out invites over email or share the link to join. A member can join via an invite link. Each member can only be part of one group with each moai having a maximum of 5 to 10 members.

Groups of up to 10 members pool USDC contributions monthly on the ARC blockchain and take turns receiving distributions through a fair round-robin system, while building a collective emergency fund. Every month, each member pays a fixed amount before a set date of the month. 70% of this monthly fund is distributed to one of the members and 30% of it is saved to the collective emergency fund. 

A calendar invite is created for every month for all the members to meet on huddle. Only members of the moai are invited,and the moai system enforces participation of all the members.
This continously communication creates a sense of community and builds relationship over decades.

A member can raise an emergency request to withdraw a maximum of 15% from the collective emergency fund. Members collectively vote on change in monthly contribution amount,removal or dissilution of moai,however in practive this scenario is strictly discouraged and almost never happens.
Any amount which was missed can be paid later  incase of unforseen cirumstance agreed upon by all members, which will be added to the emergency pool. They will be able to view their past transactions in their My History.

Moai primarily is for having each other and being a safety net. When a member of the moai has an emergency situation, they can raise a request with the amount they need not exceeding 15% of the emergency pool. Atleast 51% of the members need to approve the request for it to pass through and the amount is passed on to the beneficiary.

This is done on mutual understanding and need basis. Additionally the monthly funds is distrubuted in round robin monthly among the members. The goal is for everyone in the group to eventually receive the pot before the cycle repeats.

A member can leave the moai but will not seek any benefits on doing so. When a member of the moai passes away, any member can submit a register demise and upon approval of the members, the demised member will be removed from the moai.

While this concept has been live with cash and in person meetings, a need for decentralized moai is necessary for a sustainable money and to resolve dispersion of group from the geographic region for various reasons like job, studies etc. 

Moai Dapp has upgraded this with onchain savings and management along with huddle based online meetings.

The goal is not to have the highest yields generated, but to have a backing emotionally and financially, even if small, from the closest friends.

The project is deployed on ARC blockchain with USDC stablecoin contributions for savings. This was beneficial in having a geographically stable currency and easier for transfers among the moai members on-chain due to low volatility.

A contract address is created for each moai and for every member who joins via the invite link.
All the members and the contract of the moai is minted an ENS, for ease of recognition of the names of members, since the majority of current users are expected to be the aged population.

All payers are pooled in the smart contract created for the Moai. During the monthly distribution, according to the round robin, the 70% funds of the months is allocated to a member which can be withdrawn by them anytime. 

The remaining 30% of the funds is stored in the contract to be used only in case of emergencies by the members, which is a withdrawal upto 15% subject to atleast 51% votes. Plan is to keep this emergncy fund in low risk yield generating pool until withdrawn.

Upon dissolution of the moai, the entire balance is split equally among the members.

Architectural WorkFlow:

┌─────────────────────────────────────────────────────────────┐
│                    MONTHLY CYCLE FLOW                        │
└─────────────────────────────────────────────────────────────┘

Day 1-15 (Contribution Period)
│
├─► Members contribute USDC
│   • Each member pays fixed amount
│   • Tracks who has paid this month
│   • Contributions accumulate in pool
│
Day 16 (Distribution Date + 1 day grace)
│
├─► Distribution triggered (if 51%+ paid)
│   ├─► 70% → Allocated to round-robin recipient
│   │         (locked to specific address)
│   │
│   └─► 30% → Added to emergency reserve
│             (available for emergency requests)
│
Day 16+ (Withdrawal Period)
│
├─► Recipient withdraws allocated funds
│   • Can withdraw anytime (no rush)
│   • Funds locked to them specifically
│   • Cannot be claimed by others
│
└─► Cycle advances to Month 2
    • Round-robin index moves to next member
    • Process repeats

Fund Distribution Split

Every 100 USDC contributed:

┌────────────────────────────────────┐
│   TOTAL CONTRIBUTIONS: 100 USDC    │
└────────────────────────────────────┘
            │
            ├─► 70 USDC (70%)
            │   └─► Round-Robin Recipient
            │       • Allocated immediately
            │       • Locked to specific member
            │       • Withdrawable anytime
            │
            └─► 30 USDC (30%)
                └─► Emergency Reserve
                    • Builds over time
                    • Democratic distribution
                    • 51% approval required

Links
- Live demo: [moai-eth.vercel.app](https://moai-eth.vercel.app/)
- Pitch deck: [Canva](https://www.canva.com/design/DAHAvLOEFLU/byHuMAyfZspXW7QwlQGIWw/edit?utm_content=DAHAvLOEFLU&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton)
