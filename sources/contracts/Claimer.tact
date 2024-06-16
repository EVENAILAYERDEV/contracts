import "@stdlib/ownable";
import "./NFT";
import "./Jetton";

message SetAddress {
    usdt_wallet_address: Address?;
    nft_master_address: Address?;
}


contract Claimer with Ownable{
    owner: Address;
    usdt_wallet_address: Address;
    max_claimable_index: Int as uint64 = 0;
    nft_master_address: Address;

    init(owner: Address) {
        self.owner = owner;
        self.usdt_wallet_address = newAddress(0, 0);
        self.nft_master_address = newAddress(0, 0);
    } 

    receive(msg: ClaimNotification) {
        let ctx: Context = context();
        let item_init: StateInit = initOf NftItem(self.nft_master_address, msg.item_index);
        let item_address: Address = contractAddress(item_init);
        require(item_address == ctx.sender, "not the item");
        require(msg.item_index <= self.max_claimable_index, "exceeds the maximum claimable index, can not claim yet");

        send(SendParameters{
            to: self.usdt_wallet_address, 
            value: 0, 
            bounce: true,
            mode: SendRemainingValue,
            body: TokenTransfer {
                query_id: msg.query_id,
                amount: msg.amount,
                destination: msg.to,
                response_destination: msg.to,
                custom_payload: emptyCell(),
                forward_amount: msg.forward_amount,
                forward_payload: msg.forward_payload
                }.toCell()
            });
        
    }

    receive(msg: SetAddress) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not owner");
        if(msg.usdt_wallet_address != null){self.usdt_wallet_address = msg.usdt_wallet_address!!;}
        if(msg.nft_master_address != null){self.nft_master_address = msg.nft_master_address!!;}
    }
}