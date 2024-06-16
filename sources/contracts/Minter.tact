import "@stdlib/ownable";
import "./aUSDt";
import "./NFT";

message SetAddress {
    usdt_wallet_address: Address?;
    ausdt_wallet_address: Address?;
    asudt_master_address: Address?;
    nft_master_address: Address?;
}

message SetExchangeRate{
    exchange_rate: Int;
}

message OwnerWithdrawUSDt{
    to: Address;
    amount: Int;
}

contract Minter with Ownable{
    owner: Address;
    usdt_wallet_address: Address;
    ausdt_wallet_address: Address;
    asudt_master_address: Address;
    nft_master_address: Address;
    exchange_rate: Int as uint64;

    init(owner: Address) {
        self.owner = owner;
        self.usdt_wallet_address = newAddress(0, 0);
        self.ausdt_wallet_address = newAddress(0,0);
        self.asudt_master_address = newAddress(0,0);
        self.nft_master_address = newAddress(0,0);
        self.exchange_rate = 1000000000;
    }

    // exchange_rate:
    // decimals = 1,000,000,000
    // 1 aUSDt --> x USDt
    // should always >= 1,000,000,000

    receive(msg: TokenNotification) {
        let ctx: Context = context();
        if(ctx.sender == self.usdt_wallet_address){
            self.mintAusdt(msg.from, msg.amount * 1000000000 / self.exchange_rate);
        }
        if(ctx.sender == self.ausdt_wallet_address){
            self.mintWithdrawNft(msg.from, msg.amount * self.exchange_rate / 1000000000);
        }
    }

    receive(msg: OwnerWithdrawUSDt) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not owner");
        send(SendParameters{
        to: self.usdt_wallet_address, 
        value: 0, 
        bounce: true,
        mode: SendRemainingValue,
        body: TokenTransfer {
            query_id: 0,
            amount: msg.amount,
            destination: msg.to,
            response_destination: ctx.sender,
            custom_payload: emptyCell(),
            forward_amount: 0,
            forward_payload: emptySlice()
            }.toCell()
        });  
        
    }

    fun mintAusdt(to: Address, amount: Int) {
        send(SendParameters{
                to: self.asudt_master_address,
                value: 0,
                bounce: true,
                mode: SendRemainingValue,
                body: Mint{
                    to: to,
                    amount: amount
                }.toCell()
            }
        );
    }

    fun mintWithdrawNft(to: Address, amount: Int) {
        send(SendParameters{
                to: self.asudt_master_address,
                value: 0,
                bounce: true,
                mode: SendRemainingValue,
                body: MintNFT{
                    to: to,
                    amount: amount
                }.toCell()
            }
        );
    }

    receive(msg: SetAddress) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not owner");
        if(msg.usdt_wallet_address != null){self.usdt_wallet_address = msg.usdt_wallet_address!!;}
        if(msg.ausdt_wallet_address != null){self.ausdt_wallet_address = msg.ausdt_wallet_address!!;}
        if(msg.asudt_master_address != null){self.asudt_master_address = msg.asudt_master_address!!;}
        if(msg.nft_master_address != null){self.nft_master_address = msg.nft_master_address!!;}
    }

    receive(msg: SetExchangeRate) {
        let ctx: Context = context();
        require(ctx.sender == self.owner, "Not owner");
        self.exchange_rate = msg.exchange_rate;
    }
}