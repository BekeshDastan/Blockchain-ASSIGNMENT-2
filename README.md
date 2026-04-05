## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## CI Pipeline

The project uses GitHub Actions for continuous integration. The pipeline is defined in `.github/workflows/test.yml` and includes the following stages:

1. **Checkout**: Clones the repository with submodules.
2. **Install Foundry**: Sets up the Foundry toolchain.
3. **Format Check**: Runs `forge fmt --check` to ensure code formatting.
4. **Build**: Compiles contracts with `forge build --sizes` to check sizes.
5. **Test**: Executes all tests with `forge test -vvv` for verbose output.
6. **Gas Report**: Generates gas snapshot with `forge snapshot`.
7. **Slither Analysis**: Installs and runs Slither for static analysis of smart contracts.

The pipeline runs on pushes and pull requests to main/master branches.
