mkdir -p ~/.ssh/keychain\ copies/

# add to .ssh/keychain copies
openssl aes-256-cbc -K $encrypted_b749442190b9_key -iv $encrypted_b749442190b9_iv -in ed25519_sparkle_account_private_key.enc -out ~/.ssh/keychain\ copies/ed25519_sparkle_account_private_key -d
# same file but as ./ed25519_sparkle_account_private_key
openssl aes-256-cbc -K $encrypted_b749442190b9_key -iv $encrypted_b749442190b9_iv -in ed25519_sparkle_account_private_key.enc -out ./ed25519_sparkle_account_private_key -d

# add to .ssh/keychain copies
openssl aes-256-cbc -K $encrypted_9d3155e86c77_key -iv $encrypted_9d3155e86c77_iv -in AppleDevCert.p12.enc -out ~/.ssh/keychain\ copies/AppleDevCert.p12 -d
# same file but as ./codesign.p12
openssl aes-256-cbc -K $encrypted_9d3155e86c77_key -iv $encrypted_9d3155e86c77_iv -in AppleDevCert.p12.enc -out ./codesign.p12 -d
