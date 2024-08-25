# Smart Contract Specifications
This is Specifications contract!

## Social:

If you have any connect please touch my social:
https://linktr.ee/pichtran

### 1. Involved Actors.

Player: Users who interact with the contract by creating rooms, joining rooms, sending messages, etc.

Creator: The owner or controller of the contract who has special permissions, such as picking a winner and transferring the bet amount.

### 2. Internal Methods:
`create_bounty`: Allows a user to create a new bounty with specific parameters.

`apply_bounty`: Allows a cadidate to join a room by providing the bounty ID.

`accept_candidate`: Accecpt cadidate for user.

`submit_bounty`: Cadidate submit bounty.

`accept_submission`: creator accecpt submit.

`update_account`: Updates a player's account information (name and username).

### 3. External Methods:
#### get_all_bounties: Retrieves all the created bounty.
#### get_open_bounties: Retrieves bounties active.
#### get_player_profile: Get profile by address.
#### is_username_taken: Checks whether a specific username is already taken.
#### get_bounty_detail: Retrieves detailed information for a specific room by bounty ID.

# Table
| Function | Parameters | Description |
|---|---|---|
| `create_bounty` | `&signer`, `0x1::string::String`, `u64`, `u64` | Creates a new bounty with a title, reward amount, and deadline. |
| `apply_bounty` | `&signer`, `u64` | Allows a candidate to join a bounty by providing its ID. |
| `accept_candidate` | `&signer`, `u64`, `address` | Allows the bounty creator to accept a candidate for the bounty. |
| `submit_bounty` | `&signer`, `u64`, `0x1::string::String` | Allows a candidate to submit their bounty solution. |
| `accept_submission` | `&signer`, `u64`, `address` | Allows the bounty creator to accept a submitted solution. |
| `update_account` | `&signer`, `0x1::string::String`, `0x1::string::String` | Updates a player's account information (name and username). |


