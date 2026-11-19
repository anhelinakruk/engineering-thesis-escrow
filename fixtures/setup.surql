USE NS escrow DB wallet;

DEFINE TABLE user SCHEMAFULL;
DEFINE FIELD address ON user TYPE string;
DEFINE FIELD created_at ON user TYPE datetime DEFAULT time::now();
DEFINE INDEX user_address ON user FIELDS address UNIQUE;

DEFINE TABLE nonce SCHEMAFULL;
DEFINE FIELD value ON nonce TYPE string;
DEFINE FIELD exp ON nonce TYPE datetime;
DEFINE FIELD iat ON nonce TYPE datetime DEFAULT time::now();
DEFINE INDEX nonce_value ON nonce FIELDS value UNIQUE;
DEFINE TABLE escrow_description SCHEMAFULL;
DEFINE FIELD contract ON escrow_description TYPE string;
DEFINE FIELD escrow_id ON escrow_description TYPE int;
DEFINE FIELD description ON escrow_description TYPE string;
DEFINE FIELD created_at ON escrow_description TYPE datetime DEFAULT time::now();
DEFINE INDEX escrow_description_key ON escrow_description FIELDS contract, escrow_id UNIQUE;
DEFINE FIELD invite_key ON escrow_description TYPE string;
