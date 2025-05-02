use starknet::{ContractAddress, get_caller_address, get_block_timestamp, contract_address_const};

use dojo::model::{ModelStorage};
use dojo::event::EventStorage;


use dojo_starter::interfaces::ISnooknet::ISnooknet;
use dojo_starter::model::game_model::{Game, GameTrait, GameState, GameCounter, PlayerRating};
use dojo_starter::model::tournament_model::{
    Tournament as TournamentModel, TournamentTrait, TournamentStatus, TournamentReward,
    TournamentCounter,
};
use dojo_starter::model::player_model::{Player, PlayerTrait};


// dojo decorator
#[dojo::contract]
pub mod Snooknet {
    use super::{ISnooknet, Game, GameTrait, GameCounter, GameState, PlayerRating};
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, contract_address_const,
    };
    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;
    use super::*;

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct PlayerCreated {
        #[key]
        pub player: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct RatingUpdated {
        #[key]
        pub player: ContractAddress,
        pub new_rating: u32,
    }


    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct GameCreated {
        #[key]
        pub game_id: u256,
        pub timestamp: u64,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct GameEnded {
        #[key]
        pub game_id: u256,
        pub timestamp: u64,
    }

    #[derive(Copy, Drop, Serde)]
    #[dojo::event]
    pub struct Winner {
        #[key]
        pub game_id: u256,
        pub winner: ContractAddress,
    }

    #[dojo::event]
    #[derive(Copy, Drop, Serde)]
    pub struct TournamentCreated {
        #[key]
        tournament_id: u256,
        name: felt252,
        organizer: ContractAddress,
        start_date: u64,
        end_date: u64,
    }

    #[dojo::event]
    #[derive(Copy, Drop, Serde)]
    pub struct TournamentJoined {
        #[key]
        tournament_id: u256,
        player: ContractAddress,
    }

    #[dojo::event]
    #[derive(Copy, Drop, Serde)]
    pub struct TournamentEnded {
        #[key]
        tournament_id: u256,
        end_date: u64,
    }


    #[abi(embed_v0)]
    impl SnooknetImpl of ISnooknet<ContractState> {
        fn create_player(ref self: ContractState) {
            let mut world = self.world_default();

            let caller: ContractAddress = get_caller_address();

            let new_player: Player = PlayerTrait::new(caller, 0, 0, 0, 0, 0, 0, 1);

            world.write_model(@new_player);

            world.emit_event(@PlayerCreated { player: caller, timestamp: get_block_timestamp() });
        }

        fn create_new_game_id(ref self: ContractState) -> u256 {
            let mut world = self.world_default();
            let mut game_counter: GameCounter = world.read_model('v0');
            let new_val = game_counter.current_val + 1;
            game_counter.current_val = new_val;
            world.write_model(@game_counter);
            new_val
        }

        fn create_match(
            ref self: ContractState, opponent: ContractAddress, stake_amount: u256,
        ) -> u256 {
            let mut world = self.world_default();
            let game_id = self.create_new_game_id();
            let timestamp = get_block_timestamp();
            let player_1 = get_caller_address();
            let player_2 = opponent;

            // Initialize ratings for players if they don't exist
            self.ensure_player_rating(player_1);
            self.ensure_player_rating(player_2);

            // Create a new game
            let mut new_game: Game = GameTrait::new(
                game_id,
                player_1,
                player_2,
                player_1,
                red_balls_remaining: 13,
                state: GameState::NotStarted,
                winner: contract_address_const::<0x0>(),
                created_at: timestamp,
                updated_at: timestamp,
                stake_amount: stake_amount,
            );

            world.write_model(@new_game);

            world.emit_event(@GameCreated { game_id, timestamp });

            game_id
        }

        fn end_match(ref self: ContractState, game_id: u256, winner: ContractAddress) {
            let mut world = self.world_default();
            let mut game: Game = world.read_model(game_id);
            let caller = get_caller_address();

            let timestamp = get_block_timestamp();

            assert((caller == game.player1) || (caller == game.player2), 'Not a Player');

            assert(
                (winner == game.player1)
                    || (winner == game.player2)
                    || (winner == contract_address_const::<0x0>()),
                'Invalid winner',
            );

            // Ensure game is not already finished
            assert(game.state != GameState::Finished, 'Game already ended');

            game.winner = winner;
            game.state = GameState::Finished;
            game.updated_at = get_block_timestamp();

            // Update player ratings using Elo algorithm
            if winner != contract_address_const::<0x0>() {
                // Not a draw
                let (new_rating1, new_rating2) = self
                    .elo_function(game.player1, game.player2, winner);
                let mut rating1: PlayerRating = world.read_model(game.player1);
                let mut rating2: PlayerRating = world.read_model(game.player2);
                rating1.rating = new_rating1;
                rating2.rating = new_rating2;
                world.write_model(@rating1);
                world.write_model(@rating2);
                world.emit_event(@RatingUpdated { player: game.player1, new_rating: new_rating1 });
                world.emit_event(@RatingUpdated { player: game.player2, new_rating: new_rating2 });
            } else {
                // Draw: both players get 0.5 score
                let (new_rating1, new_rating2) = self.elo_function_draw(game.player1, game.player2);
                let mut rating1: PlayerRating = world.read_model(game.player1);
                let mut rating2: PlayerRating = world.read_model(game.player2);
                rating1.rating = new_rating1;
                rating2.rating = new_rating2;
                world.write_model(@rating1);
                world.write_model(@rating2);
                world.emit_event(@RatingUpdated { player: game.player1, new_rating: new_rating1 });
                world.emit_event(@RatingUpdated { player: game.player2, new_rating: new_rating2 });
            }

            world.write_model(@game);
            world.emit_event(@Winner { game_id, winner });
            world.emit_event(@GameEnded { game_id, timestamp });
        }

        fn retrieve_game(ref self: ContractState, game_id: u256) -> Game {
            // Get default world
            let mut world = self.world_default();
            //get the game state
            let game: Game = world.read_model(game_id);
            game
        }

        fn create_tournament(
            ref self: ContractState,
            name: felt252,
            max_players: u8,
            start_date: u64,
            end_date: u64,
            rewards: Array<TournamentReward>,
        ) -> u256 {
            let mut world = self.world_default();
            let tournament_id = self.create_new_tournament_id();

            // Validate input parameters
            assert(max_players > 1, 'Max players less than 2');
            assert(start_date < end_date, 'Invalid start date');

            let caller = get_caller_address();

            // Create new tournament
            let mut new_tournament: TournamentModel = TournamentTrait::new(
                tournament_id, name, caller, max_players, start_date, end_date, rewards,
            );

            world.write_model(@new_tournament);

            world
                .emit_event(
                    @TournamentCreated {
                        tournament_id, name, organizer: caller, start_date, end_date,
                    },
                );

            tournament_id
        }

        fn join_tournament(ref self: ContractState, tournament_id: u256) {
            // Get the caller's address
            let caller = get_caller_address();

            let mut world = self.world_default();
            let mut tournament: TournamentModel = world.read_model(tournament_id);

            // Check if tournament is open for joining
            assert(tournament.status == TournamentStatus::Pending, 'Tournament not open');

            // Check if tournament is full
            assert(tournament.current_players < tournament.max_players, 'Tournament is full');

            // Update tournament with new players array
            tournament.current_players += 1;

            // Store updated tournament
            world.write_model(@tournament);

            // Emit event
            world.emit_event(@TournamentJoined { tournament_id, player: caller });
        }

        fn end_tournament(ref self: ContractState, tournament_id: u256) {
            let mut world = self.world_default();
            let mut tournament: TournamentModel = world.read_model(tournament_id);

            // Check if tournament is in progress
            assert(
                tournament.status == TournamentStatus::Pending
                    || tournament.status == TournamentStatus::Active,
                'Tournament is not in progress',
            );

            // Update tournament status and timestamp
            tournament.status = TournamentStatus::Ended;
            tournament.end_date = get_block_timestamp();

            // Store updated tournament
            world.write_model(@tournament);

            world.emit_event(@TournamentEnded { tournament_id, end_date: tournament.end_date });
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        // Use the default namespace "dojo_starter".
        // This function is handy since the ByteArray can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"Snooknet")
        }

        fn ensure_player_rating(ref self: ContractState, player: ContractAddress) {
            let mut world = self.world_default();
            let mut rating: PlayerRating = world.read_model(player);
            if rating.rating == 0 {
                rating.rating = 1500;
                world.write_model(@rating);
            }
        }

        // Elo function for win/loss
        fn elo_function(
            ref self: ContractState,
            player1: ContractAddress,
            player2: ContractAddress,
            winner: ContractAddress,
        ) -> (u32, u32) {
            let mut world = self.world_default();
            let rating1: PlayerRating = world.read_model(player1);
            let rating2: PlayerRating = world.read_model(player2);
            let r1 = rating1.rating; // u32
            let r2 = rating2.rating; // u32
            let k = 32_u32; // Elo K-factor

            // Calculate expected scores (scaled 0 to 1000)
            let expected1 = self.calculate_expected(r1, r2); // u32
            let expected2 = self.calculate_expected(r2, r1); // u32

            // Assign scores based on winner
            let (score1, score2) = if winner == player1 {
                (1000_u32, 0_u32)
            } else {
                (0_u32, 1000_u32)
            };

            // Calculate rating changes safely
            let new_rating1 = if score1 >= expected1 {
                // Positive or zero change (e.g., winner)
                let delta = (score1 - expected1) * k / 1000;
                r1 + delta
            } else {
                // Negative change (e.g., loser)
                let delta = self.safe_subtract(expected1, score1) * k / 1000;
                let min_rating = 100_u32; // Minimum rating to prevent too-low values
                if r1 <= delta {
                    min_rating
                } else {
                    r1 - delta
                }
            };

            let new_rating2 = if score2 >= expected2 {
                // Positive or zero change
                let delta = (score2 - expected2) * k / 1000;
                r2 + delta
            } else {
                // Negative change
                let delta = self.safe_subtract(expected2, score2) * k / 1000;
                let min_rating = 100_u32;
                if r2 <= delta {
                    min_rating
                } else {
                    r2 - delta
                }
            };

            (new_rating1, new_rating2)
        }

        // Elo function for draw
        fn elo_function_draw(
            ref self: ContractState, player1: ContractAddress, player2: ContractAddress,
        ) -> (u32, u32) {
            let mut world = self.world_default();
            let rating1: PlayerRating = world.read_model(player1);
            let rating2: PlayerRating = world.read_model(player2);
            let r1 = rating1.rating;
            let r2 = rating2.rating;
            let k = 32_u32;

            let expected1 = self.calculate_expected(r1, r2);
            let expected2 = self.calculate_expected(r2, r1);
            let score = 500_u32; // Draw score (scaled)

            let new_rating1 = if score >= expected1 {
                let delta = (score - expected1) * k / 1000;
                r1 + delta
            } else {
                let delta = self.safe_subtract(expected1, score) * k / 1000;
                let min_rating = 100_u32;
                if r1 <= delta {
                    min_rating
                } else {
                    r1 - delta
                }
            };

            let new_rating2 = if score >= expected2 {
                let delta = (score - expected2) * k / 1000;
                r2 + delta
            } else {
                let delta = self.safe_subtract(expected2, score) * k / 1000;
                let min_rating = 100_u32;
                if r2 <= delta {
                    min_rating
                } else {
                    r2 - delta
                }
            };

            (new_rating1, new_rating2)
        }

        // Helper function to calculate expected score
        fn calculate_expected(self: @ContractState, r1: u32, r2: u32) -> u32 {
            if r1 > r2 {
                let diff = r1 - r2;
                if diff > 400 {
                    1000_u32
                } else {
                    500_u32 + (diff * 5) / 4
                }
            } else {
                let diff = r2 - r1;
                if diff > 400 {
                    0_u32
                } else {
                    500_u32 - (diff * 5) / 4
                }
            }
        }

        fn safe_subtract(self: @ContractState, a: u32, b: u32) -> u32 {
            if a >= b {
                a - b
            } else {
                0_u32
            }
        }

        fn create_new_tournament_id(ref self: ContractState) -> u256 {
            let mut world = self.world_default();
            let mut tournament_counter: TournamentCounter = world.read_model('v0');
            let new_val = tournament_counter.current_val + 1;
            tournament_counter.current_val = new_val;
            world.write_model(@tournament_counter);
            new_val
        }
    }
}


