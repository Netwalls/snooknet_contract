use starknet::{ContractAddress, contract_address_const};
// Keeps track of the state of the game

// New PlayerRating model to store player ratings
#[derive(Copy, Drop, Serde, Introspect)]
#[dojo::model]
pub struct PlayerRating {
    #[key]
    pub player: ContractAddress,
    pub rating: u32 // Elo rating
}

// Trait for PlayerRating operations
pub trait PlayerRatingTrait {
    fn new(player: ContractAddress, rating: u32) -> PlayerRating;
}

impl PlayerRatingImpl of PlayerRatingTrait {
    fn new(player: ContractAddress, rating: u32) -> PlayerRating {
        PlayerRating { player, rating }
    }
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
#[dojo::model]
pub struct GameCounter {
    #[key]
    pub id: felt252,
    pub current_val: u256,
}


#[derive(Copy, Drop, Serde, Debug, Introspect, PartialEq)]
pub enum GameState {
    NotStarted,
    InProgress,
    Finished,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
pub struct Game {
    #[key]
    pub id: u256,
    pub player1: ContractAddress,
    pub player2: ContractAddress,
    pub current_turn: ContractAddress,
    pub red_balls_remaining: u8,
    pub state: GameState,
    pub winner: ContractAddress,
    pub created_at: u64,
    pub updated_at: u64,
    pub stake_amount: u256,
}
pub trait GameTrait {
    // Create and return a new game
    fn new(
        id: u256,
        player1: ContractAddress,
        player2: ContractAddress,
        current_turn: ContractAddress,
        red_balls_remaining: u8,
        state: GameState,
        winner: ContractAddress,
        created_at: u64,
        updated_at: u64,
        stake_amount: u256,
    ) -> Game;
}


// Represents the status of the game
// Can either be Ongoing or Ended
#[derive(Serde, Copy, Drop, Introspect, PartialEq, Debug)]
pub enum MatchStatus {
    Pending, // Waiting for players to join (in multiplayer mode)
    Ongoing, // Game is ongoing
    Ended // Game has ended
}


impl GameImpl of GameTrait {
    fn new(
        id: u256,
        player1: ContractAddress,
        player2: ContractAddress,
        current_turn: ContractAddress,
        red_balls_remaining: u8,
        state: GameState,
        winner: ContractAddress,
        created_at: u64,
        updated_at: u64,
        stake_amount: u256,
    ) -> Game {
        let zero_address = contract_address_const::<0x0>();
        Game {
            id,
            player1,
            player2,
            current_turn: zero_address.into(),
            red_balls_remaining,
            state: GameState::NotStarted,
            winner: zero_address.into(),
            created_at,
            updated_at,
            stake_amount,
        }
    }
}

