build:
	forge build

test:
	forge test

fmt:
	forge fmt
deploy-staking:
	source .env && forge script script/Deploy.s.sol:Deploy --rpc-url dbc-testnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy
	#source .env && forge script script/Deploy.s.sol:Deploy --rpc-url dbc-testnet --private-key $PRIVATE_KEY --broadcast

verify-staking:
	source .env && forge verify-contract --chain 19850818  --compiler-version v0.8.26 --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL $STAKING_PROXY  src/NFTStaking.sol:NFTStaking

upgrade-staking:
	source .env && forge script script/Upgrade.s.sol:Upgrade --rpc-url dbc-testnet --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy

deploy-rent:
	source .env && forge script script/rent/Deploy.s.sol:Deploy --rpc-url dbc-testnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy
	#source .env && forge script script/rent/Deploy.s.sol:Deploy --rpc-url dbc-testnet --private-key $PRIVATE_KEY --broadcast
	source .env && forge script script/rent/Deploy.s.sol:Deploy --rpc-url dbc-mainnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $MAIN_NET_VERIFIER_URL --force --skip-simulation --legacy

verify-rent:
	source .env && forge verify-contract --chain 19850818  --compiler-version v0.8.25 --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL $RENT_PROXY  src/rent/Rent.sol:Rent --force

upgrade-rent:
	source .env && forge script script/rent/Upgrade.s.sol:Upgrade --rpc-url dbc-testnet --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy


deploy-tool:
	source .env && forge script script/tool/Deploy.s.sol:Deploy --rpc-url dbc-testnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation

verify-tool:
	source .env && forge verify-contract --chain 19850818  --compiler-version v0.8.25 --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL $TOOL_PROXY  src/Tool.sol:Tool

upgrade-tool:
	source .env && forge script script/tool/Upgrade.s.sol:Upgrade --rpc-url dbc-testnet --broadcast --verify --verifier blockscout --verifier-url $TEST_NET_VERIFIER_URL --force --skip-simulation --legacy


remapping:
	forge remappings > remappings.txt


deploy-staking-bsc-testnet:
	source .env && forge script script/Deploy.s.sol:Deploy --rpc-url dbc-testnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $BSC_TESTNET_VERIFIER_URL --force --skip-simulation

	forge verify-contract --chain bsc --verifier blockscout --verifier-url https://api-testnet.bscscan.com/api --compiler-version 0.8.26 0x7fdc6ed8387f3184de77e0cf6d6f3b361f906c21 src/NFTStaking.sol:NFTStaking
665adc9580c2086b3cfe81d1e470e4db574211c5f7ddaf64e4e833b034e2cf47

	source .env && forge script script/Deploy.s.sol:Deploy --rpc-url dbc-mainnet --private-key $PRIVATE_KEY --broadcast --verify --verifier blockscout --verifier-url $MAIN_NET_VERIFIER_URL --force --skip-simulation --legacy
