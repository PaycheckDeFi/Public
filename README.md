# Smart contracts for Paycheck Protocol

Consists of:

* Tokens: CHECK & LCHECK

## Compile, Test, Deploy

```shell
yarn
yarn bootstrap
```
if error, check node version for `yarn` expected node version ">=12.19", for check and set necessary version use, for example
```shell
node -v
nvm use 12.22.6
```
then use hardhat to compile, test: cd into directory and then
```shell
hardhat compile
```

## Protocol overview

Paycheck is a protocol for DeFi and NFT

#### CHECK token

CHECK token is ERC20 token with a fee taken per each transaction (unless the either side is whitelisted by excludedFromFee method).

The fees should be distributed according to the rules:
* 3% to the multi-signature project development fund
* 5% redistribution to all CHECK holders

There is also grace amount of token which allows user to avoid any fees - 100M CHECK token

## License

Smart contracts for Paycheck protocol are available under the [MIT License](LICENSE.md).
