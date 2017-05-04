# GitHubOracle 
Tokenize github repositories by commits and issues. Accept donations in eth tokens, distribute donations and bounties to code commiters.
 
## Usage 
  
## User Registration
Create a gist in your github containing in it's body only an ethereum address you own.   
Must be in first line with no spaces and no more lines.    
Call `DGit.register("<your_github_login>","<your gistid>")`  (oracle cost ~0.06 USD)  
Example: `DGit.register("3esmit","31a58f2ddf2258697cce1b969e7c298b")`   
 
## Repository    
Call `DGit.addRepository("<owner>/<repository>")`  (oracle cost ~0.06 USD)  
Example:  `DGit.addRepository("status-im/github-oracle")`    
 
### Tokenize Contributions   
Push your commits to GitHub and simply call `DGit.updateCommits("<owner>/<repository>")`    
This call will cost $0.54 USD and can process up to 4000 commits.   
Call `DGit.continueCommits("<owner>/<repository>")` (oracle cost ~0.54 USD)  
Example: `DGit.updateCommits("status-im/github-oracle")`    

### Bounty issue
When you start an issue at GitHub, you can bounty it. First you need to open it:   
Call `DGit.openBounty("<owner>/<repository>",<issuenum>)` (oracle cost ~0.06 USD)       
This will enable people to bounty into this issue, this call can contain itself a bounty to be added. 
When issue is finalized call `DGit.updateIssue("<owner>/<repository>",<issuenum>)` (oracle cost ~0.54 USD)  
This will tokenize the commits of pull requests cross-referenced with this issue and, after a lock period, distribute a fair share of bounty between contributors.    
 
### Withdraw donations   
When contract enters in lock period just call `GitHubToken.withdraw()` to get your share of the donations.  
