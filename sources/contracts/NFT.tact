import "./MessagesNFT.tact";

struct NftData {
    item_index: Int;
    amount: Int as coins;
}

message MintNFT {
    to: Address;
    amount: Int as coins;
}

message Claim{
    query_id: Int as uint64;
    claimer: Address;
    response_destination: Address?;
    forward_amount: Int as coins;
    forward_payload: Slice as remaining;
}

message ClaimNotification{
    query_id: Int as uint64;
    to: Address;
    amount: Int as coins;
    item_index: Int as uint64;
    forward_amount: Int as coins;
    forward_payload: Slice as remaining;
}

contract NftCollection {
    const min_tons_for_storage: Int = ton("0.02");
    const gas_consumption: Int = ton("0.02");

    next_item_index: Int as uint64 = 0;
    owner: Address;
    minter: Address;
    collection_content: Cell;   

    init(owner: Address, minter: Address, collection_content: Cell){
        self.owner = owner;
        self.collection_content = collection_content;
        self.minter = minter;
    }

    receive(msg: MintNFT){
        let current_item_index: Int = self.next_item_index;
        let nft_init: StateInit = self.get_nft_item_init(current_item_index);
        self.next_item_index = self.next_item_index + 1;

        let ctx: Context = context();
        let msg_value: Int = self.get_msg_value(ctx.value);  
        let fwdFee: Int = ctx.readForwardFee();
        msg_value = msg_value - fwdFee;

        send(SendParameters{
                to: contractAddress(nft_init), 
                value: 0, 
                bounce: true,
                mode: SendRemainingValue,
                body: Transfer {
                    query_id: 0,
                    new_owner: msg.to,
                    response_destination: msg.to,
                    custom_payload: self.collection_content,
                    forward_amount: 0,
                    forward_payload: beginCell().storeCoins(msg.amount).endCell().asSlice()
                }.toCell(),
                code: nft_init.code,
                data: nft_init.data
            });        
    }

    bounced(src: bounced<Transfer>) {
        self.next_item_index = self.next_item_index - 1;
    }

    // ------------------ Get Function  ------------------ //
    get fun get_collection_data(): CollectionData {     
        let b: StringBuilder = beginString();
        let collectionDataString: String = self.collection_content.asSlice().asString();
        b.append(collectionDataString);
        b.append("meta.json"); // You can changed this your self.
        return CollectionData{
            next_item_index: self.next_item_index, 
            collection_content: b.toCell(), 
            owner: self.owner
        };
    }

    get fun get_nft_address_by_index(item_index: Int): Address?{      
        let initCode: StateInit = self.get_nft_item_init(item_index);
        return contractAddress(initCode);
    }

    get fun get_nft_item_init(item_index: Int): StateInit {
        return initOf NftItem(myAddress(), item_index);
    }
    
    get fun get_nft_content(index: Int, individual_content: Cell): Cell { 
        let b: StringBuilder = beginString();
        let ic: String = individual_content.asSlice().asString();
        b.append(ic);
        return b.toCell();
    }

    get fun get_msg_value(value: Int): Int {
        let msg_value: Int = value;
        let balance_before_msg: Int = myBalance() - msg_value;
        let storage_fee: Int = self.min_tons_for_storage - min(balance_before_msg, self.min_tons_for_storage);
        msg_value = msg_value - (storage_fee + self.gas_consumption);
        return msg_value;
    }
}

contract NftItem {
    const min_tons_for_storage: Int = ton("0.02");
    const gas_consumption: Int = ton("0.02");

    collection_address: Address;
    item_index: Int as uint64;
    amount: Int as coins = 0;
    is_initialized: Bool;

    owner: Address?;
    prev_owner: Address?;
    individual_content: Cell?;

    init(collection_address: Address, item_index: Int){
        require(sender() == collection_address, "not from collection");
        self.collection_address = collection_address;
        self.item_index = item_index;
        self.is_initialized = false;
    }

    receive(msg: Transfer){
        let ctx: Context = context();
        if (self.is_initialized == false) {  // Initial Transfer, aka the "Minting" of the NFT
            require(ctx.sender == self.collection_address, "initialized tx need from collection");
            self.is_initialized = true;
            self.owner = msg.new_owner;
            self.individual_content = msg.custom_payload;
            self.amount = msg.forward_payload.loadCoins();

            let msg_value: Int = self.get_msg_value(ctx.value);  
            let fwdFee: Int = ctx.readForwardFee();
            msg_value = msg_value - fwdFee;

            if (msg.response_destination != null) { 
                send(SendParameters{ 
                    to: msg.response_destination!!,
                    value: msg_value,
                    bounce: false,
                    mode: SendIgnoreErrors,
                    body: Excesses { query_id: msg.query_id }.toCell()
                });
            }
        } else {
            require(ctx.sender == self.owner!!, "not owner");
            self.prev_owner = self.owner;
            self.owner = msg.new_owner;  // change current owner to the new_owner

            let msg_value: Int = self.get_msg_value(ctx.value);  
            let fwdFee: Int = ctx.readForwardFee();
            msg_value = msg_value - msg.forward_amount - fwdFee;

            if (msg.forward_amount > 0) {
                send(SendParameters{
                    to: msg.new_owner,
                    value: msg.forward_amount,
                    bounce: true,
                    mode:  SendPayGasSeparately + SendIgnoreErrors, 
                    body: OwnershipAssigned{
                        query_id: msg.query_id,
                        prev_owner: ctx.sender,
                        forward_payload: msg.forward_payload
                    }.toCell()
                }); 
            }

            if (msg.response_destination != null) { 
                send(SendParameters{ 
                    to: msg.response_destination!!,
                    value: msg_value,
                    bounce: false,
                    mode: SendIgnoreErrors,
                    body: Excesses { query_id: msg.query_id }.toCell()
                });
            }
        }
    }

    receive(msg: Claim){
        let ctx: Context = context();
        require(self.is_initialized,"not initialized");
        require(ctx.sender == self.owner!!, "not owner");
        self.prev_owner = self.owner;
        self.owner = newAddress(0,0);  // change current owner to the new_owner

        if (msg.forward_amount > 0) {
            send(SendParameters{
                to: msg.claimer,
                value: 0,
                bounce: true,
                mode:  SendRemainingValue, 
                body: ClaimNotification{
                    query_id: msg.query_id,
                    to: self.owner!!,
                    amount: self.amount,
                    item_index: self.item_index,
                    forward_amount: msg.forward_amount,
                    forward_payload: msg.forward_payload
                }.toCell()
            }); 
        }
        
    }

    receive(msg: GetStaticData){ 
        let ctx: Context = context();
        send(SendParameters {
            to: ctx.sender,
            value: 0,
            mode: SendRemainingValue,  // 64: return msg amount except gas fees
            bounce: false,
            body: ReportStaticData{
                query_id: msg.query_id,
                index_id: self.item_index,
                collection: self.collection_address
            }.toCell()
        });
    }

    bounced(src: bounced<OwnershipAssigned>) {
        self.owner = self.prev_owner;
    }

    bounced(src: bounced<ClaimNotification>) {
        self.owner = self.prev_owner;
    }
   
    
    // --------- Get Function  --------- //
    get fun get_nft_data(): GetNftData {
        let b: StringBuilder = beginString();
        let collectionData: String = (self.individual_content!!).asSlice().asString();
        b.append(collectionData);
        b.append(self.item_index.toString());
        b.append(".json");

        return GetNftData {
            is_initialized: self.is_initialized, 
            index: self.item_index, 
            collection_address: self.collection_address, 
            owner: self.owner!!,
            individual_content: b.toCell()
        };
    }

    get fun get_msg_value(value: Int): Int {
        let msg_value: Int = value;
        let balance_before_msg: Int = myBalance() - msg_value;
        let storage_fee: Int = self.min_tons_for_storage - min(balance_before_msg, self.min_tons_for_storage);
        msg_value = msg_value - (storage_fee + self.gas_consumption);
        return msg_value;
    }

    // bounced(src: bounced<TokenBurnNotification>) {
    //     self.balance = self.balance + src.amount;
    // }
}