# GitPivot 

Ethereum application to incentive open-source development in GitHub by opening direct fair payment channels for bounties and indirect payments through tokenization of commits.

## System Features

### Configurable reward modes by project

For a project being accepted by GitPivot it must have a file in root of tree called `.gitpoints` with specifing `user-agent:` to `*` or `GitPivot`.

Example:

```.gitpoints
user-agent: *
commits-reward: words
issues-reward: pulls, comments, commits, reactions
pulls-reward: comments, commits
comments-reward: reactions
reactions-reward: heart, +1 

```

### GitHub User Ethereum Address

To control GitPivot users need to link their GitHub user login to an ethereum address. 
User calls GitPivot and passes his username and the gistid, GitPivot registers users by loading gistid file called `register.txt` under user `login`. This file must contain only the ethereum address who made the register call, starting with `0x`.

### Tokenize project merged contributions

Any repository that enabled commits-rewards will have tokenization enabled of the contributions and a donation bank.

The avaliable modes are `lines` or `words` that respectively mint tokens by added lines or added words.

GitHub Oracle load commits in batches, and accept continue in case of huge commit trees (+4k commits).

### Distribute project donations to contributors

Repositories that enabled tokenizations of contributions also have a DonationBank that can be withdrawn by Project Token Holders in the start of every epoch, called locked period, where trasfers and minting are blocked.

### Reward bounties by contribuion in GitHub Issues.

Issues may be tracked by GitPivot, accept payments, depending on the `.gitpoints` configuration, positively reacted posts and merged pull requests/commits generate points that allow issue contributors to withdraw a fair share of balances related to the issue.

## Network Features

### Code wage contracts

Different types of contracts can be programmed to accept buy of project tokens by a list of allowed users/accounts.

### Code ICO

The initial coin offers may be based on project tokens or use project tokens to mint the developers share.

### Testnet Faucets

The project may be deployed in PoA chains, such Rinkeby and Kovan, and automatically faucet as code wage contract in registered projects to all developers.

### Other

Ethereum network potential still much unexplored and we still don't know all incredible things we can do. The tokens are ERC20 and ERC23 compataible so your project token might even become exchangable in a descentralized trade market.

## Credits

Developed by Ricardo Guilherme Schmidt <3esmit>;

Special thanks to all that made this possible: Status.im, Oraclize, Solidity & Remix team, ParityTech, Kovan, Rinkeby, TheEtherian, Giveth, Ether.camp, Foundation.
