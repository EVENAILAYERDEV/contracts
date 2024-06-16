import "./Jetton";

message Mint {
    to: Address;
    amount: Int;
}

contract TestUSDt with Jetton {
    total_supply: Int as coins; 
    mintable: Bool;
    owner: Address;
    content: Cell;

    init(owner: Address, content: Cell) {
        self.total_supply = 0;
        self.content = content;
        self.owner = owner;
        self.mintable = true;
    }

    receive(msg: Mint) {
        let ctx: Context = context();
        // require(ctx.sender == self.owner, "invalid minter!");
        // require(self.mintable, "Not mintable");
        self.mint(msg.to, msg.amount);        
    }
} 