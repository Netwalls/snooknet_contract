#[cfg(test)]
mod tests {
    use starknet::contract_address::contract_address_const;
    use starknet::testing::set_contract_address;

    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };

    use dojo_starter::systems::Snooknet::{Snooknet};
    use dojo_starter::interfaces::ISnooknet::{ISnooknetDispatcher, ISnooknetDispatcherTrait};
    use dojo_starter::model::tournament_model::{TournamentStatus, TournamentReward, Tournament};

    use dojo_starter::model::game_model::{
        Game, m_Game, GameState, GameCounter, m_GameCounter, PlayerRating, m_PlayerRating,
    };
    use starknet::{testing, get_caller_address, contract_address_const};
    use dojo_starter::model::tournament_model::{m_Tournament, m_TournamentCounter};
    use dojo_starter::model::player_model::{m_Player};

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "Snooknet",
            resources: [
                TestResource::Model(m_GameCounter::TEST_CLASS_HASH),
                TestResource::Model(m_Game::TEST_CLASS_HASH),
                TestResource::Model(m_PlayerRating::TEST_CLASS_HASH),
                TestResource::Event(Snooknet::e_RatingUpdated::TEST_CLASS_HASH),
                TestResource::Event(Snooknet::e_GameCreated::TEST_CLASS_HASH),
                TestResource::Event(Snooknet::e_Winner::TEST_CLASS_HASH),
                TestResource::Event(Snooknet::e_GameEnded::TEST_CLASS_HASH),
                TestResource::Model(m_TournamentCounter::TEST_CLASS_HASH),
                TestResource::Model(m_Tournament::TEST_CLASS_HASH),
                TestResource::Event(Snooknet::e_TournamentCreated::TEST_CLASS_HASH),
                TestResource::Event(Snooknet::e_TournamentJoined::TEST_CLASS_HASH),
                TestResource::Event(Snooknet::e_TournamentEnded::TEST_CLASS_HASH),
                TestResource::Model(m_Player::TEST_CLASS_HASH),
                TestResource::Event(Snooknet::e_PlayerCreated::TEST_CLASS_HASH),
                TestResource::Contract(Snooknet::TEST_CLASS_HASH),
            ]
                .span(),
        };

        ndef
    }

    fn contract_defs() -> Span<ContractDef> {
        [
            ContractDefTrait::new(@"Snooknet", @"Snooknet")
                .with_writer_of([dojo::utils::bytearray_hash(@"Snooknet")].span())
        ]
            .span()
    }

    #[test]
    fn test_create_game() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        set_contract_address(caller_1);

        let game_id = actions_system.create_match(player_1, 400);
        assert(game_id == 1, 'Wrong game id');
        println!("game_id: {}", game_id);
    }

    #[test]
    fn test_create_game_two_games() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();
        let player = contract_address_const::<'playeriw'>();
        let opponent = contract_address_const::<'opponent'>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        set_contract_address(caller_1);

        let game_id = actions_system.create_match(player_1, 400);

        set_contract_address(player);
        let game_id_1 = actions_system.create_match(opponent, 1000);
        assert(game_id_1 == 2, 'Wrong game id');
        println!("game_id: {}", game_id);
    }

    #[test]
    fn test_end_game() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        set_contract_address(caller_1);
        let game_id = actions_system.create_match(player_1, 400);

        set_contract_address(caller_1);
        actions_system.end_match(game_id, caller_1);

        set_contract_address(caller_1);
        let game = actions_system.retrieve_game(game_id);

        assert(game.winner == caller_1, 'Winner not set correctly');
        assert(game.state == GameState::Finished, 'Game not ended');
    }

    #[test]
    #[should_panic]
    fn test_non_participant_end_game() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();
        let player = contract_address_const::<'pla'>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        set_contract_address(caller_1);
        let game_id = actions_system.create_match(player_1, 400);

        set_contract_address(player);
        actions_system.end_match(game_id, caller_1);

        set_contract_address(caller_1);
        let game = actions_system.retrieve_game(game_id);

        assert(game.winner == caller_1, 'Winner not set correctly');
        assert(game.state == GameState::Finished, 'Game not ended');
    }

    // New test: Verify player rating initialization
    #[test]
    fn test_player_rating_initialization() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();
    }

    #[test]
    fn test_create_tournament() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        testing::set_contract_address(caller_1);
        let game_id = actions_system.create_match(player_1, 400);

        let rating1: PlayerRating = world.read_model(caller_1);
        let rating2: PlayerRating = world.read_model(player_1);
        assert(rating1.rating == 1500, 'Player 1 rating not initialized');
        assert(rating2.rating == 1500, 'Player 2 rating not initialized');
    }

    // New test: Verify rating update after a win
    #[test]
    fn test_rating_update_after_win() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();

        let organizer = contract_address_const::<'organizer'>();
        set_contract_address(organizer);

        let name = 'Test Tournament';
        let max_players = 8_u8;
        let start_date = 1000_u64;
        let end_date = 2000_u64;

        let mut rewards = ArrayTrait::new();
        rewards.append(TournamentReward { position: 1_u8, amount: 1000_u256, token_type: 'ETH' });
        rewards.append(TournamentReward { position: 2_u8, amount: 500_u256, token_type: 'ETH' });
        rewards.append(TournamentReward { position: 3_u8, amount: 250_u256, token_type: 'ETH' });

        let tournament_id = actions_system
            .create_tournament(name, max_players, start_date, end_date, rewards);

        let tournament: Tournament = world.read_model(tournament_id);

        assert(tournament.name == name, 'Name mismatch');
        assert(tournament.max_players == max_players, 'Max players mismatch');
        assert(tournament.start_date == start_date, 'Start date mismatch');
        assert(tournament.end_date == end_date, 'End date mismatch');
        assert(tournament.status == TournamentStatus::Pending, 'Status should be Pending');
        assert(tournament.rewards.len() == 3, 'Rewards length mismatch');
    }

    #[test]
    fn test_join_tournament() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        testing::set_contract_address(caller_1);
        let game_id = actions_system.create_match(player_1, 400);

        testing::set_contract_address(caller_1);
        actions_system.end_match(game_id, caller_1);

        let rating1: PlayerRating = world.read_model(caller_1);
        let rating2: PlayerRating = world.read_model(player_1);
        assert(rating1.rating > 1500, 'Winner rating not increased');
        assert(rating2.rating < 1500, 'Loser rating not decreased');
    }

    // New test: Verify rating update after a draw
    #[test]
    fn test_rating_update_after_draw() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();

        let organizer = contract_address_const::<'organizer'>();
        set_contract_address(organizer);

        let name = 'Test Tournament';
        let max_players = 8_u8;
        let start_date = 1000_u64;
        let end_date = 2000_u64;

        let mut rewards = ArrayTrait::new();
        rewards.append(TournamentReward { position: 1_u8, amount: 1000_u256, token_type: 'ETH' });
        rewards.append(TournamentReward { position: 2_u8, amount: 500_u256, token_type: 'ETH' });
        rewards.append(TournamentReward { position: 3_u8, amount: 250_u256, token_type: 'ETH' });

        let tournament_id = actions_system
            .create_tournament(name, max_players, start_date, end_date, rewards);

        // Create a player
        let player_address = contract_address_const::<'player'>();
        set_contract_address(player_address);

        actions_system.create_player();
        // Join tournament
        actions_system.join_tournament(tournament_id);

        let tournament: Tournament = world.read_model(tournament_id);
        assert(tournament.current_players == 1, 'Player should be added');
    }

    #[test]
    fn test_end_tournament() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        testing::set_contract_address(caller_1);
        let game_id = actions_system.create_match(player_1, 400);

        testing::set_contract_address(caller_1);
        actions_system
            .end_match(game_id, contract_address_const::<0x0>()); // Zero address indicates draw

        let rating1: PlayerRating = world.read_model(caller_1);
        let rating2: PlayerRating = world.read_model(player_1);
        assert(rating1.rating == 1500, 'Player 1 rating changed in draw');
        assert(rating2.rating == 1500, 'Player 2 rating changed in draw');
    }

    // New test: Ending an already ended game should panic
    #[test]
    #[should_panic]
    fn test_end_game_already_ended() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        testing::set_contract_address(caller_1);
        let game_id = actions_system.create_match(player_1, 400);

        testing::set_contract_address(caller_1);
        actions_system.end_match(game_id, caller_1);

        // Attempt to end the game again
        actions_system.end_match(game_id, caller_1);
    }

    // New test: Ending a game with an invalid winner should panic
    #[test]
    #[should_panic]
    fn test_invalid_winner() {
        let caller_1 = contract_address_const::<'aji'>();
        let player_1 = contract_address_const::<'player'>();
        let invalid_winner = contract_address_const::<'invalid'>();

        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());
        world.sync_perms_and_inits(contract_defs());

        let (contract_address, _) = world.dns(@"Snooknet").unwrap();
        let actions_system = ISnooknetDispatcher { contract_address };

        testing::set_contract_address(caller_1);
        let game_id = actions_system.create_match(player_1, 400);

        testing::set_contract_address(caller_1);
        actions_system.end_match(game_id, invalid_winner);
        let organizer = contract_address_const::<'organizer'>();
        set_contract_address(organizer);

        let name = 'Test Tournament';
        let max_players = 8_u8;
        let start_date = 1000_u64;
        let end_date = 2000_u64;

        let mut rewards = ArrayTrait::new();
        rewards.append(TournamentReward { position: 1_u8, amount: 1000_u256, token_type: 'ETH' });
        rewards.append(TournamentReward { position: 2_u8, amount: 500_u256, token_type: 'ETH' });
        rewards.append(TournamentReward { position: 3_u8, amount: 250_u256, token_type: 'ETH' });

        let tournament_id = actions_system
            .create_tournament(name, max_players, start_date, end_date, rewards);

        // End tournament
        actions_system.end_tournament(tournament_id);

        let tournament: Tournament = world.read_model(tournament_id);
        assert(tournament.status == TournamentStatus::Ended, 'Tournament should be ended');
    }
}
