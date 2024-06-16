import "./Jetton";

message Mint {
    to: Address;
    amount: Int;
}

message SetMintable {
    mintable: Bool;
}


contract aiUSDT with Jetton {
    total_supply: Int as coins;
    owner: Address;
    content: Cell;
    mintable: Bool;
    minter: Address;


    init(owner: Address, content: Cell, minter: Address) {
        self.total_supply = 0;
        self.owner = owner;
        self.content = content;
        self.mintable = true;
        self.minter = minter;
    }

    receive(msg: Mint) {
        let ctx: Context = context();
        require(ctx.sender == self.minter, "Not the minter address");
        require(self.mintable, "Not mintable");
        self.mint(msg.to, msg.amount);
    }

    // owner mint for test
    receive("Mint: 1000000") { 
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not owner");
        self.mint(ctx.sender, ton("1000000")); 
    }

    receive(msg: SetMintable) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not owner");
        self.mintable = msg.mintable;
    }
}