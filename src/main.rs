fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.iter().any(|a| a == "--version" || a == "-V") {
        println!("ke {}", env!("CARGO_PKG_VERSION"));
        return;
    }
    println!("Hello, world!");
}
