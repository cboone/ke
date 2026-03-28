use clap::Parser;

/// A developer-focused CLI for ergonomic macOS Keychain access
#[derive(Parser)]
#[command(version)]
struct Cli {}

fn main() {
    let _cli = Cli::parse();
    println!("Hello, world!");
}
