module bounty_contract::bounty {
    use std::string::{String, utf8, append};
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table, add, borrow, borrow_mut, contains, new};
    use aptos_framework::account;
    use aptos_framework::event::{EventHandle, emit_event};
    use std::option::{Option, Self};
    use aptos_framework::signer;


    // Error constants
    const E_NOT_INITIALIZED: u64 = 1;
    const E_ALREADY_INITIALIZED: u64 = 2;
    const E_NOT_CREATOR: u64 = 3;
    const E_INVALID_STATUS: u64 = 4;
    const E_INSUFFICIENT_FUNDS: u64 = 5;
    const E_NOT_WHITELISTED: u64 = 6;
    const E_BOUNTY_NOT_FOUND: u64 = 7;
    const E_NOT_AUTHORIZED: u64 = 8;
    const E_CANDIDATE_ALREADY_ACCEPTED: u64 = 9;
    const E_CANDIDATE_NOT_ACCEPTED: u64 = 10;
    const E_ALREADY_WHITELISTED: u64 = 11;
    const E_PLAYER_ACCOUNT_NOT_EXIST: u64 = 12;
    const E_USERNAME_ALREADY_EXISTS: u64 = 13;


    struct Bounty has copy, key, store {
        id: u64,
        creator: address,
        create_day: u64,
        job_name: String,
        description: String,
        bounty_amount: u64,
        tags: vector<String>,
        deadline: u64,
        skill_level: String,
        skill_expertise: String,
        num_candidates: u64,
        contact_info: String,
        status: String,
        candidate: Option<address>,
        submission: Option<String>,
        whitelisted_candidates: vector<address>,
    }


    struct BountyList has key {
        bounties: Table<u64, Bounty>,
        bounty_count: u64,
        bounty_created_events: EventHandle<BountyCreatedEvent>,
        admin_cap: account::SignerCapability,
    }


    struct BountyCreatedEvent has store, drop {
        creator: address,
        bounty_id: u64,
        job_name: String,
        bounty_amount: u64,
    }


    struct CandidateInfo has drop, store {
        address: address,
        username: String,
    }


    struct PlayerAccount has key, store, copy, drop {
        name: String,
        username: String,
        user_image: String,
        address_id: address,
        points: u64,
        bounties_created: u64,
        bounties_completed: u64,
    }


    struct PlayerAccounts has key {
        accounts: vector<PlayerAccount>,
    }


    const DEFAULT_NAME: vector<u8> = b"No_name";
    const DEFAULT_IMG_LINK: vector<u8> = b"https://example.com/default.jpg";


    // Initialize the contract
    fun init_module(admin: &signer) {
        let admin_address = signer::address_of(admin);
        assert!(admin_address == @bounty_contract, E_NOT_AUTHORIZED);


        let event_handle = account::new_event_handle<BountyCreatedEvent>(admin);
        
        let (admin_signer, admin_cap) = account::create_resource_account(admin, b"ADMIN_RESOURCE_ACCOUNT");
        let state = BountyList {
            bounties: new(),
            bounty_count: 0,
            bounty_created_events: event_handle,
            admin_cap,
        };


        move_to(admin, state);
    }


    public fun create_account(signer: &signer) acquires PlayerAccounts {
        let account_address = signer::address_of(signer);
        let current_time = timestamp::now_microseconds();
        let unique_username = utf8(b"NoName");
        append(&mut unique_username, u64_to_string(current_time));


        let player_account = PlayerAccount {
            name: utf8(DEFAULT_NAME),
            username: unique_username,
            user_image: utf8(DEFAULT_IMG_LINK),
            address_id: account_address,
            points: 0,
            bounties_created: 0,
            bounties_completed: 0,
        };


        move_to(signer, player_account);


        let player_accounts = borrow_global_mut<PlayerAccounts>(@bounty_contract);
        vector::push_back(&mut player_accounts.accounts, player_account);
    }


    public entry fun create_bounty(
        creator: &signer,
        job_name: String,
        description: String,
        bounty_amount: u64,
        tags: vector<String>,
        deadline: u64,
        skill_level: String,
        skill_expertise: String,
        num_candidates: u64,
        contact_info: String
    ) acquires BountyList {
        let creator_addr = signer::address_of(creator);
        let state = borrow_global_mut<BountyList>(@bounty_contract);
        let bounty_id = state.bounty_count + 1;


        let new_bounty = Bounty {
            id: bounty_id,
            creator: creator_addr,
            create_day: timestamp::now_seconds(),
            job_name,
            description,
            bounty_amount,
            tags,
            deadline,
            skill_level,
            skill_expertise,
            num_candidates,
            contact_info,
            status: utf8(b"Open"),
            candidate: option::none(),
            submission: option::none(),
            whitelisted_candidates: vector::empty(),
        };


        coin::transfer<AptosCoin>(creator, @bounty_contract, bounty_amount);
        add(&mut state.bounties, bounty_id, new_bounty);
        state.bounty_count = bounty_id;


        let event = BountyCreatedEvent {
            creator: creator_addr,
            bounty_id,
            job_name,
            bounty_amount,
        };
        emit_event(&mut state.bounty_created_events, event);
    }


    public entry fun add_whitelisted_candidate(creator: &signer, bounty_id: u64, candidate: address) acquires BountyList {
        let creator_addr = signer::address_of(creator);
        let state = borrow_global_mut<BountyList>(@bounty_contract);
        let bounty = borrow_mut(&mut state.bounties, bounty_id);


        assert!(bounty.creator == creator_addr, E_NOT_CREATOR);
        assert!(bounty.status == utf8(b"Open"), E_INVALID_STATUS);



        vector::push_back(&mut bounty.whitelisted_candidates, candidate);
    }


    public entry fun apply_bounty(candidate: &signer, bounty_id: u64) acquires BountyList {
        let candidate_addr = signer::address_of(candidate);
        let state = borrow_global_mut<BountyList>(@bounty_contract);
        assert!(contains(&state.bounties, bounty_id), E_BOUNTY_NOT_FOUND);
        
        let bounty = borrow_mut(&mut state.bounties, bounty_id);
        assert!(bounty.status == utf8(b"Open"), E_INVALID_STATUS);
        
        // Check if the candidate is already whitelisted
        assert!(!vector::contains(&bounty.whitelisted_candidates, &candidate_addr), E_ALREADY_WHITELISTED);
        
        // Add the candidate to the whitelist
        vector::push_back(&mut bounty.whitelisted_candidates, candidate_addr);
    }


public entry fun submit_bounty(candidate: &signer, bounty_id: u64, submission: String) acquires BountyList {
        let candidate_addr = signer::address_of(candidate);
        let state = borrow_global_mut<BountyList>(@bounty_contract);
        let bounty = borrow_mut(&mut state.bounties, bounty_id);


        assert!(vector::contains(&bounty.whitelisted_candidates, &candidate_addr), E_NOT_WHITELISTED);
        assert!(bounty.status == utf8(b"In Progress"), E_INVALID_STATUS);
        assert!(option::contains(&bounty.candidate, &candidate_addr), E_CANDIDATE_NOT_ACCEPTED);


        bounty.status = utf8(b"Submitted");
        bounty.submission = option::some(submission);
    }



public entry fun accept_candidate(creator: &signer, bounty_id: u64, candidate: address) acquires BountyList {
        let creator_addr = signer::address_of(creator);
        let state = borrow_global_mut<BountyList>(@bounty_contract);
        let bounty = borrow_mut(&mut state.bounties, bounty_id);


        assert!(bounty.creator == creator_addr, E_NOT_CREATOR);
        assert!(bounty.status == utf8(b"Open"), E_INVALID_STATUS);
        assert!(vector::contains(&bounty.whitelisted_candidates, &candidate), E_NOT_WHITELISTED);


        bounty.status = utf8(b"In Progress");
        bounty.candidate = option::some(candidate);
    }


    public entry fun accept_submission(creator: &signer, bounty_id: u64) acquires BountyList {
        let creator_addr = signer::address_of(creator);
        let state = borrow_global_mut<BountyList>(@bounty_contract);
        let bounty = borrow_mut(&mut state.bounties, bounty_id);


        assert!(bounty.creator == creator_addr, E_NOT_CREATOR);
        assert!(bounty.status == utf8(b"Submitted"), E_INVALID_STATUS);


        bounty.status = utf8(b"Completed");
        let candidate = *option::borrow(&bounty.candidate);
        coin::transfer<AptosCoin>(creator, candidate, bounty.bounty_amount);
    }


    // Function to update player profile
    public entry fun update_profile(
        signer: &signer,
        new_name: String,
        new_username: String,
        new_user_image: String
    ) acquires PlayerAccount, PlayerAccounts {
        let account_address = signer::address_of(signer);
        assert!(exists<PlayerAccount>(account_address), E_PLAYER_ACCOUNT_NOT_EXIST);


        // Check if the new username is already taken
        assert!(!is_username_taken(new_username), E_USERNAME_ALREADY_EXISTS);


        let player_account = borrow_global_mut<PlayerAccount>(account_address);
        player_account.name = new_name;
        player_account.username = new_username;
        player_account.user_image = new_user_image;


        // Update the account in the global list
        let player_accounts = borrow_global_mut<PlayerAccounts>(@bounty_contract);
        let i = 0;
        let len = vector::length(&player_accounts.accounts);
        while (i < len) {
            let account = vector::borrow_mut(&mut player_accounts.accounts, i);
            if (account.address_id == account_address) {
                *account = *player_account;
                break
            };
            i = i + 1;
        };
    }


        // View functions


    #[view]
    public fun get_all_bounties(): vector<Bounty> acquires BountyList {
        let state = borrow_global<BountyList>(@bounty_contract);
        let bounties = vector::empty<Bounty>();
        let i = 1;
        while (i <= state.bounty_count) {
            if (contains(&state.bounties, i)) {
                let bounty = borrow(&state.bounties, i);
                vector::push_back(&mut bounties, *bounty);
            };
            i = i + 1;
        };
        bounties
    }


    #[view]
    public fun get_bounty_detail(bounty_id: u64): Bounty acquires BountyList {
        let state = borrow_global<BountyList>(@bounty_contract);
        assert!(contains(&state.bounties, bounty_id), E_BOUNTY_NOT_FOUND);
        *borrow(&state.bounties, bounty_id)
    }


    #[view]
    public fun get_open_bounties(): vector<Bounty> acquires BountyList {
        let state = borrow_global<BountyList>(@bounty_contract);
        let open_bounties = vector::empty<Bounty>();
        let i = 1;
        while (i <= state.bounty_count) {
            if (contains(&state.bounties, i)) {
                let bounty = borrow(&state.bounties, i);
                if (bounty.status == utf8(b"Open")) {
                    vector::push_back(&mut open_bounties, *bounty);
                };
            };
            i = i + 1;
        };
        open_bounties
    }


    #[view]
    public fun get_candidate_info(bounty_id: u64): Option<CandidateInfo> acquires BountyList {
        let state = borrow_global<BountyList>(@bounty_contract);
        assert!(contains(&state.bounties, bounty_id), E_BOUNTY_NOT_FOUND);
        let bounty = borrow(&state.bounties, bounty_id);
        
        if (option::is_some(&bounty.candidate)) {
            let candidate_addr = *option::borrow(&bounty.candidate);
            option::some(CandidateInfo {
                address: candidate_addr,
                username: get_username(candidate_addr),
            })
        } else {
            option::none()
        }
    }


    // View function to get player profile
    #[view]
    public fun get_player_profile(player_address: address): PlayerAccount acquires PlayerAccount {
        assert!(exists<PlayerAccount>(player_address), E_PLAYER_ACCOUNT_NOT_EXIST);
        *borrow_global<PlayerAccount>(player_address)
    }


    #[view]
    public fun is_username_taken(username: String): bool acquires PlayerAccounts {
        let player_accounts = borrow_global<PlayerAccounts>(@bounty_contract);
        let accounts = &player_accounts.accounts;
        let len = vector::length(accounts);
        let i = 0;
        
        while (i < len) {
            let account = vector::borrow(accounts, i);
            if (account.username == username) {
                return true
            };
            i = i + 1;
        };
        
        false
    }


    // Helper functions


    fun u64_to_string(value: u64): String {
        if (value == 0) {
            return utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            let digit = ((value % 10) as u8) + 48;
            vector::push_back(&mut buffer, digit);
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        utf8(buffer)
    }


    fun get_username(address: address): String {
        // Implement the logic to get the username from the address
        // This is a placeholder implementation
        utf8(b"username_placeholder")
    }
}
