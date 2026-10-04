mod secrets;

use std::path::PathBuf;

use anyhow::Result;
use clap::{Parser, Subcommand};
use secrets::Repository;

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    Init,
    Onboard {
        device: String,
        public_key: PathBuf,
        scopes: Vec<String>,
    },
    Offboard,
    Edit {
        scope: String,
        name: String,
    },
    Remove,
    Check,
}

fn main() -> Result<()> {
    let command = Cli::parse().command;
    let repository = Repository::discover()?;
    match command {
        Command::Init => repository.init(),
        Command::Onboard {
            device,
            public_key,
            scopes,
        } => repository.onboard(&device, &public_key, &scopes),
        Command::Offboard => repository.offboard(),
        Command::Edit { scope, name } => repository.edit(&scope, &name),
        Command::Remove => repository.remove(),
        Command::Check => repository.check(),
    }
}
