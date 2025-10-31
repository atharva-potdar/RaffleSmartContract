-include .env

.PHONY: all clean remove install update build test format

# Thank you Cyfrin!
all: clean remove install update build test format

clean  :; forge clean

remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "Force update modules"

install :; forge install cyfrin/foundry-devops@0.4.0 && forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 && forge install foundry-rs/forge-std@v1.11.0 && forge install Vectorized/solady@v0.1.26

update :; forge update

build :; forge build

test :; forge test

format :; forge fmt
# Thank you Cyfrin!