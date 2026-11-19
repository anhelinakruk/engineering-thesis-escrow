mod auth;
mod chain;
mod db;

use auth::Claims;
use axum::{
    extract::{Json, Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Router,
};
use db::AppState;
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use tower_http::cors::CorsLayer;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let db_address =
        std::env::var("SURREALDB_ADDRESS").unwrap_or_else(|_| "localhost:8000".to_string());
    let namespace =
        std::env::var("SURREALDB_NAMESPACE").unwrap_or_else(|_| "escrow".to_string());
    let database =
        std::env::var("SURREALDB_DATABASE").unwrap_or_else(|_| "wallet".to_string());
    let user = std::env::var("SURREAL_USER").unwrap_or_else(|_| "root".to_string());
    let pass = std::env::var("SURREAL_PASS").unwrap_or_else(|_| "root".to_string());
    let rpc_url =
        std::env::var("RPC_URL").unwrap_or_else(|_| "http://127.0.0.1:8545".to_string());
    let escrow_contract = std::env::var("ESCROW_CONTRACT")
        .unwrap_or_else(|_| "0x5FbDB2315678afecb367f032d93F642f64180aa3".to_string())
        .parse()
        .expect("ESCROW_CONTRACT is not a valid address");

    let app_state = AppState::new(
        &db_address,
        &user,
        &pass,
        &namespace,
        &database,
        rpc_url,
        escrow_contract,
    )
    .await
    .expect("Failed to connect to database");

    let app = Router::new()
        .route("/health", get(health))
        .route("/api/auth/nonce", get(auth::get_nonce))
        .route("/api/auth/verify", post(auth::verify_and_login))
        .route("/api/auth/me", get(auth::me))
        .route("/api/escrows/descriptions", get(get_descriptions))
        .route(
            "/api/escrows/:id/description",
            post(save_description).get(get_invite_description),
        )
        .layer(CorsLayer::permissive())
        .with_state(app_state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    eprintln!("Server listening on {}", addr);
    axum::serve(listener, app).await.unwrap();
}

async fn health() -> &'static str {
    "ok"
}

const MAX_DESCRIPTION_CHARS: usize = 500;

#[derive(Debug, Deserialize)]
struct SaveDescriptionRequest {
    description: String,
}

/// Trimmed description, or why it is rejected.
fn validate_description(raw: &str) -> Result<&str, &'static str> {
    let description = raw.trim();
    if description.is_empty() {
        return Err("description is empty");
    }
    if description.chars().count() > MAX_DESCRIPTION_CHARS {
        return Err("description is longer than 500 characters");
    }
    Ok(description)
}

/// `POST /api/escrows/:id/description` — the buyer attaches the deal terms
/// once. JWT-gated, and the caller must be the escrow's buyer on-chain, so
/// nobody else can put words in the buyer's mouth. Write-once: terms can't
/// change after the seller has seen them.
async fn save_description(
    claims: Claims,
    State(state): State<AppState>,
    Path(escrow_id): Path<u64>,
    Json(payload): Json<SaveDescriptionRequest>,
) -> axum::response::Response {
    let description = match validate_description(&payload.description) {
        Ok(d) => d,
        Err(why) => return error(StatusCode::BAD_REQUEST, why),
    };

    let caller = match state.get_user_address(&claims.sub).await {
        Ok(Some(address)) => address,
        Ok(None) => return error(StatusCode::UNAUTHORIZED, "unknown user"),
        Err(e) => return internal_error(e),
    };
    let buyer = match chain::escrow_parties(&state.rpc_url, state.escrow_contract, escrow_id).await {
        Ok((buyer, _)) => buyer,
        Err(e) => return internal_error(e),
    };
    if buyer.is_zero() {
        return error(StatusCode::NOT_FOUND, "escrow does not exist");
    }
    if buyer.to_string().to_lowercase() != caller.to_lowercase() {
        return error(StatusCode::FORBIDDEN, "only the buyer can describe the escrow");
    }

    match state.has_description(escrow_id).await {
        Ok(true) => return error(StatusCode::CONFLICT, "description already set"),
        Ok(false) => {}
        Err(e) => return internal_error(e),
    }
    let invite_key = siwe::generate_nonce();
    match state.save_description(escrow_id, description, &invite_key).await {
        Ok(()) => StatusCode::CREATED.into_response(),
        Err(e) => internal_error(e),
    }
}

#[derive(Debug, Deserialize)]
struct DescriptionsQuery {
    /// Comma-separated escrow ids, e.g. `0,1,2`.
    ids: String,
}

#[derive(Debug, Serialize)]
struct DescriptionResponse {
    escrow_id: i64,
    description: String,
    /// Only for the buyer, who needs it to build the invite link.
    #[serde(skip_serializing_if = "Option::is_none")]
    invite_key: Option<String>,
}

/// `GET /api/escrows/descriptions?ids=0,1,2` — descriptions for the caller's
/// own escrows (the wallet list). Rows where the caller is neither buyer nor
/// seller on-chain are left out, so ids can't be enumerated to read other
/// people's deals. Escrows without a description are absent too.
async fn get_descriptions(
    claims: Claims,
    State(state): State<AppState>,
    Query(query): Query<DescriptionsQuery>,
) -> axum::response::Response {
    let caller = match state.get_user_address(&claims.sub).await {
        Ok(Some(address)) => address.to_lowercase(),
        Ok(None) => return error(StatusCode::UNAUTHORIZED, "unknown user"),
        Err(e) => return internal_error(e),
    };
    let ids: Result<Vec<u64>, _> = query
        .ids
        .split(',')
        .filter(|s| !s.is_empty())
        .map(str::parse)
        .collect();
    let Ok(ids) = ids else {
        return error(StatusCode::BAD_REQUEST, "ids must be comma-separated numbers");
    };
    let rows = match state.get_descriptions(&ids).await {
        Ok(rows) => rows,
        Err(e) => return internal_error(e),
    };

    // ponytail: one RPC read per described escrow; fine for a wallet's own list.
    let mut visible = Vec::new();
    for row in rows {
        let (buyer, seller) =
            match chain::escrow_parties(&state.rpc_url, state.escrow_contract, row.escrow_id as u64).await {
                Ok(parties) => parties,
                Err(e) => return internal_error(e),
            };
        let is_buyer = buyer.to_string().to_lowercase() == caller;
        let is_seller = !seller.is_zero() && seller.to_string().to_lowercase() == caller;
        if is_buyer || is_seller {
            visible.push(DescriptionResponse {
                escrow_id: row.escrow_id,
                description: row.description,
                invite_key: is_buyer.then_some(row.invite_key),
            });
        }
    }
    (StatusCode::OK, Json(visible)).into_response()
}

#[derive(Debug, Deserialize)]
struct InviteQuery {
    key: String,
}

/// `GET /api/escrows/:id/description?key=…` — the terms for someone holding
/// the invite link, before they are a party. A wrong key and a missing
/// description both answer 404, so the endpoint reveals nothing without the key.
async fn get_invite_description(
    _claims: Claims,
    State(state): State<AppState>,
    Path(escrow_id): Path<u64>,
    Query(query): Query<InviteQuery>,
) -> axum::response::Response {
    match state.get_descriptions(&[escrow_id]).await {
        Ok(rows) => match rows.into_iter().find(|row| row.invite_key == query.key) {
            Some(row) => (
                StatusCode::OK,
                Json(DescriptionResponse {
                    escrow_id: row.escrow_id,
                    description: row.description,
                    invite_key: None,
                }),
            )
                .into_response(),
            None => error(StatusCode::NOT_FOUND, "no description for this invite"),
        },
        Err(e) => internal_error(e),
    }
}

fn error(status: StatusCode, message: &str) -> axum::response::Response {
    (status, Json(serde_json::json!({ "error": message }))).into_response()
}

fn internal_error(e: anyhow::Error) -> axum::response::Response {
    eprintln!("db error: {}", e);
    (
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(serde_json::json!({ "error": e.to_string() })),
    )
        .into_response()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validate_description_trims_and_limits() {
        assert_eq!(validate_description("  MacBook Pro 14  "), Ok("MacBook Pro 14"));
        assert!(validate_description("   ").is_err());
        assert!(validate_description(&"a".repeat(500)).is_ok());
        assert!(validate_description(&"a".repeat(501)).is_err());
        // Counted in characters, not bytes: 500 Polish letters are fine.
        assert!(validate_description(&"ż".repeat(500)).is_ok());
    }
}
