use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use surrealdb::engine::remote::ws::{Client, Ws};
use surrealdb::opt::auth::Root;
use surrealdb::sql::Thing;
use surrealdb::Surreal;
use alloy::primitives::Address;

#[derive(Clone)]
pub struct AppState {
    pub database: Arc<Surreal<Client>>,
    pub rpc_url: String,
    pub escrow_contract: Address,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct User {
    pub id: Option<Thing>,
    pub address: String,
    pub created_at: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Nonce {
    pub id: Option<Thing>,
    pub value: String,
    pub exp: Option<String>,
    pub iat: Option<String>,
}

/// A transaction record the wallet asks the backend to keep (history/index).
/// The chain stays the source of truth; this is a convenience cache keyed by
/// the owning wallet. Mirrors the `transactions` table in the fixtures.
#[derive(Debug, Serialize, Deserialize)]
pub struct Transaction {
    pub id: Option<Thing>,
    pub wallet_id: String,
    pub tx_hash: String,
    pub from_address: String,
    pub to_address: String,
    pub amount: String,
    pub status: String,
    pub chain_id: i64,
    pub created_at: Option<String>,
}

/// Off-chain terms of an escrow. Keyed by contract + id because ids restart at
/// 0 on every deployment. `invite_key` travels in the invite link and lets
/// someone who isn't a party yet (the seller-to-be) read the terms.
#[derive(Debug, Serialize, Deserialize)]
pub struct EscrowDescription {
    pub escrow_id: i64,
    pub description: String,
    pub invite_key: String,
}

impl AppState {
    pub async fn new(
        address: &str,
        username: &str,
        password: &str,
        namespace: &str,
        database: &str,
        rpc_url: String,
        escrow_contract: Address,
    ) -> Result<Self> {
        let client = Surreal::new::<Ws>(address).await?;
        client.signin(Root { username, password }).await?;
        client.use_ns(namespace).use_db(database).await?;
        Ok(AppState { database: Arc::new(client), rpc_url, escrow_contract })
    }

    /// Address of the user a JWT `sub` (a `user:…` record id) points to.
    pub async fn get_user_address(&self, user_id: &str) -> Result<Option<String>> {
        let mut result = self
            .database
            .query("SELECT VALUE address FROM type::record($id)")
            .bind(("id", user_id.to_string()))
            .await?;
        let addresses: Vec<String> = result.take(0)?;
        Ok(addresses.into_iter().next())
    }

    /// Fails if the escrow already has a description (unique index).
    pub async fn save_description(&self, escrow_id: u64, description: &str, invite_key: &str) -> Result<()> {
        self.database
            .query(
                "CREATE escrow_description SET contract = $contract, escrow_id = $id, description = $description, invite_key = $key",
            )
            .bind(("contract", self.escrow_contract.to_string().to_lowercase()))
            .bind(("id", escrow_id as i64))
            .bind(("description", description.to_string()))
            .bind(("key", invite_key.to_string()))
            .await?
            .check()?;
        Ok(())
    }

    pub async fn has_description(&self, escrow_id: u64) -> Result<bool> {
        Ok(!self.get_descriptions(&[escrow_id]).await?.is_empty())
    }

    pub async fn get_descriptions(&self, escrow_ids: &[u64]) -> Result<Vec<EscrowDescription>> {
        let ids: Vec<i64> = escrow_ids.iter().map(|&id| id as i64).collect();
        let mut result = self
            .database
            .query(
                "SELECT escrow_id, description, invite_key FROM escrow_description WHERE contract = $contract AND escrow_id IN $ids",
            )
            .bind(("contract", self.escrow_contract.to_string().to_lowercase()))
            .bind(("ids", ids))
            .await?;
        Ok(result.take(0)?)
    }

    pub async fn create_user(&self, address: &str) -> Result<User> {
        let user: Option<User> = self
            .database
            .create("user")
            .content(User {
                id: None,
                address: address.to_lowercase(),
                created_at: None,
            })
            .await?;
        user.ok_or_else(|| anyhow::anyhow!("Failed to create user"))
    }

    pub async fn get_user_by_address(&self, address: &str) -> Result<Option<User>> {
        let mut result = self
            .database
            .query("SELECT * FROM user WHERE address = type::string(string::lowercase($address))")
            .bind(("address", address.to_string()))
            .await?;
        let users: Vec<User> = result.take(0)?;
        Ok(users.into_iter().next())
    }

    pub async fn save_nonce(&self, value: &str) -> Result<()> {
        self.database
            .query(
                "DELETE nonce WHERE exp < time::now() RETURN BEFORE;
                 CREATE ONLY nonce SET value = type::string($value), exp = time::now() + 5m, iat = time::now();",
            )
            .bind(("value", value.to_string()))
            .await?;
        Ok(())
    }

    pub async fn get_nonce(&self, value: &str) -> Result<Option<Nonce>> {
        let mut result = self
            .database
            .query(
                "DELETE nonce WHERE exp < time::now() RETURN BEFORE;
                 SELECT * FROM nonce WHERE value = type::string($value);",
            )
            .bind(("value", value.to_string()))
            .await?;
        let nonces: Vec<Nonce> = result.take(1)?;
        Ok(nonces.into_iter().next())
    }

    pub async fn save_transaction(
        &self,
        wallet_id: &str,
        tx_hash: &str,
        from_address: &str,
        to_address: &str,
        amount: &str,
        chain_id: i64,
    ) -> Result<Transaction> {
        let transaction: Option<Transaction> = self
            .database
            .create("transactions")
            .content(Transaction {
                id: None,
                wallet_id: wallet_id.to_string(),
                tx_hash: tx_hash.to_string(),
                from_address: from_address.to_string(),
                to_address: to_address.to_string(),
                amount: amount.to_string(),
                status: "pending".to_string(),
                chain_id,
                created_at: None,
            })
            .await?;
        transaction.ok_or_else(|| anyhow::anyhow!("Failed to save transaction"))
    }

    pub async fn get_transactions_by_wallet(&self, wallet_id: &str) -> Result<Vec<Transaction>> {
        let mut result = self
            .database
            .query("SELECT * FROM transactions WHERE wallet_id = $wallet_id ORDER BY created_at DESC")
            .bind(("wallet_id", wallet_id.to_string()))
            .await?;
        let transactions: Vec<Transaction> = result.take(0)?;
        Ok(transactions)
    }
}
