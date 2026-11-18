use alloy::primitives::{Address, U256};
use alloy::providers::ProviderBuilder;
use alloy::sol;
use anyhow::Result;

sol! {
    #[sol(rpc)]
    contract Escrow {
        function transactions(uint256 id) external view returns (
            address buyer,
            address seller,
            uint256 amount,
            uint8 state,
            uint256 shipDeadline,
            uint256 confirmDeadline
        );
    }
}

/// Buyer and seller as recorded on-chain. A missing escrow has a zero buyer;
/// a seller who hasn't joined yet is zero too.
pub async fn escrow_parties(rpc_url: &str, contract: Address, id: u64) -> Result<(Address, Address)> {
    let provider = ProviderBuilder::new().on_http(rpc_url.parse()?);
    let escrow = Escrow::new(contract, provider);
    let t = escrow.transactions(U256::from(id)).call().await?;
    Ok((t.buyer, t.seller))
}
